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
        manager.deviceMotionUpdateInterval = 1 / 20
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude else { return }
            // Clamp to a few points so it reads as a sheen shift, not a wobble.
            let next = CGSize(
                width: max(-12, min(12, attitude.roll * 24)),
                height: max(-12, min(12, attitude.pitch * 24))
            )
            // A hand at rest still jitters. Ignoring movements too small to see saves a redraw
            // of the whole deck on most ticks.
            guard abs(next.width - self.tilt.width) > 0.2 || abs(next.height - self.tilt.height) > 0.2 else { return }
            self.tilt = next
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isRunning = false
        tilt = .zero
    }
}
