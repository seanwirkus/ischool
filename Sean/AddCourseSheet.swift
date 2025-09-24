//
//  AddCourseSheet.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI


struct AddCourseSheet: View {
    @State private var meetingTimes: [Int: (start: Date, end: Date)] = [:]
    let onSave: (String, String?, String, Int?, [CourseMeeting]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var color = "#4ECDC4"
    @State private var units: Int = 0

    // Apple tag-like palette
    let colors = ["#8E8E93", "#FF453A", "#FF9F0A", "#FFD60A", "#30D158", "#0A84FF", "#BF5AF2"]

    private let weekdayOrder: [(label: String, index: Int)] = [
        ("Mon", 2), ("Tue", 3), ("Wed", 4), ("Thu", 5), ("Fri", 6), ("Sat", 7), ("Sun", 1)
    ]
    private let colorGridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    @State private var selectedDays: Set<Int> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Course Name", text: $name)
                        .font(.title3)
                        .padding(.vertical, 2)
                    TextField("Description", text: $description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                }
                Section(header: Text("Details & Appearance")) {
                    TextField("Units", value: $units, formatter: NumberFormatter())
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 2)
                    Text("Course Color")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    LazyVGrid(columns: colorGridColumns, spacing: 12) {
                        ForEach(colors, id: \ .self) { hex in
                            Button(action: { color = hex }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex) ?? .blue)
                                        .frame(width: 32, height: 32)
                                    if color == hex {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .font(.caption.bold())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Course")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let meetings = selectedDays.compactMap { dayIndex -> CourseMeeting? in
                            guard let times = meetingTimes[dayIndex] else { return nil }
                            let startComponents = Calendar.current.dateComponents([.hour, .minute], from: times.start)
                            let endComponents = Calendar.current.dateComponents([.hour, .minute], from: times.end)
                            return CourseMeeting(
                                dayOfWeek: dayIndex,
                                startHour: startComponents.hour ?? 9,
                                startMinute: startComponents.minute ?? 0,
                                endHour: endComponents.hour ?? 10,
                                endMinute: endComponents.minute ?? 0
                            )
                        }
                        onSave(name, description.isEmpty ? nil : description, color, units > 0 ? units : nil, meetings)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedDays.isEmpty)
                }
            }
        }
    }
}
