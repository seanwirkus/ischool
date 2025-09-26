import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var courseToDelete: Course? = nil
    @State private var showDeleteAlert: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
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
                    .foregroundStyle(Color.white.opacity(0.82))

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        ForEach(quickActionItems) { item in
                            QuickAddButton(icon: item.icon, title: item.title, gradient: item.gradient, action: item.action)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompactWidth ? 140 : 180), spacing: 12)], spacing: 12) {
                        ForEach(quickActionItems) { item in
                            QuickAddButton(icon: item.icon, title: item.title, gradient: item.gradient, action: item.action)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(quickCaptureBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(quickCaptureBorder, lineWidth: 1.1)
            )
            .shadow(color: quickCaptureShadow, radius: 16, x: 0, y: 12)
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
            QuickActionItem(
                id: "note",
                icon: "note.text",
                title: "Note",
                gradient: [Color(hex: "#8B5CF6") ?? .purple, Color(hex: "#6366F1") ?? .indigo]
            ) {
                showingQuickNoteSheet = true
            },
            QuickActionItem(
                id: "file",
                icon: "paperclip",
                title: "File",
                gradient: [Color(hex: "#0EA5E9") ?? .teal, Color(hex: "#14B8A6") ?? .teal]
            ) {
                showingQuickFileImporter = true
            },
            QuickActionItem(
                id: "assignment",
                icon: "checkmark.circle",
                title: "Assignment",
                gradient: [Color(hex: "#F97316") ?? .orange, Color(hex: "#EC4899") ?? .pink]
            ) {
                showingQuickAssignmentSheet = true
            },
            QuickActionItem(
                id: "calendar",
                icon: "calendar",
                title: "Calendar",
                gradient: [Color(hex: "#22D3EE") ?? .cyan, Color(hex: "#818CF8") ?? .indigo]
            ) {
                showingCalendar = true
            }
        ]
    }

    private var quickCaptureBackground: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(hex: "#312E81") ?? Color(red: 0.19, green: 0.18, blue: 0.45),
                    Color(hex: "#1E40AF") ?? Color(red: 0.12, green: 0.25, blue: 0.69)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(hex: "#EEF2FF") ?? Color(red: 0.94, green: 0.95, blue: 1.0),
                    Color(hex: "#DBEAFE") ?? Color(red: 0.86, green: 0.92, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var quickCaptureBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.35 : 0.7),
                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var quickCaptureShadow: Color {
        (colorScheme == .dark ? Color(hex: "#312E81") : Color(hex: "#93C5FD"))?.opacity(colorScheme == .dark ? 0.5 : 0.35) ??
            Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.35)
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
    let gradient: [Color]
    let action: () -> Void
}

struct HomeBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(radialAccentOne)
                    .frame(width: colorScheme == .dark ? 420 : 360)
                    .blur(radius: 160)
                    .offset(x: 80, y: -40)
                    .blendMode(.screen)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(radialAccentTwo)
                    .frame(width: colorScheme == .dark ? 480 : 420)
                    .blur(radius: 140)
                    .offset(x: -120, y: 120)
                    .blendMode(colorScheme == .dark ? .plusLighter : .plusDarker)
            }
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.overlay)
            )
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(hex: "#0F172A") ?? Color(red: 0.09, green: 0.1, blue: 0.18),
                Color(hex: "#1E1B4B") ?? Color(red: 0.13, green: 0.11, blue: 0.29),
                Color(hex: "#0B1120") ?? Color(red: 0.07, green: 0.09, blue: 0.15)
            ]
        } else {
            return [
                Color(hex: "#F8FAFC") ?? Color(white: 0.97),
                Color(hex: "#E0F2FE") ?? Color(red: 0.85, green: 0.94, blue: 0.99),
                Color(hex: "#F5E0FF") ?? Color(red: 0.96, green: 0.88, blue: 1.0)
            ]
        }
    }

    private var radialAccentOne: RadialGradient {
        let centerColor = colorScheme == .dark ? Color(hex: "#7C3AED") ?? .purple : Color(hex: "#818CF8") ?? .indigo
        return RadialGradient(
            gradient: Gradient(colors: [centerColor, centerColor.opacity(0.05)]),
            center: .center,
            startRadius: 10,
            endRadius: 220
        )
    }

    private var radialAccentTwo: RadialGradient {
        let base = colorScheme == .dark ? Color(hex: "#22D3EE") ?? .cyan : Color(hex: "#34D399") ?? .green
        return RadialGradient(
            gradient: Gradient(colors: [base.opacity(0.85), base.opacity(0.08)]),
            center: .center,
            startRadius: 10,
            endRadius: 240
        )
    }
}

