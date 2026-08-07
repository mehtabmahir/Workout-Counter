import SwiftUI
import AVFoundation
import Combine
import Vision

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if os(iOS)
import UIKit

// MARK: - Workout Screen

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()
    @StateObject private var curlCounter = BicepCurlCounter()

    @State private var isCounting = false

    var body: some View {
        ZStack {
            CameraPreview(
                session: camera.session,
                pose: camera.pose,
                selectedArm: curlCounter.selectedArm
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .black.opacity(0.7),
                    .clear,
                    .black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text(isCounting ? "COUNTING" : "READY")
                        .font(.caption.bold())
                        .tracking(2)
                        .foregroundStyle(isCounting ? .green : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                }

                Spacer()

                VStack(spacing: 0) {
                    Text("\(curlCounter.repCount)")
                        .font(
                            .system(
                                size: 100,
                                weight: .black,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)

                    Text("REPS")
                        .font(.headline.bold())
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        curlCounter.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2.bold())
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.white)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    Button {
                        isCounting.toggle()
                        curlCounter.resetMovement()
                    } label: {
                        Text(isCounting ? "Pause" : "Start Counting")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .foregroundStyle(.black)
                            .background(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
            .padding(20)

            if let message = camera.message {
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await camera.start()
        }
        .onReceive(camera.$pose) { pose in
            guard isCounting else {
                return
            }

            curlCounter.process(pose)
        }
        .onDisappear {
            camera.stop()
        }
    }
}

// MARK: - Pose Data

struct ArmPose: Sendable {
    var imageSize = CGSize.zero

    var leftShoulder: CGPoint?
    var leftElbow: CGPoint?
    var leftWrist: CGPoint?

    var rightShoulder: CGPoint?
    var rightElbow: CGPoint?
    var rightWrist: CGPoint?

    var leftArmConfidence: Float = 0
    var rightArmConfidence: Float = 0
    var leftWristIsDetected = false
    var rightWristIsDetected = false

    static let empty = ArmPose()

    var leftElbowAngle: CGFloat? {
        guard leftArmConfidence >= 0.25 else {
            return nil
        }

        return elbowAngle(
            shoulder: leftShoulder,
            elbow: leftElbow,
            wrist: leftWrist
        )
    }

    var rightElbowAngle: CGFloat? {
        guard rightArmConfidence >= 0.25 else {
            return nil
        }

        return elbowAngle(
            shoulder: rightShoulder,
            elbow: rightElbow,
            wrist: rightWrist
        )
    }

    private func elbowAngle(
        shoulder: CGPoint?,
        elbow: CGPoint?,
        wrist: CGPoint?
    ) -> CGFloat? {
        guard imageSize.width > 0,
              imageSize.height > 0,
              let shoulder,
              let elbow,
              let wrist else {
            return nil
        }

        let scaledShoulder = CGPoint(
            x: shoulder.x * imageSize.width,
            y: shoulder.y * imageSize.height
        )
        let scaledElbow = CGPoint(
            x: elbow.x * imageSize.width,
            y: elbow.y * imageSize.height
        )
        let scaledWrist = CGPoint(
            x: wrist.x * imageSize.width,
            y: wrist.y * imageSize.height
        )

        let upperArm = CGVector(
            dx: scaledShoulder.x - scaledElbow.x,
            dy: scaledShoulder.y - scaledElbow.y
        )
        let forearm = CGVector(
            dx: scaledWrist.x - scaledElbow.x,
            dy: scaledWrist.y - scaledElbow.y
        )

        let upperArmLength = hypot(upperArm.dx, upperArm.dy)
        let forearmLength = hypot(forearm.dx, forearm.dy)

        guard upperArmLength > 0,
              forearmLength > 0 else {
            return nil
        }

        let dotProduct = upperArm.dx * forearm.dx
            + upperArm.dy * forearm.dy
        let cosine = max(
            -1,
            min(1, dotProduct / (upperArmLength * forearmLength))
        )

        return acos(cosine) * 180 / CGFloat.pi
    }
}

private struct PoseFilter {
    private struct JointFilter {
        private var point: CGPoint?
        private var missingFrames = 0

        mutating func update(with newPoint: CGPoint?) -> CGPoint? {
            if let newPoint {
                if let point {
                    let smoothingFactor: CGFloat = 0.45
                    self.point = CGPoint(
                        x: point.x
                            + smoothingFactor * (newPoint.x - point.x),
                        y: point.y
                            + smoothingFactor * (newPoint.y - point.y)
                    )
                } else {
                    point = newPoint
                }

                missingFrames = 0
            } else if point != nil {
                missingFrames += 1

                if missingFrames > 8 {
                    point = nil
                    missingFrames = 0
                }
            }

            return point
        }

        mutating func reset() {
            point = nil
            missingFrames = 0
        }
    }

    private var imageSize = CGSize.zero
    private var leftShoulder = JointFilter()
    private var leftElbow = JointFilter()
    private var leftWrist = JointFilter()
    private var rightShoulder = JointFilter()
    private var rightElbow = JointFilter()
    private var rightWrist = JointFilter()
    private var leftArmConfidence: Float = 0
    private var rightArmConfidence: Float = 0

    mutating func process(_ pose: ArmPose) -> ArmPose {
        if pose.imageSize != .zero {
            imageSize = pose.imageSize
        }

        let filteredLeftShoulder = leftShoulder.update(
            with: pose.leftShoulder
        )
        let filteredLeftElbow = leftElbow.update(with: pose.leftElbow)
        let filteredLeftWrist = leftWrist.update(with: pose.leftWrist)
        let filteredRightShoulder = rightShoulder.update(
            with: pose.rightShoulder
        )
        let filteredRightElbow = rightElbow.update(with: pose.rightElbow)
        let filteredRightWrist = rightWrist.update(with: pose.rightWrist)

        leftArmConfidence = filteredConfidence(
            newConfidence: pose.leftArmConfidence,
            previousConfidence: leftArmConfidence,
            hasCompleteArm: filteredLeftShoulder != nil
                && filteredLeftElbow != nil
                && filteredLeftWrist != nil
        )
        rightArmConfidence = filteredConfidence(
            newConfidence: pose.rightArmConfidence,
            previousConfidence: rightArmConfidence,
            hasCompleteArm: filteredRightShoulder != nil
                && filteredRightElbow != nil
                && filteredRightWrist != nil
        )

        return ArmPose(
            imageSize: imageSize,
            leftShoulder: filteredLeftShoulder,
            leftElbow: filteredLeftElbow,
            leftWrist: filteredLeftWrist,
            rightShoulder: filteredRightShoulder,
            rightElbow: filteredRightElbow,
            rightWrist: filteredRightWrist,
            leftArmConfidence: leftArmConfidence,
            rightArmConfidence: rightArmConfidence,
            leftWristIsDetected: pose.leftWristIsDetected,
            rightWristIsDetected: pose.rightWristIsDetected
        )
    }

    mutating func reset() {
        imageSize = .zero
        leftShoulder.reset()
        leftElbow.reset()
        leftWrist.reset()
        rightShoulder.reset()
        rightElbow.reset()
        rightWrist.reset()
        leftArmConfidence = 0
        rightArmConfidence = 0
    }

    private func filteredConfidence(
        newConfidence: Float,
        previousConfidence: Float,
        hasCompleteArm: Bool
    ) -> Float {
        guard hasCompleteArm else {
            return 0
        }

        if newConfidence > 0.15 {
            return previousConfidence == 0
                ? newConfidence
                : previousConfidence * 0.4 + newConfidence * 0.6
        }

        return previousConfidence * 0.9
    }
}

// MARK: - Vision Processing

final class PoseProcessor:
    NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable {

    var onPose: (@Sendable (ArmPose) -> Void)?

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            onPose?(.empty)
            return
        }

        let imageSize = CGSize(
            width: CVPixelBufferGetHeight(pixelBuffer),
            height: CVPixelBufferGetWidth(pixelBuffer)
        )
        let request = VNDetectHumanBodyPoseRequest()

        let requestHandler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .leftMirrored,
            options: [:]
        )

        do {
            try requestHandler.perform([request])

            guard let observation = request.results?.first else {
                onPose?(.empty)
                return
            }

            let recognizedPoints = try observation.recognizedPoints(.all)

            func location(
                for joint: VNHumanBodyPoseObservation.JointName
            ) -> CGPoint? {
                guard let point = recognizedPoints[joint],
                      point.confidence > 0.15 else {
                    return nil
                }

                // Vision's origin is bottom-left. AVFoundation uses top-left.
                return CGPoint(
                    x: 1 - point.location.x,
                    y: 1 - point.location.y
                )
            }

            func confidence(
                for joints: [VNHumanBodyPoseObservation.JointName]
            ) -> Float {
                joints.compactMap { recognizedPoints[$0]?.confidence }
                    .min() ?? 0
            }

            let leftWrist = location(for: .leftWrist)
            let rightWrist = location(for: .rightWrist)

            let pose = ArmPose(
                imageSize: imageSize,
                leftShoulder: location(for: .leftShoulder),
                leftElbow: location(for: .leftElbow),
                leftWrist: leftWrist,
                rightShoulder: location(for: .rightShoulder),
                rightElbow: location(for: .rightElbow),
                rightWrist: rightWrist,
                leftArmConfidence: confidence(
                    for: [.leftShoulder, .leftElbow, .leftWrist]
                ),
                rightArmConfidence: confidence(
                    for: [.rightShoulder, .rightElbow, .rightWrist]
                ),
                leftWristIsDetected: leftWrist != nil,
                rightWristIsDetected: rightWrist != nil
            )

            onPose?(pose)
        } catch {
            onPose?(.empty)
        }
    }
}

