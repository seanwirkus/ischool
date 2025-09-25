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

    private var isSaveDisabled: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !selectedDays.isEmpty else { return true }

        for day in selectedDays {
            guard let times = meetingTimes[day] else { return true }
            if times.end <= times.start { return true }
        }

        return false
    }

    private var orderedSelectedDays: [(label: String, index: Int)] {
        weekdayOrder.filter { selectedDays.contains($0.index) }
    }

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
                        ForEach(colors, id: \.self) { hex in
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

                Section(
                    header: Text("Meeting Schedule"),
                    footer: Text("Pick the days and time blocks your class meets. We'll use this pattern to build the initial lecture schedule.")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 8), count: 4), spacing: 8) {
                            ForEach(weekdayOrder, id: \.index) { day in
                                let isSelected = selectedDays.contains(day.index)
                                Button {
                                    toggleDaySelection(day.index)
                                } label: {
                                    Text(day.label)
                                        .font(.footnote.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.platformChipBackground)
                                        )
                                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                            }
                        }

                        if orderedSelectedDays.isEmpty {
                            Text("Choose at least one day to set meeting times.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(orderedSelectedDays, id: \.index) { day in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("\(day.label) Meeting")
                                            .font(.subheadline.weight(.semibold))
                                        HStack {
                                            DatePicker(
                                                "Start",
                                                selection: startBinding(for: day.index),
                                                displayedComponents: .hourAndMinute
                                            )
                                            .labelsHidden()
                                            .datePickerStyle(.compact)

                                            Image(systemName: "arrow.right")
                                                .foregroundStyle(.secondary)

                                            DatePicker(
                                                "End",
                                                selection: endBinding(for: day.index),
                                                displayedComponents: .hourAndMinute
                                            )
                                            .labelsHidden()
                                            .datePickerStyle(.compact)
                                        }
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel("Meeting time for \(day.label)")
                                        .accessibilityValue(formattedRange(for: day.index))
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.platformCardBackground)
                                    )
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
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
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    private func toggleDaySelection(_ dayIndex: Int) {
        if selectedDays.contains(dayIndex) {
            selectedDays.remove(dayIndex)
        } else {
            selectedDays.insert(dayIndex)
            if meetingTimes[dayIndex] == nil {
                let calendar = Calendar.current
                let defaultStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                let defaultEnd = calendar.date(bySettingHour: 10, minute: 15, second: 0, of: Date()) ?? defaultStart.addingTimeInterval(60 * 45)
                meetingTimes[dayIndex] = (start: defaultStart, end: defaultEnd)
            }
        }
    }

    private func startBinding(for dayIndex: Int) -> Binding<Date> {
        Binding<Date>(
            get: {
                meetingTimes[dayIndex]?.start ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                var times = meetingTimes[dayIndex] ?? (start: newValue, end: newValue.addingTimeInterval(60 * 45))
                times.start = newValue
                if times.end <= newValue {
                    times.end = Calendar.current.date(byAdding: .minute, value: 45, to: newValue) ?? newValue.addingTimeInterval(60 * 45)
                }
                meetingTimes[dayIndex] = times
            }
        )
    }

    private func endBinding(for dayIndex: Int) -> Binding<Date> {
        Binding<Date>(
            get: {
                meetingTimes[dayIndex]?.end ?? Calendar.current.date(bySettingHour: 10, minute: 15, second: 0, of: Date()) ?? Date().addingTimeInterval(60 * 45)
            },
            set: { newValue in
                var times = meetingTimes[dayIndex] ?? (start: newValue.addingTimeInterval(-60 * 45), end: newValue)
                times.end = newValue
                if times.end <= times.start {
                    times.start = Calendar.current.date(byAdding: .minute, value: -45, to: newValue) ?? newValue.addingTimeInterval(-60 * 45)
                }
                meetingTimes[dayIndex] = times
            }
        )
    }

    private func formattedRange(for dayIndex: Int) -> String {
        guard let times = meetingTimes[dayIndex] else { return "Time not set" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: times.start)) to \(formatter.string(from: times.end))"
    }
}
