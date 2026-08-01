import SwiftUI
import AVFoundation
import Combine

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

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.black, Color(red: 0.08, green: 0.12, blue: 0.18)],
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

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()

    @State private var repCount = 0
    @State private var isCounting = false

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.7), .clear, .black.opacity(0.85)],
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
                        .font(.system(size: 100, weight: .black, design: .rounded))
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

@MainActor
final class CameraModel: ObservableObject {
    let session = AVCaptureSession()

    @Published var message: String?

    private var configured = false

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)

            if granted {
                configureAndStart()
            } else {
                message = "Camera access is required to count workouts."
            }

        case .denied, .restricted:
            message = "Enable camera access in Settings."

        @unknown default:
            message = "Camera access is unavailable."
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureAndStart() {
        guard !configured else {
            if !session.isRunning {
                session.startRunning()
            }
            return
        }

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            message = "No camera is available on this device."
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)

            session.beginConfiguration()
            session.sessionPreset = .high

            guard session.canAddInput(input) else {
                session.commitConfiguration()
                message = "The camera could not be connected."
                return
            }

            session.addInput(input)
            session.commitConfiguration()

            configured = true
            session.startRunning()
        } catch {
            message = "The camera could not be started."
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
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
