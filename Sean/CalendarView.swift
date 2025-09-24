//
//  CalendarView.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI
import SwiftData
import EventKit

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Lecture.date, order: .forward) private var lectures: [Lecture]

    @State private var selectedDate = Date()
    @State private var showingAddToCalendar = false

    var upcomingLectures: [Lecture] {
        lectures.filter { $0.date >= Date() }.sorted(by: { $0.date < $1.date })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Lecture Calendar")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Button(action: { showingAddToCalendar = true }) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Lectures list
                    ScrollView {
                        VStack(spacing: 16) {
                            if upcomingLectures.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                    Text("No upcoming lectures")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    Text("Add lectures to your classes to see them here")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 60)
                            } else {
                                ForEach(upcomingLectures) { lecture in
                                    LectureCalendarCardView(lecture: lecture)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .sheet(isPresented: $showingAddToCalendar) {
                AddToCalendarSheet(lectures: upcomingLectures)
            }
        }
    }
}

struct LectureCalendarCardView: View {
    let lecture: Lecture

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lecture.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let courseName = lecture.course?.name {
                        Text(courseName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(lecture.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(lecture.date, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    if lecture.date.isToday {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if lecture.date.isTomorrow {
                        Text("Tomorrow")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(16)
        }
        .frame(height: 80)
    }
}

struct AddToCalendarSheet: View {
    let lectures: [Lecture]
    @Environment(\.dismiss) private var dismiss
    @State private var eventStore = EKEventStore()

    var body: some View {
        NavigationStack {
            List {
                ForEach(lectures) { lecture in
                    Button(action: { addToCalendar(lecture) }) {
                        VStack(alignment: .leading) {
                            Text(lecture.title)
                                .font(.headline)
                            Text(lecture.course?.name ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(lecture.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add to iCloud Calendar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                requestCalendarAccess()
            }
        }
    }

    private func requestCalendarAccess() {
        if #available(iOS 17.0, macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                if let error = error {
                    print("Error requesting calendar access: \(error)")
                }
                if !granted {
                    print("Calendar access not granted.")
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                if let error = error {
                    print("Error requesting calendar access: \(error)")
                }
                if !granted {
                    print("Calendar access not granted.")
                }
            }
        }
    }

    private func addToCalendar(_ lecture: Lecture) {
        let event = EKEvent(eventStore: eventStore)
        event.title = "\(lecture.course?.name ?? "Course"): \(lecture.title)"
        event.startDate = lecture.date
        event.endDate = lecture.date.addingTimeInterval(3600) // 1 hour
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            print("Event saved to calendar")
        } catch {
            print("Error saving event: \(error)")
        }
    }
}

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
}
