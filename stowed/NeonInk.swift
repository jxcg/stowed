import SwiftUI

// A trip's colours.
// In: the trip's accent hue, light or dark mode, its metal finish, and the phone's tilt.
// Out: the metal card's inks (near-white steel, dark text, the finish's warm and cool light),
// plus the accent-tinted ground and rim the bag screen draws with.
struct NeonInk {
    let accent: Double
    let dark: Bool
    var finish: MetalFinish = .silver
    var tilt: CGSize = .zero

    private func shifted(_ amount: Double) -> Double { (accent + amount + 1).truncatingRemainder(dividingBy: 1) }

    // MARK: The metal card

    var glow: Color { finish.warm }
    var glow2: Color { finish.cool }
    var haze: Color { Color(white: 0.88) }
    var text: Color { Color(white: 0.13) }
    // The dot matrix's metal.
    var metal: Gradient { Gradient(colors: [Color(white: 0.62), Color(white: 0.34), Color(white: 0.58), Color(white: 0.26)]) }
    var separation: Color { Color(white: 0.86) }

    // Anodised edges shift colour with the angle you hold them at. This is that, at a whisper:
    // a few hundredths of a turn around the wheel, and nothing at all when the card is flat.
    private var edgeShift: Double { max(-0.045, min(0.045, tilt.width / 12 * 0.045)) }

    var metalRim: LinearGradient {
        LinearGradient(colors: [Color(hue: (0.58 + edgeShift + 1).truncatingRemainder(dividingBy: 1),
                                      saturation: abs(edgeShift) * 2.2, brightness: 0.97),
                                Color(hue: (0.06 - edgeShift + 1).truncatingRemainder(dividingBy: 1),
                                      saturation: abs(edgeShift) * 1.8, brightness: 0.55)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: The bag screen

    // Pale blue into lavender by day, deep indigo by night.
    var ground: LinearGradient {
        let stops: [Color] = dark
            ? [Color(hue: 0.70, saturation: 0.55, brightness: 0.36), Color(hue: 0.73, saturation: 0.7, brightness: 0.16)]
            : [Color(hue: 0.58, saturation: 0.1, brightness: 0.99), Color(hue: 0.73, saturation: 0.14, brightness: 0.92)]
        return LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
    }

    // The trip's accent, running from light to dark across the frame.
    var rim: LinearGradient {
        LinearGradient(colors: [Color(hue: shifted(edgeShift), saturation: dark ? 0.42 : 0.5, brightness: dark ? 0.82 : 0.9),
                                Color(hue: shifted(-0.09 - edgeShift), saturation: dark ? 0.8 : 0.7, brightness: dark ? 0.46 : 0.68)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
