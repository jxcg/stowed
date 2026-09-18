import CoreGraphics
import CoreMotion
import Observation

// Phone tilt as a small offset, for the card sheen (decision 23). Nothing in the simulator.
@Observable
final class MotionReader {
    private(set) var tilt: CGSize = .zero
    private(set) var isRunning = false
    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        isRunning = true
        manager.deviceMotionUpdateInterval = 1 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let attitude = motion?.attitude else { return }
            // Clamp to a few points so it reads as a sheen shift, not a wobble.
            self?.tilt = CGSize(
                width: max(-12, min(12, attitude.roll * 24)),
                height: max(-12, min(12, attitude.pitch * 24))
            )
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isRunning = false
        tilt = .zero
    }
}
