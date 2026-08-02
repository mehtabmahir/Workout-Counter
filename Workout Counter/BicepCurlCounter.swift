import Combine
import CoreGraphics
import Foundation

#if os(iOS)

@MainActor
protocol ExerciseCounter: AnyObject, ObservableObject {
    var repCount: Int { get }

    func process(_ pose: ArmPose)
    func reset()
    func resetMovement()
}

@MainActor
final class BicepCurlCounter: ExerciseCounter {
    @Published private(set) var repCount = 0

    private enum Arm: Hashable {
        case left
        case right
    }

    private enum Phase {
        case waitingForExtension
        case waitingForFlexion
    }

    private let extendedAngle: CGFloat = 145
    private let flexedAngle: CGFloat = 80
    private let requiredStableFrames = 3
    private let maximumMissingFrames = 10
    private let minimumRepInterval = 0.5

    private var phase = Phase.waitingForExtension
    private var armedArms: Set<Arm> = []
    private var leftExtensionFrames = 0
    private var rightExtensionFrames = 0
    private var leftFlexionFrames = 0
    private var rightFlexionFrames = 0
    private var missingFrames = 0
    private var smoothedLeftAngle: CGFloat?
    private var smoothedRightAngle: CGFloat?
    private var lastRepTime = -Double.infinity

    func process(_ pose: ArmPose) {
        let leftAngle = Self.smoothed(
            pose.leftElbowAngle,
            previous: &smoothedLeftAngle
        )
        let rightAngle = Self.smoothed(
            pose.rightElbowAngle,
            previous: &smoothedRightAngle
        )

        switch phase {
        case .waitingForExtension:
            observeExtensions(
                leftAngle: leftAngle,
                rightAngle: rightAngle
            )

        case .waitingForFlexion:
            observeFlexions(
                leftAngle: leftAngle,
                rightAngle: rightAngle
            )
        }
    }

    func reset() {
        repCount = 0
        resetMovement()
    }

    func resetMovement() {
        phase = .waitingForExtension
        armedArms.removeAll()
        leftExtensionFrames = 0
        rightExtensionFrames = 0
        leftFlexionFrames = 0
        rightFlexionFrames = 0
        missingFrames = 0
        smoothedLeftAngle = nil
        smoothedRightAngle = nil
        lastRepTime = -Double.infinity
    }

    private func observeExtensions(
        leftAngle: CGFloat?,
        rightAngle: CGFloat?
    ) {
        updateArmedArms(
            leftAngle: leftAngle,
            rightAngle: rightAngle
        )

        if !armedArms.isEmpty {
            phase = .waitingForFlexion
            missingFrames = 0
        }
    }

    private func observeFlexions(
        leftAngle: CGFloat?,
        rightAngle: CGFloat?
    ) {
        // If one arm became reliably visible a moment after the other,
        // allow it to join the same rep before either arm is flexed.
        updateArmedArms(
            leftAngle: leftAngle,
            rightAngle: rightAngle
        )

        let hasVisibleArmedArm =
            (armedArms.contains(.left) && leftAngle != nil)
            || (armedArms.contains(.right) && rightAngle != nil)

        if !hasVisibleArmedArm {
            missingFrames += 1

            if missingFrames > maximumMissingFrames {
                resetTransition()
            }

            return
        }

        missingFrames = 0

        if armedArms.contains(.left),
           let leftAngle,
           leftAngle <= flexedAngle {
            leftFlexionFrames += 1
        } else {
            leftFlexionFrames = 0
        }

        if armedArms.contains(.right),
           let rightAngle,
           rightAngle <= flexedAngle {
            rightFlexionFrames += 1
        } else {
            rightFlexionFrames = 0
        }

        guard leftFlexionFrames >= requiredStableFrames
                || rightFlexionFrames >= requiredStableFrames else {
            return
        }

        let now = ProcessInfo.processInfo.systemUptime

        if now - lastRepTime >= minimumRepInterval {
            repCount += 1
            lastRepTime = now
        }

        resetTransition()
    }

    private func resetTransition() {
        phase = .waitingForExtension
        armedArms.removeAll()
        leftExtensionFrames = 0
        rightExtensionFrames = 0
        leftFlexionFrames = 0
        rightFlexionFrames = 0
        missingFrames = 0
    }

    private func updateArmedArms(
        leftAngle: CGFloat?,
        rightAngle: CGFloat?
    ) {
        leftExtensionFrames = Self.updatedExtensionFrames(
            angle: leftAngle,
            previousFrames: leftExtensionFrames,
            threshold: extendedAngle
        )
        rightExtensionFrames = Self.updatedExtensionFrames(
            angle: rightAngle,
            previousFrames: rightExtensionFrames,
            threshold: extendedAngle
        )

        if leftExtensionFrames >= requiredStableFrames {
            armedArms.insert(.left)
        }

        if rightExtensionFrames >= requiredStableFrames {
            armedArms.insert(.right)
        }
    }

    private static func updatedExtensionFrames(
        angle: CGFloat?,
        previousFrames: Int,
        threshold: CGFloat
    ) -> Int {
        guard let angle,
              angle >= threshold else {
            return 0
        }

        return previousFrames + 1
    }

    private static func smoothed(
        _ newAngle: CGFloat?,
        previous: inout CGFloat?
    ) -> CGFloat? {
        guard let newAngle else {
            return nil
        }

        let smoothingFactor: CGFloat = 0.3

        if let previousAngle = previous {
            previous = previousAngle
                + smoothingFactor * (newAngle - previousAngle)
        } else {
            previous = newAngle
        }

        return previous
    }
}

#endif