struct QuickAddButton: View {
    let icon: String
    let title: String
    let gradient: [Color]
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(colors: circleGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle()
                            .strokeBorder(highlightColor.opacity(colorScheme == .dark ? 0.45 : 0.6), lineWidth: 1.2)
                    )
                    .overlay(
                        Image(systemName: icon)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    )

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .frame(minWidth: 124)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: backgroundGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(borderGradient, lineWidth: 1.2)
            )
            .shadow(color: shadowColor, radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var primaryColor: Color { gradient.first ?? .accentColor }
    private var secondaryColor: Color { gradient.last ?? gradient.first ?? .accentColor }

    private var backgroundGradient: [Color] {
        if colorScheme == .dark {
            return [
                primaryColor.darken(by: 0.1),
                secondaryColor
            ]
        } else {
            return [
                primaryColor.lighten(by: 0.08),
                secondaryColor
            ]
        }
    }

    private var circleGradient: [Color] {
        [primaryColor.lighten(by: 0.12), secondaryColor]
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                highlightColor.opacity(colorScheme == .dark ? 0.4 : 0.55),
                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var highlightColor: Color {
        primaryColor.lighten(by: 0.25)
    }

    private var shadowColor: Color {
        secondaryColor.opacity(colorScheme == .dark ? 0.6 : 0.35)
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
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Spacer()

                Circle()
                    .fill(primaryAccent)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.55), lineWidth: 2)
                    )
            }

            if let detail = course.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(3)
            }

            if let nextLecture = upcomingLecture {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next session")
                        .font(.caption2)
                        .foregroundStyle(secondaryTextColor.opacity(0.9))
                        .textCase(.uppercase)
                    Label {
                        Text(nextLecture.date.formatted(date: .omitted, time: .shortened))
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(primaryTextColor)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: chipGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: 1.1)
        )
        .shadow(color: primaryAccent.opacity(colorScheme == .dark ? 0.5 : 0.25), radius: 18, x: 0, y: 10)
    }

    private var upcomingLecture: Lecture? {
        let now = Date()
        return course.lectures
            .filter { $0.date >= now }
            .sorted { $0.date < $1.date }
            .first
    }

    private var primaryAccent: Color {
        course.colorValue
    }

    private var chipGradient: [Color] {
        if colorScheme == .dark {
            return [primaryAccent.darken(by: 0.25), primaryAccent]
        } else {
            return [primaryAccent.lighten(by: 0.15), primaryAccent]
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.18 : 0.45),
                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.95) : Color.white.opacity(0.94)
    }

    private var secondaryTextColor: Color {
        Color.white.opacity(0.75)
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
                            .strokeBorder(Color.white.opacity(0.45), lineWidth: 1.4)
                            .frame(width: 28, height: 28)

                        Image(systemName: "plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.white)
                    }

                    Text("Add Course")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.96))
                }

                Text("Create a new class and start tracking meetings.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.78))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: backgroundGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(borderGradient, style: StrokeStyle(lineWidth: 1.2, dash: [8, 6]))
            )
            .shadow(color: shadowColor, radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var accent: Color {
        (Color(hex: "#22D3EE") ?? .teal).mixed(with: .white, amount: colorScheme == .dark ? 0.1 : 0.4)
    }

    private var backgroundGradient: [Color] {
        if colorScheme == .dark {
            return [accent.darken(by: 0.3), accent.darken(by: 0.05)]
        } else {
            return [accent.lighten(by: 0.35), accent]
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(colorScheme == .dark ? 0.5 : 0.85), Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shadowColor: Color {
        accent.opacity(colorScheme == .dark ? 0.6 : 0.3)
    }
}

struct WeekScheduleView: View {
    let allLectures: [Lecture]
    @Environment(\.colorScheme) private var colorScheme

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
                .fill(containerBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(containerStroke, lineWidth: 1)
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

    private var containerBackground: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.8), Color.white.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var containerStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
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
                    .foregroundStyle(headerTextColor)

                ForEach(lectures) { lecture in
                    HStack(alignment: .center, spacing: 14) {
                        Circle()
                            .fill((lecture.course?.colorValue ?? accentColor).lighten(by: 0.12))
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(lecture.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(rowPrimaryTextColor)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)

                            if let courseName = lecture.course?.name {
                                Text(courseName)
                                    .font(.caption)
                                    .foregroundStyle(rowSecondaryTextColor)
                            }
                        }

                        Spacer()

                        Text(lecture.date.formatted(.dateTime.hour().minute()))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(rowSecondaryTextColor)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(rowBackground)
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: cardGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(borderOverlayGradient, lineWidth: 1.2)
            )
            .shadow(color: accentColor.opacity(colorScheme == .dark ? 0.45 : 0.25), radius: 14, x: 0, y: 10)
        }

        private var accentColor: Color {
            lectures.first?.course?.colorValue ?? (Color(hex: "#38BDF8") ?? .blue)
        }

        private var cardGradient: [Color] {
            if colorScheme == .dark {
                return [accentColor.darken(by: 0.35), accentColor.darken(by: 0.05)]
            } else {
                return [accentColor.lighten(by: 0.35), accentColor]
            }
        }

        private var borderOverlayGradient: LinearGradient {
            LinearGradient(
                colors: [Color.white.opacity(colorScheme == .dark ? 0.25 : 0.55), Color.white.opacity(colorScheme == .dark ? 0.12 : 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        private var headerTextColor: Color {
            Color.white.opacity(0.82)
        }

        private var rowPrimaryTextColor: Color {
            Color.white.opacity(0.94)
        }

        private var rowSecondaryTextColor: Color {
            Color.white.opacity(0.78)
        }

        private var rowBackground: some ShapeStyle {
            LinearGradient(
                colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Course.self, Lecture.self, LectureNote.self, LectureFile.self, CourseMeeting.self, Syllabus.self, Assignment.self], inMemory: true)
}
