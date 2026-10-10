import SwiftUI

// One base, two modes (decision 30). The ground is the same on every card: pale blue into
// lavender by day, deep indigo by night. Only the accent moves from trip to trip, and it never
// leaves the band between cyan and magenta, so a wall of these still looks like one set.
struct NeonInk {
    let accent: Double
    let dark: Bool
    // The metal print is pearl: near-white, whatever the system scheme is.
    var pearl = false
    var finish: MetalFinish = .silver
    var tilt: CGSize = .zero

    private func shifted(_ amount: Double) -> Double { (accent + amount + 1).truncatingRemainder(dividingBy: 1) }

    var ground: LinearGradient {
        if pearl {
            // BeadBlastSteel paints the surface; this is only what shows through it.
            return LinearGradient(colors: [Color(white: 0.9), Color(white: 0.55)],
                                  startPoint: .top, endPoint: .bottom)
        }
        let stops: [Color] = dark
            ? [Color(hue: 0.70, saturation: 0.55, brightness: 0.36), Color(hue: 0.73, saturation: 0.7, brightness: 0.16)]
            : [Color(hue: 0.58, saturation: 0.1, brightness: 0.99), Color(hue: 0.73, saturation: 0.14, brightness: 0.92)]
        return LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
    }

    var glow: Color {
        pearl ? finish.warm
              : Color(hue: accent, saturation: dark ? 0.5 : 0.55, brightness: dark ? 0.86 : 0.6)
    }
    var glow2: Color {
        pearl ? finish.cool
              : Color(hue: shifted(0.05), saturation: dark ? 0.22 : 0.45, brightness: dark ? 0.95 : 0.55)
    }
    var haze: Color {
        pearl ? Color(white: 0.88) : Color(hue: shifted(-0.02), saturation: dark ? 0.55 : 0.2, brightness: dark ? 0.44 : 0.92)
    }
    var text: Color {
        pearl ? Color(white: 0.13) : (dark ? .white : Color(hue: 0.73, saturation: 0.7, brightness: 0.3))
    }
    // Brushed metal for the dot matrix.
    var metal: Gradient {
        if pearl { return Gradient(colors: [Color(white: 0.62), Color(white: 0.34), Color(white: 0.58), Color(white: 0.26)]) }
        return Gradient(colors: dark
            ? [Color(white: 1), Color(white: 0.78), Color(white: 0.92), Color(white: 0.6)]
            : [Color(white: 0.98), Color(white: 0.62), Color(white: 0.85), Color(white: 0.45)])
    }
    // The pearl shift, taken from Apple's Siri diagram: blush, lavender, aqua, sage, cream.
    var splash: Color {
        pearl ? Color(hue: shifted(0.1), saturation: 0.22, brightness: 0.98)
              : (dark ? Color(hue: 0.57, saturation: 0.3, brightness: 0.9) : Color(hue: 0.72, saturation: 0.5, brightness: 0.62))
    }
    var separation: Color {
        pearl ? Color(white: 0.86) : (dark ? Color(hue: 0.73, saturation: 0.8, brightness: 0.1) : Color(hue: 0.72, saturation: 0.2, brightness: 0.8))
    }
    // Anodised edges shift colour with the angle you hold them at. This is that, at a whisper:
    // a few hundredths of a turn around the wheel, and nothing at all when the card is flat.
    private var edgeShift: Double { max(-0.045, min(0.045, tilt.width / 12 * 0.045)) }

    var rim: LinearGradient {
        if pearl {
            return LinearGradient(colors: [Color(hue: (0.58 + edgeShift + 1).truncatingRemainder(dividingBy: 1),
                                                 saturation: abs(edgeShift) * 2.2, brightness: 0.97),
                                           Color(hue: (0.06 - edgeShift + 1).truncatingRemainder(dividingBy: 1),
                                                 saturation: abs(edgeShift) * 1.8, brightness: 0.55)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [Color(hue: shifted(edgeShift), saturation: dark ? 0.42 : 0.5, brightness: dark ? 0.82 : 0.9),
                                       Color(hue: shifted(-0.09 - edgeShift), saturation: dark ? 0.8 : 0.7, brightness: dark ? 0.46 : 0.68)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
