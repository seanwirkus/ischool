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
    @Query(sort: \Lecture.date, order: .forward) private var lectures: [Lecture]
    @Query(sort: [
        SortDescriptor(\CourseMeeting.dayOfWeek, order: .forward),
        SortDescriptor(\CourseMeeting.startHour, order: .forward),
        SortDescriptor(\CourseMeeting.startMinute, order: .forward)
    ]) private var courseMeetings: [CourseMeeting]
    @Query(sort: \Course.name, order: .forward) private var courses: [Course]

    @State private var selectedDate = Date()
    @State private var showingAddToCalendar = false
    @State private var selectedCourseIDs: Set<UUID> = []

    private let calendar = Calendar.current

    private var activeCourseIDs: Set<UUID> {
        selectedCourseIDs
    }

    private var filteredLectures: [Lecture] {
        guard !activeCourseIDs.isEmpty else { return lectures }
        return lectures.filter { lecture in
            guard let id = lecture.course?.id else { return false }
            return activeCourseIDs.contains(id)
        }
    }

    private var filteredMeetings: [CourseMeeting] {
        guard !activeCourseIDs.isEmpty else { return courseMeetings }
        return courseMeetings.filter { meeting in
            guard let id = meeting.course?.id else { return false }
            return activeCourseIDs.contains(id)
        }
    }

    private var upcomingLectures: [Lecture] {
        let todayStart = calendar.startOfDay(for: Date())
        return filteredLectures
            .filter { $0.date >= todayStart }
            .sorted { $0.date < $1.date }
    }

    private var selectedDayEvents: [CalendarScheduleEvent] {
        let weekday = calendar.component(.weekday, from: selectedDate)
        let meetingEvents = filteredMeetings
            .filter { $0.dayOfWeek == weekday }
            .compactMap { meeting -> CalendarScheduleEvent? in
                guard let course = meeting.course else { return nil }
                guard let start = meeting.startDate(on: selectedDate, calendar: calendar) else { return nil }
                let end = meeting.endDate(on: selectedDate, calendar: calendar) ?? start.addingTimeInterval(50 * 60)
                let dayComponent = calendar.component(.day, from: selectedDate)
                let monthComponent = calendar.component(.month, from: selectedDate)
                let yearComponent = calendar.component(.year, from: selectedDate)
                let identifier = "meeting-\(meeting.id.uuidString)-\(yearComponent)-\(monthComponent)-\(dayComponent)"
                return CalendarScheduleEvent(
                    id: identifier,
                    title: course.name,
                    subtitle: "Class meeting",
                    startDate: start,
                    endDate: end,
                    accentColor: course.colorValue,
                    iconName: "person.2.fill"
                )
            }

        let lectureEvents = filteredLectures
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .map { lecture -> CalendarScheduleEvent in
                let courseColor = lecture.course?.colorValue ?? .accentColor
                return CalendarScheduleEvent(
                    id: lecture.id.uuidString,
                    title: lecture.title,
                    subtitle: lecture.course?.name ?? "Lecture",
                    startDate: lecture.date,
                    endDate: lecture.date.addingTimeInterval(60 * 60),
                    accentColor: courseColor,
                    iconName: "book.fill"
                )
            }

        return (meetingEvents + lectureEvents).sorted { $0.startDate < $1.startDate }
    }

    private var selectedDaySummary: String {
        let meetingCount = filteredMeetings.filter { $0.dayOfWeek == calendar.component(.weekday, from: selectedDate) }.count
        let lectureCount = filteredLectures.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }.count
        switch (meetingCount, lectureCount) {
        case (0, 0):
            return "No scheduled items"
        case (_, 0):
            return "\(meetingCount) class \(meetingCount == 1 ? "meeting" : "meetings")"
        case (0, _):
            return "\(lectureCount) lecture\(lectureCount == 1 ? "" : "s")"
        default:
            let meetingPart = "\(meetingCount) class \(meetingCount == 1 ? "meeting" : "meetings")"
            let lecturePart = "\(lectureCount) lecture\(lectureCount == 1 ? "" : "s")"
            return "\(meetingPart) • \(lecturePart)"
        }
    }

    private var recurringByWeekday: [(Int, [CourseMeeting])]
    {
        let grouped = Dictionary(grouping: filteredMeetings) { $0.dayOfWeek }
        return grouped
            .map { ($0.key, $0.value.sorted(by: { ($0.startHour, $0.startMinute) < ($1.startHour, $1.startMinute) })) }
            .sorted { lhs, rhs in
                lhs.0 < rhs.0
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    summaryCard
                    weekSelector
                    dayScheduleSection
                    recurringSection
                    upcomingSection
                }
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
            .background(Color.platformElevatedBackground.ignoresSafeArea())
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddToCalendar = true
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                    .accessibilityLabel("Add events to calendar")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            selectedCourseIDs.removeAll()
                        } label: {
                            Label("All Courses", systemImage: activeCourseIDs.isEmpty ? "checkmark.circle.fill" : "circle")
                        }
                        if !courses.isEmpty {
                            Divider()
                        }
                        ForEach(courses, id: \.id) { course in
                            let isSelected = activeCourseIDs.contains(course.id)
                            Button {
                                toggleCourse(course.id)
                            } label: {
                                Label(course.name, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    } label: {
                        Image(systemName: activeCourseIDs.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("Filter courses")
                }
            }
            .sheet(isPresented: $showingAddToCalendar) {
                AddToCalendarSheet(lectures: upcomingLectures)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !activeCourseIDs.isEmpty {
                Text("\(activeCourseIDs.count) course\(activeCourseIDs.count == 1 ? "" : "s") selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.title2.bold())
            Text(selectedDaySummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }

    private var weekSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(displayedWeek, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedDate = date
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.footnote.smallCaps())
                            Text(date.formatted(.dateTime.day()))
                                .font(.title3.bold())
                        }
                        .frame(width: 64, height: 72)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.platformCardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var dayScheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily Schedule")
                    .font(.headline)
                Spacer()
                Button {
                    selectedDate = Date()
                } label: {
                    Label("Today", systemImage: "location")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .opacity(calendar.isDate(selectedDate, inSameDayAs: Date()) ? 0.3 : 1)
                .disabled(calendar.isDate(selectedDate, inSameDayAs: Date()))
            }
            if selectedDayEvents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No events scheduled")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(selectedDayEvents) { event in
                        CalendarScheduleRow(event: event)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.platformCardBackground)
        )
        .padding(.horizontal, 20)
    }

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Class Pattern")
                .font(.headline)
            if recurringByWeekday.isEmpty {
                Text("Add meeting days to your courses to build a weekly routine.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(recurringByWeekday, id: \.0) { day, meetings in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(weekdayName(for: day))
                                .font(.subheadline.bold())
                            ForEach(meetings, id: \.id) { meeting in
                                HStack(spacing: 10) {
                                    if let color = meeting.course?.colorValue {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 10, height: 10)
                                    }
                                    Text(meeting.course?.name ?? "Course")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(meeting.timeRangeDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.platformElevatedBackground)
                        )
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.platformCardBackground)
        )
        .padding(.horizontal, 20)
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Lectures")
                    .font(.headline)
                Spacer()
                Button("Add to Calendar") {
                    showingAddToCalendar = true
                }
                .buttonStyle(.borderedProminent)
                .font(.footnote)
            }
            if upcomingLectures.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No upcoming lectures")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Add lectures or schedule meetings to populate your agenda.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(upcomingLectures, id: \.id) { lecture in
                        LectureCalendarCardView(lecture: lecture)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.platformCardBackground)
        )
        .padding(.horizontal, 20)
    }

    private var displayedWeek: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
    }

    private func toggleCourse(_ id: UUID) {
        if selectedCourseIDs.contains(id) {
            selectedCourseIDs.remove(id)
        } else {
            selectedCourseIDs.insert(id)
        }
    }

    private func weekdayName(for weekday: Int) -> String {
        let index = (weekday - 1 + 7) % 7
        let symbols = calendar.weekdaySymbols
        guard symbols.indices.contains(index) else { return "Day" }
        return symbols[index]
    }
}

