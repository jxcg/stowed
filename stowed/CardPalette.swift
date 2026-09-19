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

    // Hard-edged metal: light, dark, light, dark across the diagonal, with abrupt turns rather
    // than a smooth blend. That is what makes it read as foil instead of paint.
    var frameGradient: LinearGradient {
        let pale: Color, deep: Color
        switch frame {
        case .tone:
            pale = Color(hue: hue, saturation: saturation * 0.2, brightness: 1)
            deep = Color(hue: hue, saturation: min(1, saturation + 0.1), brightness: 0.45)
        case .gold:
            pale = Color(hue: 0.14, saturation: 0.25, brightness: 1)
            deep = Color(hue: 0.08, saturation: 0.95, brightness: 0.45)
        }
        return LinearGradient(
            stops: [
                .init(color: pale, location: 0),
                .init(color: deep, location: 0.2),
                .init(color: pale, location: 0.38),
                .init(color: pale, location: 0.46),
                .init(color: deep, location: 0.66),
                .init(color: pale, location: 0.86),
                .init(color: deep, location: 1),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // The other card style's colourway: ten hues, one per palette, spread right across the
    // spectrum. The gradient is built the same way for all of them.
    var neonHue: Double {
        switch self {
        case .oxblood: 0.95    // rose
        case .navy: 0.66       // indigo
        case .forest: 0.38     // spring
        case .plum: 0.80       // violet
        case .slate: 0.58      // azure
        case .rust: 0.04       // coral
        case .teal: 0.48       // cyan
        case .charcoal: 0.72   // ultraviolet
        case .ochre: 0.12      // amber
        case .bordeaux: 0.88   // magenta
        }
    }

    // The card's edge, seen under the face.
    var stock: Color { Color(hue: hue, saturation: saturation * 0.5, brightness: 0.3) }
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
