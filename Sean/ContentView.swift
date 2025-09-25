import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(iOS)
import VisionKit
#endif

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
#if os(iOS)
    @State private var showingDocumentScanner = false
    @State private var pendingScannedDocuments: [ScannedDocument] = []
    @State private var scannerErrorMessage: String?
#endif

    var body: some View {
        NavigationStack {
            ZStack {
                // Liquid glass background
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header with quick actions
                    HStack {
                        Text("My Courses")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        HStack(spacing: 16) {
                            QuickAddButton(icon: "note.text", title: "Note") {
                                showingQuickNoteSheet = true
                            }
                            QuickAddButton(icon: "paperclip", title: "File") {
                                showingQuickFileImporter = true
                            }
                            QuickAddButton(icon: "checkmark.circle", title: "Assignment") {
                                showingQuickAssignmentSheet = true
                            }
#if os(iOS)
                            if supportsDocumentScanner {
                                QuickAddButton(icon: "doc.text.viewfinder", title: "Scan") {
                                    showingDocumentScanner = true
                                }
                            }
#endif
                            Button(action: { showingCalendar = true }) {
                                Image(systemName: "calendar")
                                    .font(.title2)
                                    .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Content: horizontal course chips + week schedule
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Horizontal course chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(courses) { course in
                                        CourseChipView(course: course)
                                            .onTapGesture { selectedCourse = course }
                                            .contextMenu {
                                                Button("Rename") {
                                                    selectedCourse = course
                                                    // Show rename sheet/modal (implement as needed)
                                                }
                                                Button("Change Color") {
                                                    selectedCourse = course
                                                    // Show color picker sheet/modal (implement as needed)
                                                }
                                                Divider()
                                                Button(role: .destructive) {
                                                    courseToDelete = course
                                                    showDeleteAlert = true
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
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
                                    AddCourseChipView(action: { showingAddCourseSheet = true })
                                }
                                .padding(.horizontal, 20)
                            }

                            // Week schedule view (default)
                            WeekScheduleView(allLectures: lectures)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                        }
                    }
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
                    // Show course selector for file attachment
                    showingQuickFileCourseSelector = true
                    pendingFileURLs = urls
                case .failure(let error):
                    print("File import failed: \(error)")
                }
            }
            .sheet(isPresented: $showingQuickFileCourseSelector) {
                QuickFileCourseSelector(courses: courses) { course in
                    let targetLecture = findNearestLecture(for: course)
#if os(iOS)
                    if !pendingScannedDocuments.isEmpty {
                        for document in pendingScannedDocuments {
                            let newFile = LectureFile(filename: document.filename, fileData: document.data, lecture: targetLecture)
                            modelContext.insert(newFile)
                        }
                        pendingScannedDocuments = []
                    } else {
                        processImportedFiles(for: targetLecture)
                    }
#else
                    processImportedFiles(for: targetLecture)
#endif
                    pendingFileURLs = []
                }
            }
            .onChange(of: showingQuickFileCourseSelector) { isPresented in
                if !isPresented {
                    pendingFileURLs = []
#if os(iOS)
                    pendingScannedDocuments = []
#endif
                }
            }
#if os(iOS)
            .sheet(isPresented: $showingDocumentScanner) {
                DocumentScannerSheet { documents in
                    guard !documents.isEmpty else { return }
                    pendingScannedDocuments = documents
                    showingQuickFileCourseSelector = true
                } onError: { error in
                    scannerErrorMessage = error.localizedDescription
                }
            }
            .alert("Scanner Error", isPresented: Binding(
                get: { scannerErrorMessage != nil },
                set: { if !$0 { scannerErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    scannerErrorMessage = nil
                }
            } message: {
                Text(scannerErrorMessage ?? "An unknown error occurred.")
            }
#endif
        }
    }

    private func processImportedFiles(for lecture: Lecture?) {
        for url in pendingFileURLs {
            do {
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent
                let newFile = LectureFile(filename: filename, fileData: data, lecture: lecture)
                modelContext.insert(newFile)
            } catch {
                print("Error loading file: \(error)")
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

#if os(iOS)
private extension ContentView {
    var supportsDocumentScanner: Bool {
        if #available(iOS 17.0, *) {
            return VNDocumentCameraViewController.isSupported
        }
        return false
    }
}
#endif

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
                }

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(minWidth: 96)
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
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(course.colorValue)
                    .frame(width: 50, height: 50)
                Text(course.name.prefix(1))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            Text(course.name)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 60)
        }
        .padding(.vertical, 8)
    }
}

struct AddCourseChipView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(.secondary.opacity(0.3), lineWidth: 2)
                        )
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }
                Text("Add Course")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 60)
            }
            .padding(.vertical, 8)
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
                        ForEach(groupedLectures.keys.sorted(), id: \ .self) { date in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(date.formatted(.dateTime.weekday(.wide)))
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                ForEach(groupedLectures[date] ?? []) { lecture in
                                    HStack {
                                        Circle()
                                            .fill(lecture.course?.colorValue ?? .blue)
                                            .frame(width: 10, height: 10)
                                        Text(lecture.title)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(lecture.date.formatted(.dateTime.hour().minute()))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.platformCardBackground))
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
}

#Preview {
    ContentView()
        .modelContainer(for: [Course.self, Lecture.self, LectureNote.self, LectureFile.self, CourseMeeting.self, Syllabus.self, Assignment.self], inMemory: true)
}
