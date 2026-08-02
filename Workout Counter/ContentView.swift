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

// MARK: - Home Screen

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        .black,
                        Color(red: 0.08, green: 0.12, blue: 0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    Spacer()

                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 54))
                        .foregroundStyle(.green)

                    Text("Workout Counter")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Choose a workout and let your camera count the reps.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.65))

                    NavigationLink {
                        WorkoutView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Bicep Curls")
                                    .font(.title2.bold())

                                Text("Start workout")
                                    .foregroundStyle(.white.opacity(0.65))
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.title2.bold())
                        }
                        .foregroundStyle(.white)
                        .padding(22)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    }

                    Spacer()
                }
                .padding(24)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Workout Screen

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()

    @State private var repCount = 0
    @State private var isCounting = false

    var body: some View {
        ZStack {
            CameraPreview(
                session: camera.session,
                pose: camera.pose
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
                    Text("\(repCount)")
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
                        repCount = 0
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
        .onDisappear {
            camera.stop()
        }
    }
}

// MARK: - Pose Data

struct ArmPose: Sendable {
    var leftShoulder: CGPoint?
    var leftElbow: CGPoint?
    var leftWrist: CGPoint?

    var rightShoulder: CGPoint?
    var rightElbow: CGPoint?
    var rightWrist: CGPoint?

    static let empty = ArmPose()
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
                      point.confidence > 0.3 else {
                    return nil
                }

                // Vision's origin is bottom-left. AVFoundation uses top-left.
                return CGPoint(
                    x: 1 - point.location.x,
                    y: 1 - point.location.y
                )
            }

            let pose = ArmPose(
                leftShoulder: location(for: .leftShoulder),
                leftElbow: location(for: .leftElbow),
                leftWrist: location(for: .leftWrist),
                rightShoulder: location(for: .rightShoulder),
                rightElbow: location(for: .rightElbow),
                rightWrist: location(for: .rightWrist)
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

    private let sessionQueue = DispatchQueue(
        label: "WorkoutCounter.camera",
        qos: .userInitiated
    )

    private var configured = false

    init() {
        poseProcessor.onPose = { [weak self] pose in
            DispatchQueue.main.async {
                self?.pose = pose
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
            session.sessionPreset = .high

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
        uiView.updatePose(pose)
    }
}

// MARK: - Pose Overlay

final class PreviewView: UIView {
    private let poseLayer = CAShapeLayer()
    private var pose = ArmPose.empty

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        poseLayer.strokeColor = UIColor.systemGreen.cgColor
        poseLayer.fillColor = UIColor.clear.cgColor
        poseLayer.lineWidth = 6
        poseLayer.lineCap = .round
        poseLayer.lineJoin = .round

        layer.addSublayer(poseLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        poseLayer.frame = bounds
        drawPose()
    }

    func updatePose(_ newPose: ArmPose) {
        pose = newPose
        drawPose()
    }

    private func drawPose() {
        let path = UIBezierPath()

        drawArm(
            shoulder: pose.leftShoulder,
            elbow: pose.leftElbow,
            wrist: pose.leftWrist,
            into: path
        )

        drawArm(
            shoulder: pose.rightShoulder,
            elbow: pose.rightElbow,
            wrist: pose.rightWrist,
            into: path
        )

        poseLayer.path = path.cgPath
    }

    private func drawArm(
        shoulder: CGPoint?,
        elbow: CGPoint?,
        wrist: CGPoint?,
        into path: UIBezierPath
    ) {
        guard let shoulder,
              let elbow,
              let wrist else {
            return
        }

        let convertedPoints = [shoulder, elbow, wrist].map { point in
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

        path.move(to: convertedPoints[0])
        path.addLine(to: convertedPoints[1])
        path.addLine(to: convertedPoints[2])

        for point in convertedPoints {
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
