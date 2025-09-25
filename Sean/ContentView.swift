import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var courseToDelete: Course? = nil
    @State private var showDeleteAlert: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.createdDate, order: .reverse) private var courses: [Course]
    @Query(sort: \Lecture.date, order: .forward) private var lectures: [Lecture]

    @State private var showingAddCourseSheet = false
    @State private var selectedCourse: Course? = nil
    @State private var showingCalendar = false
    @State private var showingQuickNoteSheet = false
    @State private var showingQuickFileImporter = false
    @State private var showingQuickAssignmentSheet = false
    @State private var showingQuickFileCourseSelector = false
    @State private var pendingFileURLs: [URL] = []

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let size = proxy.size
                let isCompactWidth = size.width < 700

                ZStack {
                    HomeBackground()
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            header(isCompactWidth: isCompactWidth)

                            coursesSection(isCompactWidth: isCompactWidth)

                            WeekScheduleView(allLectures: lectures)
                                .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .navigationDestination(item: $selectedCourse) { course in
            CourseDetailView(course: course)
        }
        .sheet(isPresented: $showingAddCourseSheet) {
            AddCourseSheet { name, description, color, units, meetings in
                let newCourse = Course(name: name, detail: description, color: color, units: units)
                modelContext.insert(newCourse)
                for meeting in meetings {
                    meeting.course = newCourse
                    modelContext.insert(meeting)
                }
                // Generate lectures from meetings
                generateLectures(for: newCourse, meetings: meetings)
            }
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarView()
        }
        .sheet(isPresented: $showingQuickNoteSheet) {
            QuickNoteSheet(courses: courses) { content, course in
                let targetLecture = findNearestLecture(for: course)
                let newNote = LectureNote(content: content, lecture: targetLecture)
                modelContext.insert(newNote)
            }
        }
        .sheet(isPresented: $showingQuickAssignmentSheet) {
            QuickAssignmentSheet(courses: courses) { title, description, dueDate, priority, course in
                let newAssignment = Assignment(title: title, assignmentDescription: description, dueDate: dueDate, priority: priority, course: course)
                modelContext.insert(newAssignment)
            }
        }
        .fileImporter(isPresented: $showingQuickFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                showingQuickFileCourseSelector = true
                pendingFileURLs = urls
            case .failure(let error):
                print("File import failed: \(error)")
            }
        }
        .sheet(isPresented: $showingQuickFileCourseSelector) {
            QuickFileCourseSelector(courses: courses) { course in
                let targetLecture = findNearestLecture(for: course)
                for url in pendingFileURLs {
                    do {
                        let data = try Data(contentsOf: url)
                        let filename = url.lastPathComponent
                        let newFile = LectureFile(filename: filename, fileData: data, lecture: targetLecture)
                        modelContext.insert(newFile)
                    } catch {
                        print("Error loading file: \(error)")
                    }
                }
                pendingFileURLs = []
            }
        }
        .alert("Delete Course?", isPresented: $showDeleteAlert, presenting: courseToDelete) { course in
            Button("Delete", role: .destructive) {
                modelContext.delete(course)
                courseToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                courseToDelete = nil
            }
        } message: { _ in
            Text("This action cannot be undone.")
        }
    }

    @ViewBuilder
    private func header(isCompactWidth: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Text("Stay on top of your courses and upcoming meetings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 20) {
                Text("Quick Capture")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        ForEach(quickActionItems) { item in
                            QuickAddButton(icon: item.icon, title: item.title, action: item.action)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompactWidth ? 140 : 180), spacing: 12)], spacing: 12) {
                        ForEach(quickActionItems) { item in
                            QuickAddButton(icon: item.icon, title: item.title, action: item.action)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.platformElevatedBackground.opacity(0.95))
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, isCompactWidth ? 8 : 16)
    }

    @ViewBuilder
    private func coursesSection(isCompactWidth: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Courses")
                .font(.headline)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompactWidth ? 180 : 220), spacing: 20)], spacing: 20) {
                    courseChipContent
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        courseChipContent
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.platformElevatedBackground.opacity(0.95))
        )
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var courseChipContent: some View {
        ForEach(courses) { course in
            CourseChipView(course: course)
                .onTapGesture { selectedCourse = course }
                .contextMenu {
                    Button("Rename") {
                        selectedCourse = course
                    }
                    Button("Change Color") {
                        selectedCourse = course
                    }
                    Divider()
                    Button(role: .destructive) {
                        courseToDelete = course
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        AddCourseChipView(action: { showingAddCourseSheet = true })
    }

    private var quickActionItems: [QuickActionItem] {
        [
            QuickActionItem(id: "note", icon: "note.text", title: "Note") {
                showingQuickNoteSheet = true
            },
            QuickActionItem(id: "file", icon: "paperclip", title: "File") {
                showingQuickFileImporter = true
            },
            QuickActionItem(id: "assignment", icon: "checkmark.circle", title: "Assignment") {
                showingQuickAssignmentSheet = true
            },
            QuickActionItem(id: "calendar", icon: "calendar", title: "Calendar") {
                showingCalendar = true
            }
        ]
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

    private func generateLectures(for course: Course, meetings: [CourseMeeting]) {
        let term = course.term ?? Term(name: "Default Term", startDate: course.termStartDate ?? Date(), endDate: course.termEndDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date())!)
        let calendar = Calendar.current
        var date = term.startDate
        while date <= term.endDate {
            let weekday = calendar.component(.weekday, from: date)
            for meeting in meetings where meeting.dayOfWeek == weekday {
                let startDateTime = calendar.date(bySettingHour: meeting.startHour, minute: meeting.startMinute, second: 0, of: date)!
                let lecture = Lecture(title: "Lecture", date: startDateTime, course: course)
                modelContext.insert(lecture)
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
    }
}

private struct QuickActionItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let action: () -> Void
}

struct HomeBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .fill(colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.03))
                .blendMode(.overlay)
        )
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.07, green: 0.07, blue: 0.08),
                Color(red: 0.04, green: 0.04, blue: 0.05)
            ]
        } else {
            return [
                Color(white: 0.97),
                Color(white: 0.92)
            ]
        }
    }
}

