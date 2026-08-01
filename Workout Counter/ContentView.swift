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
    @StateObject private var camera = CameraModel()

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            if let message = camera.message {
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()
            }
        }
        .task {
            await camera.start()
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
