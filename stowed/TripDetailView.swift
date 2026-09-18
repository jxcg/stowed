import SwiftUI

// ponytail: placeholder, #5 fills this with the bag list.
struct TripDetailView: View {
    let trip: Trip

    var body: some View {
        ContentUnavailableView("No bags yet", systemImage: "bag", description: Text("Bags arrive in the next issue."))
            .navigationTitle(trip.name)
    }
}
