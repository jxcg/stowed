import SwiftUI

// Curated card colours (decision 21). One deep hue per palette for the face; the frame is
// the only place a second colour appears, either a tint of the same hue or gold foil.
enum CardPalette: String, CaseIterable {
    case oxblood, navy, forest, plum, slate, rust, teal, charcoal, ochre, bordeaux

    enum Frame { case tone, gold }

    var hue: Double {
        switch self {
        case .oxblood: 0.98
        case .navy: 0.62
        case .forest: 0.38
        case .plum: 0.80
        case .slate: 0.58
        case .rust: 0.05
        case .teal: 0.48
        case .charcoal: 0.60
        case .ochre: 0.10
        case .bordeaux: 0.93
        }
    }

    var saturation: Double {
        switch self {
        case .slate, .charcoal: 0.18
        default: 0.75
        }
    }

    var frame: Frame {
        switch self {
        case .navy, .forest, .plum, .bordeaux: .gold
        default: .tone
        }
    }

    // Face: mid tone in the centre, darker at the edge.
    var centre: Color { Color(hue: hue, saturation: saturation, brightness: 0.5) }
    var edge: Color { Color(hue: hue, saturation: min(1, saturation + 0.1), brightness: 0.24) }

    var frameGradient: LinearGradient {
        let colors: [Color] = switch frame {
        case .tone: [Color(hue: hue, saturation: saturation * 0.4, brightness: 0.97), Color(hue: hue, saturation: saturation * 0.65, brightness: 0.8)]
        case .gold: [Color(hue: 0.12, saturation: 0.55, brightness: 0.95), Color(hue: 0.10, saturation: 0.7, brightness: 0.7)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// One suit per trip, picked at random and kept. The pip in the corners.
enum CardSuit: String, CaseIterable {
    case spade, heart, diamond, club

    var glyph: String {
        switch self {
        case .spade: "♠"
        case .heart: "♥"
        case .diamond: "♦"
        case .club: "♣"
        }
    }
}
