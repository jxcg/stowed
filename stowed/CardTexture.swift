import CoreGraphics
import Foundation

// Procedural texture under the grain (decision 24). Drawn from the trip's own initial, dates
// and name. Seeded from the trip so a card looks the same every launch.
enum CardTexture: String, CaseIterable {
    case scatter, lattice, stamp
}

// SplitMix64. Tiny, deterministic, good enough for scattering glyphs.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    // 0..<1
    mutating func unit() -> CGFloat { CGFloat(next() >> 11) / CGFloat(1 << 53) }
}
