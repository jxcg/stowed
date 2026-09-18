import SwiftData
import SwiftUI

@main struct StowedApp: App {
    var body: some Scene {
        WindowGroup {
            TripListView()
        }
        .modelContainer(for: Trip.self)
    }
}
