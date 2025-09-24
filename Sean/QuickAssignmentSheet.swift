//
//  QuickAssignmentSheet.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI

struct QuickAssignmentSheet: View {
    let courses: [Course]
    let onSave: (String, String?, Date?, String, Course) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var dueDate: Date? = nil
    @State private var hasDueDate = false
    @State private var priority = "Medium"
    @State private var selectedCourse: Course?

    let priorities = ["Low", "Medium", "High"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick Assignment") {
                    TextField("Assignment title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Link to Course") {
                    Picker("Course", selection: $selectedCourse) {
                        Text("Choose course...").tag(Course?.none)
                        ForEach(courses, id: \.id) { course in
                            Text(course.name).tag(course as Course?)
                        }
                    }
                }

                Section("Due Date") {
                    Toggle("Has due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due Date", selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ), displayedComponents: .date)
                    }
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(priorities, id: \.self) { priority in
                            Text(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Quick Assignment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let course = selectedCourse {
                            onSave(title, description.isEmpty ? nil : description, hasDueDate ? dueDate : nil, priority, course)
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCourse == nil)
                }
            }
        }
    }
}