import SwiftData
import SwiftUI

// A trip's plans, by day (#98).
// In: the trip. Out: one section per day, then Unscheduled. Tap a plan to edit it, swipe to
// delete it, + to add one.
struct TripPlansView: View {
    @Environment(\.modelContext) private var context
    let trip: Trip
    @State private var isAdding = false
    @State private var planToEdit: TripPlan?
    @State private var deleteFailed = false

    var body: some View {
        Group {
            if trip.plans.isEmpty {
                ContentUnavailableView(
                    "No plans yet",
                    systemImage: "calendar",
                    description: Text("Tap + to add a journey, a stay, or an idea.")
                )
            } else {
                List(trip.planSections) { section in
                    Section {
                        ForEach(section.plans) { plan in
                            Button { planToEdit = plan } label: { PlanRow(plan: plan) }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button("Delete", systemImage: "trash", role: .destructive) { delete(plan) }
                                }
                        }
                    } header: {
                        heading(for: section)
                    }
                }
            }
        }
        .navigationTitle("Plans")
        .toolbar {
            Button("Add plan", systemImage: "plus") { isAdding = true }
        }
        .sheet(isPresented: $isAdding) { PlanForm(trip: trip, plan: nil) }
        .sheet(item: $planToEdit) { PlanForm(trip: trip, plan: $0) }
        .alert("Couldn’t delete plan", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your plan is still here. Please try again.")
        }
    }

    // Saved at once, so a deleted plan cannot come back if the app is closed straight after.
    private func delete(_ plan: TripPlan) {
        context.delete(plan)
        do {
            try context.save()
        } catch {
            context.rollback()
            deleteFailed = true
        }
    }

    // In: a section. Out: its date with the year, since a plan can sit outside the trip's dates.
    @ViewBuilder private func heading(for section: PlanSection) -> some View {
        if let key = section.day, let date = PlanDay().date(for: key) {
            Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year())
        } else {
            Text("Unscheduled")
        }
    }
}

// symbol | title, then location and notes when they exist.
private struct PlanRow: View {
    let plan: TripPlan

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: plan.planCategory.symbol)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel(plan.planCategory.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                if !plan.location.isEmpty {
                    Text(plan.location).font(.subheadline).foregroundStyle(.secondary)
                }
                if !plan.notes.isEmpty {
                    Text(plan.notes).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// Add or edit a plan. plan == nil means add. Nothing is saved until Save.
private struct PlanForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let trip: Trip
    let plan: TripPlan?
    @State private var title: String
    @State private var category: PlanCategory
    @State private var location: String
    @State private var notes: String
    @State private var isScheduled: Bool
    @State private var date: Date
    @State private var saveFailed = false

    init(trip: Trip, plan: TripPlan?) {
        self.trip = trip
        self.plan = plan
        _title = State(initialValue: plan?.title ?? "")
        _category = State(initialValue: plan?.planCategory ?? .activity)
        _location = State(initialValue: plan?.location ?? "")
        _notes = State(initialValue: plan?.notes ?? "")
        _isScheduled = State(initialValue: plan?.day != nil)
        let saved = plan?.day.flatMap { PlanDay().date(for: $0) }
        _date = State(initialValue: saved ?? trip.startDate ?? .now)
    }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                Picker("Type", selection: $category) {
                    ForEach(PlanCategory.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                TextField("Location", text: $location)
                Toggle("On a day", isOn: $isScheduled)
                if isScheduled {
                    // No limit to the trip's dates: a plan outside them has to keep its day.
                    DatePicker("Day", selection: $date, displayedComponents: .date)
                }
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...)
            }
            .navigationTitle(plan == nil ? "New plan" : "Edit plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmed(title).isEmpty)
                }
            }
            .alert("Couldn’t save plan", isPresented: $saveFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your plan wasn’t saved. Please try again.")
            }
        }
    }

    // Written to disk before the sheet closes. Left to autosave, a plan was lost if the app was
    // closed straight after. If the write fails the form stays open with what was typed.
    private func save() {
        let target = plan ?? TripPlan(title: "")
        target.title = trimmed(title)
        target.category = category.rawValue
        target.location = trimmed(location)
        target.notes = trimmed(notes)
        target.day = isScheduled ? PlanDay().key(for: date) : nil
        if plan == nil { trip.plans.append(target) }
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            saveFailed = true
        }
    }
}