struct QuickAddButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    )

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(minWidth: 112)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.platformCardBackground.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
}

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date { Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? self }
}

struct CourseChipView: View {
    let course: Course

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(course.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Spacer()

                Circle()
                    .fill(course.colorValue)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    )
            }

            if let detail = course.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let nextLecture = upcomingLecture {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next session")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Label {
                        Text(nextLecture.date.formatted(date: .omitted, time: .shortened))
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.platformCardBackground.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private var upcomingLecture: Lecture? {
        let now = Date()
        return course.lectures
            .filter { $0.date >= now }
            .sorted { $0.date < $1.date }
            .first
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
}

struct AddCourseChipView: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 28, height: 28)

                        Image(systemName: "plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text("Add Course")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Text("Create a new class and start tracking meetings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(borderColor, style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
}

struct WeekScheduleView: View {
    let allLectures: [Lecture]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("This Week")
                .font(.headline)
                .foregroundStyle(.secondary)

            if upcomingDays.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No sessions scheduled in the next 7 days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 36)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.platformCardBackground.opacity(0.9))
                )
            } else {
                VStack(spacing: 16) {
                    ForEach(upcomingDays, id: \.date) { day in
                        DayScheduleCard(date: day.date, lectures: day.lectures)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.platformElevatedBackground.opacity(0.95))
        )
    }

    private var upcomingDays: [(date: Date, lectures: [Lecture])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAhead = calendar.date(byAdding: .day, value: 7, to: today) else { return [] }

        let upcomingLectures = allLectures
            .filter { $0.date >= today && $0.date < weekAhead }
            .sorted { $0.date < $1.date }

        let grouped = Dictionary(grouping: upcomingLectures) { lecture in
            calendar.startOfDay(for: lecture.date)
        }

        return grouped.keys
            .sorted()
            .map { date in
                (date, grouped[date] ?? [])
            }
    }

    private struct DayScheduleCard: View {
        let date: Date
        let lectures: [Lecture]

        @Environment(\.colorScheme) private var colorScheme

        private var weekdayFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(weekdayFormatter.string(from: date))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(lectures) { lecture in
                    HStack(alignment: .center, spacing: 14) {
                        Circle()
                            .fill(lecture.course?.colorValue ?? .gray)
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(lecture.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)

                            if let courseName = lecture.course?.name {
                                Text(courseName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text(lecture.date.formatted(.dateTime.hour().minute()))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.platformCardBackground.opacity(0.9))
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }

        private var borderColor: Color {
            colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Course.self, Lecture.self, LectureNote.self, LectureFile.self, CourseMeeting.self, Syllabus.self, Assignment.self], inMemory: true)
}
