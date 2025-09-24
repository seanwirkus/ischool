//
//  QuickFileCourseSelector.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI

struct QuickFileCourseSelector: View {
    let courses: [Course]
    let onSelect: (Course) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(courses, id: \.id) { course in
                    Button(action: {
                        onSelect(course)
                        dismiss()
                    }) {
                        HStack {
                            Circle()
                                .fill(course.colorValue)
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading) {
                                Text(course.name)
                                    .font(.headline)
                                let lecture = findNearestLecture(for: course)
                                if let lecture = lecture {
                                    Text("Will link to: \(lecture.title)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("General course files")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Link Files to Course")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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