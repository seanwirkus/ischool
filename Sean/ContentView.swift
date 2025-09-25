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
                    Color.clear
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        header(isCompactWidth: isCompactWidth)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                coursesSection(isCompactWidth: isCompactWidth)

                                WeekScheduleView(allLectures: lectures)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("My Courses")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    ForEach(quickActionItems) { item in
                        QuickAddButton(icon: item.icon, title: item.title, action: item.action)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(quickActionItems) { item in
                        QuickAddButton(icon: item.icon, title: item.title, action: item.action)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, isCompactWidth ? 20 : 32)
    }

    @ViewBuilder
    private func coursesSection(isCompactWidth: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompactWidth ? 140 : 180), spacing: 16)], alignment: .leading, spacing: 16) {
                courseChipContent
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    courseChipContent
                }
                .padding(.horizontal, 20)
            }
        }
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

struct QuickAddButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(minWidth: 96)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.platformCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date { Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? self }
}

struct CourseChipView: View {
    let course: Course

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(course.colorValue)
                    .frame(width: 56, height: 56)
                Text(course.name.prefix(1))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            Text(course.name)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: 120)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: 140)
    }
}

struct AddCourseChipView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(.secondary.opacity(0.3), lineWidth: 2)
                        )
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.8)
                }
                Text("Add Course")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: 120)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: 140)
        }
        .buttonStyle(.plain)
    }
}

struct WeekScheduleView: View {
    let allLectures: [Lecture]

    var body: some View {
        VStack(spacing: 0) {
            Text("Course Schedule")
                .font(.title.bold())
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal], 24)

            ScrollView {
                VStack(spacing: 16) {
                    if allLectures.isEmpty {
                        Text("No lectures scheduled.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.platformCardBackground))
                    } else {
                        ViewThatFits(in: .horizontal) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                                daySections
                            }

                            VStack(spacing: 16) {
                                daySections
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var groupedLectures: [Date: [Lecture]] {
        let calendar = Calendar.current
        return Dictionary(grouping: allLectures) { lecture in
            calendar.startOfDay(for: lecture.date)
        }
    }

    @ViewBuilder
    private var daySections: some View {
        ForEach(groupedLectures.keys.sorted(), id: \.self) { date in
            VStack(alignment: .leading, spacing: 8) {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.headline)
                    .foregroundColor(.accentColor)
                ForEach(groupedLectures[date] ?? []) { lecture in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(lecture.course?.colorValue ?? .blue)
                            .frame(width: 10, height: 10)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lecture.title)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                            if let courseName = lecture.course?.name {
                                Text(courseName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(lecture.date.formatted(.dateTime.hour().minute()))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.platformCardBackground))
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Course.self, Lecture.self, LectureNote.self, LectureFile.self, CourseMeeting.self, Syllabus.self, Assignment.self], inMemory: true)
}