// MARK: - Camera

final class CameraModel:
    ObservableObject,
    @unchecked Sendable {

    let session = AVCaptureSession()

    @Published private(set) var message: String?
    @Published private(set) var pose = ArmPose.empty

    private let poseProcessor = PoseProcessor()
    private var poseFilter = PoseFilter()

    private let sessionQueue = DispatchQueue(
        label: "WorkoutCounter.camera",
        qos: .userInitiated
    )

    private var configured = false

    init() {
        poseProcessor.onPose = { [weak self] pose in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.pose = self.poseFilter.process(pose)
            }
        }
    }

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)

            if granted {
                startSession()
            } else {
                publishMessage(
                    "Camera access is required to count workouts."
                )
            }

        case .denied, .restricted:
            publishMessage("Enable camera access in Settings.")

        @unknown default:
            publishMessage("Camera access is unavailable.")
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            if self.session.isRunning {
                self.session.stopRunning()
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.poseFilter.reset()
            self?.pose = .empty
        }
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            self?.configureAndStart()
        }
    }

    private func configureAndStart() {
        if configured {
            if !session.isRunning {
                session.startRunning()
            }

            return
        }

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            publishMessage("No camera is available on this device.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            let videoOutput = AVCaptureVideoDataOutput()

            videoOutput.alwaysDiscardsLateVideoFrames = true

            videoOutput.setSampleBufferDelegate(
                poseProcessor,
                queue: DispatchQueue(
                    label: "WorkoutCounter.pose",
                    qos: .userInitiated
                )
            )

            session.beginConfiguration()

            if session.canSetSessionPreset(.vga640x480) {
                session.sessionPreset = .vga640x480
            } else {
                session.sessionPreset = .high
            }

            guard session.canAddInput(input) else {
                session.commitConfiguration()
                publishMessage("The camera could not be connected.")
                return
            }

            guard session.canAddOutput(videoOutput) else {
                session.commitConfiguration()
                publishMessage("Camera frames could not be analyzed.")
                return
            }

            session.addInput(input)
            session.addOutput(videoOutput)
            session.commitConfiguration()

            configured = true
            publishMessage(nil)
            session.startRunning()
        } catch {
            publishMessage("The camera could not be started.")
        }
    }

    private func publishMessage(_ newMessage: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.message = newMessage
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let pose: ArmPose
    let selectedArm: ExerciseArm?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()

        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect

        if let connection = view.previewLayer.connection,
           connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        return view
    }

    func updateUIView(
        _ uiView: PreviewView,
        context: Context
    ) {
        uiView.updatePose(
            pose,
            selectedArm: selectedArm
        )
    }
}

