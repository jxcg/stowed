import SwiftUI

// ponytail: placeholder, #6 fills this with the item list.
struct BagDetailView: View {
    let bag: Bag

    var body: some View {
        ContentUnavailableView("Nothing packed yet", systemImage: "tshirt", description: Text("Items arrive in the next issue."))
            .navigationTitle("\(bag.emoji) \(bag.name)")
    }
}
