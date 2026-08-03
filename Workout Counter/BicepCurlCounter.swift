import Combine
import CoreGraphics
import Foundation

#if os(iOS)

enum ExerciseArm: Hashable, Sendable {
    case left
    case right
}

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
    @Published private(set) var selectedArm: ExerciseArm?

    private enum Phase {
        case waitingForExtension
        case waitingForFlexion
    }

    private let extendedAngle: CGFloat = 145
    private let armSelectionAngle: CGFloat = 125
    private let flexedAngle: CGFloat = 80
    private let requiredStableFrames = 3
    private let maximumMissingFrames = 10
    private let minimumRepInterval = 0.5

    private var phase = Phase.waitingForExtension
    private var armedArms: Set<ExerciseArm> = []
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
        selectedArm = nil
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
        // Watch both extended arms only until one begins a clear curl.
        updateArmedArms(
            leftAngle: leftAngle,
            rightAngle: rightAngle
        )

        selectArmIfNeeded(
            leftAngle: leftAngle,
            rightAngle: rightAngle
        )

        guard let selectedArm else {
            return
        }

        let hasVisibleArmedArm =
            selectedArm == .left
                ? leftAngle != nil
                : rightAngle != nil

        if !hasVisibleArmedArm {
            missingFrames += 1

            if missingFrames > maximumMissingFrames {
                resetTransition()
            }

            return
        }

        missingFrames = 0

        if selectedArm == .left,
           let leftAngle,
           leftAngle <= flexedAngle {
            leftFlexionFrames += 1
        } else {
            leftFlexionFrames = 0
        }

        if selectedArm == .right,
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

    private func selectArmIfNeeded(
        leftAngle: CGFloat?,
        rightAngle: CGFloat?
    ) {
        guard selectedArm == nil else {
            return
        }

        var candidates: [(arm: ExerciseArm, angle: CGFloat)] = []

        if armedArms.contains(.left),
           let leftAngle,
           leftAngle <= armSelectionAngle {
            candidates.append((.left, leftAngle))
        }

        if armedArms.contains(.right),
           let rightAngle,
           rightAngle <= armSelectionAngle {
            candidates.append((.right, rightAngle))
        }

        guard let movingArm = candidates.min(
            by: { $0.angle < $1.angle }
        )?.arm else {
            return
        }

        selectedArm = movingArm
        armedArms = [movingArm]
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

        let canTrackLeft = selectedArm == nil || selectedArm == .left
        let canTrackRight = selectedArm == nil || selectedArm == .right

        if canTrackLeft,
           leftExtensionFrames >= requiredStableFrames {
            armedArms.insert(.left)
        }

        if canTrackRight,
           rightExtensionFrames >= requiredStableFrames {
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