// MARK: - Pose Overlay

final class PreviewView: UIView {
    private let leftPoseLayer = CAShapeLayer()
    private let rightPoseLayer = CAShapeLayer()
    private var pose = ArmPose.empty
    private var selectedArm: ExerciseArm?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configurePoseLayer(leftPoseLayer)
        configurePoseLayer(rightPoseLayer)

        layer.addSublayer(leftPoseLayer)
        layer.addSublayer(rightPoseLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        leftPoseLayer.frame = bounds
        rightPoseLayer.frame = bounds
        drawPose()
    }

    func updatePose(
        _ newPose: ArmPose,
        selectedArm: ExerciseArm?
    ) {
        pose = newPose
        self.selectedArm = selectedArm
        drawPose()
    }

    private func drawPose() {
        let leftPath = UIBezierPath()
        let rightPath = UIBezierPath()

        drawArm(
            shoulder: pose.leftShoulder,
            elbow: pose.leftElbow,
            wrist: pose.leftWrist,
            into: leftPath
        )

        drawArm(
            shoulder: pose.rightShoulder,
            elbow: pose.rightElbow,
            wrist: pose.rightWrist,
            into: rightPath
        )

        leftPoseLayer.path = leftPath.cgPath
        rightPoseLayer.path = rightPath.cgPath
        stylePoseLayers()
    }

