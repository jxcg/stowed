import SwiftUI

// A symbol punched out of a field of dots, the dots catching one gradient across the whole
// field so they read as metal. Used by both card styles.
struct DotMatrix: View {
    let symbol: String
    let metal: Gradient
    var spacing: CGFloat = 6
    var dot: CGFloat = 3.1

    var body: some View {
        GeometryReader { geometry in
            dots(in: geometry.size)
                .mask(
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
    }

    private func dots(in size: CGSize) -> some View {
        Canvas { context, _ in
            let sheen = GraphicsContext.Shading.linearGradient(
                metal,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: size.width * 0.4, y: size.height)
            )
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)), with: sheen)
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

// Eight marks, one per trip by its seed, so a shelf of cards is not eight of the same icon.
enum TripSymbol {
    static let all = ["mappin.and.ellipse", "airplane", "globe.europe.africa.fill",
                      "suitcase.fill", "map.fill", "mountain.2.fill",
                      "building.2.fill", "ferry.fill"]

    static func forTrip(_ trip: Trip) -> String {
        all[Int(trip.textureSeed % UInt64(all.count))]
    }
}
