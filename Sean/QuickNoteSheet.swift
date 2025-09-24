//
//  QuickNoteSheet.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI

struct QuickNoteSheet: View {
    let courses: [Course]
    let onSave: (String, Course) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var content = ""
    @State private var selectedCourse: Course?

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick Note") {
                    TextField("What's on your mind?", text: $content, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section("Link to Course") {
                    Picker("Course", selection: $selectedCourse) {
                        Text("Choose course...").tag(Course?.none)
                        ForEach(courses, id: \.id) { course in
                            Text(course.name).tag(course as Course?)
                        }
                    }
                }

                if let course = selectedCourse {
                    Section("Will be linked to") {
                        let lecture = findNearestLecture(for: course)
                        if let lecture = lecture {
                            Text("Next lecture: \(lecture.title)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("General course notes")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Quick Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let course = selectedCourse {
                            onSave(content, course)
                            dismiss()
                        }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCourse == nil)
                }
            }
        }
    }

    private func findNearestLecture(for course: Course) -> Lecture? {
        let now = Date()
        let todayLectures = course.lectures.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
        if let todayLecture = todayLectures.sorted(by: { $0.date < $1.date }).first(where: { $0.date >= now }) {
            return todayLecture
        }
        if let firstTodayLecture = todayLectures.sorted(by: { $0.date < $1.date }).first {
            return firstTodayLecture
        }

        // Find next upcoming lecture
        let upcomingLectures = course.lectures.filter { $0.date > now }.sorted(by: { $0.date < $1.date })
        return upcomingLectures.first
    }
}