    private func configurePoseLayer(_ poseLayer: CAShapeLayer) {
        poseLayer.strokeColor = UIColor.systemGreen.cgColor
        poseLayer.fillColor = UIColor.clear.cgColor
        poseLayer.lineWidth = 6
        poseLayer.lineCap = .round
        poseLayer.lineJoin = .round
    }

    private func stylePoseLayers() {
        guard let selectedArm else {
            styleActive(leftPoseLayer)
            styleActive(rightPoseLayer)
            return
        }

        style(
            leftPoseLayer,
            isActive: selectedArm == .left
        )
        style(
            rightPoseLayer,
            isActive: selectedArm == .right
        )
    }

    private func style(
        _ poseLayer: CAShapeLayer,
        isActive: Bool
    ) {
        if isActive {
            styleActive(poseLayer)
        } else {
            poseLayer.strokeColor = UIColor.systemGray.cgColor
            poseLayer.opacity = 0.22
            poseLayer.lineWidth = 4
        }
    }

    private func styleActive(_ poseLayer: CAShapeLayer) {
        poseLayer.strokeColor = UIColor.systemGreen.cgColor
        poseLayer.opacity = 1
        poseLayer.lineWidth = 6
    }

    private func drawArm(
        shoulder: CGPoint?,
        elbow: CGPoint?,
        wrist: CGPoint?,
        into path: UIBezierPath
    ) {
        let convertedShoulder = shoulder.map(convertToLayerPoint)
        let convertedElbow = elbow.map(convertToLayerPoint)
        let convertedWrist = wrist.map(convertToLayerPoint)

        if let convertedShoulder,
           let convertedElbow {
            path.move(to: convertedShoulder)
            path.addLine(to: convertedElbow)
        }

        if let convertedElbow,
           let convertedWrist {
            path.move(to: convertedElbow)
            path.addLine(to: convertedWrist)
        }

        for point in [
            convertedShoulder,
            convertedElbow,
            convertedWrist
        ].compactMap({ $0 }) {
            path.move(
                to: CGPoint(
                    x: point.x + 8,
                    y: point.y
                )
            )

            path.addArc(
                withCenter: point,
                radius: 8,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
        }
    }

    private func convertToLayerPoint(_ point: CGPoint) -> CGPoint {
        // Vision reports portrait-oriented points, but the preview layer
        // converts from the camera sensor's unrotated coordinate space.
        let captureDevicePoint = CGPoint(
            x: point.y,
            y: 1 - point.x
        )

        return previewLayer.layerPointConverted(
            fromCaptureDevicePoint: captureDevicePoint
        )
    }
}

#else

struct ContentView: View {
    var body: some View {
        Text("Workout Counter requires an iPhone.")
    }
}

#endif

#Preview {
    ContentView()
}