private struct CalendarScheduleEvent: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let startDate: Date
    let endDate: Date
    let accentColor: Color
    let iconName: String
}

private struct CalendarScheduleRow: View {
    let event: CalendarScheduleEvent

    private static let timeFormatter = Date.FormatStyle.dateTime.hour().minute()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(event.accentColor.opacity(0.15))
                Image(systemName: event.iconName)
                    .foregroundStyle(event.accentColor)
                    .font(.headline)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                Text(event.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Self.timeFormatter.format(event.startDate))
                    .font(.footnote.monospacedDigit())
                Text(Self.timeFormatter.format(event.endDate))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.platformElevatedBackground)
        )
    }
}

struct LectureCalendarCardView: View {
    let lecture: Lecture

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private var accentColor: Color {
        lecture.course?.colorValue ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accentColor)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(lecture.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(lecture.date, style: .time)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary)
                }

                if let courseName = lecture.course?.name {
                    Text(courseName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(lecture.date.formatted(date: .long, time: .omitted), systemImage: "calendar")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Self.relativeFormatter.localizedString(for: lecture.date, relativeTo: Date()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.platformElevatedBackground)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct AddToCalendarSheet: View {
    let lectures: [Lecture]
    @Environment(\.dismiss) private var dismiss
    @State private var eventStore = EKEventStore()

    var body: some View {
        NavigationStack {
            Group {
                if lectures.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No upcoming lectures available")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Schedule lectures to push them to your system calendar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        Section {
                            Button {
                                addAllToCalendar()
                            } label: {
                                Label("Add all upcoming", systemImage: "calendar.badge.plus")
                            }
                        }

                        Section("Lectures") {
                            ForEach(lectures, id: \.id) { lecture in
                                Button(action: { addToCalendar(lecture) }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lecture.title)
                                            .font(.headline)
                                        if let courseName = lecture.course?.name {
                                            Text(courseName)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(lecture.date, format: .dateTime.weekday().month().day().hour().minute())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Add to Calendar")
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
        event.endDate = lecture.date.addingTimeInterval(3600)
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            print("Event saved to calendar")
        } catch {
            print("Error saving event: \(error)")
        }
    }

    private func addAllToCalendar() {
        lectures.forEach { addToCalendar($0) }
        dismiss()
    }
}

private extension CourseMeeting {
    func startDate(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: day)
    }

    func endDate(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: day)
    }

    var timeRangeDescription: String {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: Date()) ?? Date()
        let end = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: start) ?? start.addingTimeInterval(50 * 60)
        let formatter = Date.FormatStyle.dateTime.hour().minute()
        let startText = formatter.format(start)
        let endText = formatter.format(end)
        if startText == endText {
            return startText
        }
        return "\(startText) – \(endText)"
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
