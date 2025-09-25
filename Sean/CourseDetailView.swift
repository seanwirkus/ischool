//
//  CourseDetailView.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI
import SwiftData
import Foundation
import UniformTypeIdentifiers

struct CourseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let course: Course

    @State private var selectedLecture: Lecture? = nil
    @State private var showingAddSyllabusSheet = false
    @State private var showingFileImporter = false
    @State private var showingAddAssignmentSheet = false
    @State private var selectedTab = 0
    @State private var showingSyllabusView = false
    @State private var showingEditCourseSheet = false
    @State private var activeLectureForMaterial: Lecture? = nil
    @State private var noteTargetLecture: Lecture? = nil
    @State private var fileTargetLecture: Lecture? = nil
    @State private var showingMaterialOptions = false
    @State private var showingLectureFileImporter = false
    @State private var taskEditorContext: TaskEditorContext? = nil

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header with syllabus access button on top right
                HStack {
                    VStack(alignment: .leading) {
                        Text(course.name)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)
                        if let det = course.detail {
                            Text(det)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 16) {
                            if let units = course.units {
                                Text("\(units) units")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(course.lectures.count) lectures")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(course.assignments.count) assignments")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        showingEditCourseSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .padding(8)
                            .background(
                                Circle().fill(Color.accentColor.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit Course")
                    .padding(.trailing, 4)

                    Circle()
                        .fill(course.colorValue)
                        .frame(width: 20, height: 20)

                    // Syllabus access/upload area
                    if course.syllabi.isEmpty {
                        // Upload area: a labeled rounded rectangle that triggers a file importer
                        Button {
                            showingFileImporter = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.on.doc")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upload Syllabus")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text("Upload a PDF, text, or image file")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(minWidth: 140)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.25)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.03)))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                        .accessibilityLabel("Upload Syllabus")
                        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [UTType.pdf, UTType.plainText, UTType.rtf, UTType.rtfd, UTType.image], allowsMultipleSelection: false) { result in
                            switch result {
                            case .success(let urls):
                                guard let url = urls.first else { return }
                                self.handleImportedFile(url: url)
                            case .failure(let err):
                                print("File import failed: \(err)")
                            }
                        }
                    } else {
                        Button {
                            showingSyllabusView = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text")
                                    .font(.title3)
                                    .foregroundColor(course.colorValue)
                                Text("View Syllabus")
                                    .font(.caption)
                                    .foregroundColor(course.colorValue)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(course.colorValue.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                        .accessibilityLabel("View Syllabus")
                        .sheet(isPresented: $showingSyllabusView) {
                            SyllabusListView(course: course)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Calendar view showing this course's lectures (new)
                CourseMiniCalendarView(course: course)
                    .padding(.horizontal, 20)

                // Tab selector (without syllabus tab)
                HStack(spacing: 0) {
                    TabButton(title: "Lectures", icon: "book.closed", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "Assignments", icon: "checkmark.circle", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                }
                .padding(.horizontal, 20)

                // Content based on selected tab (syllabus tab removed)
                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case 0:
                            // Lectures grid view with add material button
                            lecturesGridSection
                        case 1:
                            assignmentsSection
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationDestination(item: $selectedLecture) { lecture in
            LectureDetailView(lecture: lecture)
        }
        .sheet(isPresented: $showingAddSyllabusSheet) {
            AddSyllabusSheet(course: course) { title, content in
                let newSyllabus = Syllabus(title: title, content: content, course: course)
                modelContext.insert(newSyllabus)
            }
        }
        .sheet(isPresented: $showingAddAssignmentSheet) {
            AddAssignmentSheet(course: course) { title, description, dueDate, priority in
                let newAssignment = Assignment(title: title, assignmentDescription: description, dueDate: dueDate, priority: priority, course: course)
                modelContext.insert(newAssignment)
            }
        }
        .sheet(item: $taskEditorContext) { context in
            let assignments = (context.lecture.course?.assignments ?? []).sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?):
                    return l < r
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.createdDate < rhs.createdDate
                }
            }

            LectureTaskEditorSheet(
                lecture: context.lecture,
                task: context.task,
                assignments: assignments
            ) { title, details, dueDate, assignment in
                if let existingTask = context.task {
                    existingTask.title = title
                    existingTask.details = details
                    existingTask.dueDate = dueDate
                    existingTask.assignment = assignment
                } else {
                    let newTask = LectureTask(
                        title: title,
                        details: details,
                        dueDate: dueDate,
                        lecture: context.lecture,
                        assignment: assignment
                    )
                    modelContext.insert(newTask)
                }
            } onDelete: { task in
                modelContext.delete(task)
            }
        }
        .sheet(isPresented: $showingEditCourseSheet) {
            CourseEditSheet(course: course, modelContext: modelContext) {
                showingEditCourseSheet = false
            }
        }
        .sheet(item: $noteTargetLecture) { lecture in
            LectureNoteComposerSheet(lecture: lecture) { noteText in
                let newNote = LectureNote(content: noteText, lecture: lecture)
                modelContext.insert(newNote)
                activeLectureForMaterial = nil
                noteTargetLecture = nil
            }
        }
        .fileImporter(isPresented: $showingLectureFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard let lecture = fileTargetLecture else { return }
            switch result {
            case .success(let urls):
                for url in urls {
                    do {
                        let data = try Data(contentsOf: url)
                        let newFile = LectureFile(filename: url.lastPathComponent, fileData: data, lecture: lecture)
                        modelContext.insert(newFile)
                    } catch {
                        print("Failed to attach file: \(error)")
                    }
                }
            case .failure(let error):
                print("File import failed: \(error)")
            }
            fileTargetLecture = nil
            activeLectureForMaterial = nil
        }
        .confirmationDialog(
            "Add material",
            isPresented: $showingMaterialOptions,
            presenting: activeLectureForMaterial
        ) { lecture in
            Button("Add Note") {
                noteTargetLecture = lecture
                fileTargetLecture = nil
            }
            Button("Attach File") {
                fileTargetLecture = lecture
                showingLectureFileImporter = true
                noteTargetLecture = nil
            }
            Button("Cancel", role: .cancel) {
                activeLectureForMaterial = nil
            }
        } message: { lecture in
            Text("Link new material to \(lecture.title)")
        }
    }

    // MARK: - Lectures grid section with 2 columns and add material button on each card
    private var lecturesGridSection: some View {
        // Sort lectures by date descending
        let sortedLectures = course.lectures.sorted(by: { $0.date > $1.date })
        let columns = [GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, spacing: 16) {
            if sortedLectures.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "No Schedule Yet",
                    message: "Edit your course to set up the schedule.",
                    action: { showingEditCourseSheet = true },
                    actionTitle: "Edit Course"
                )
            } else {
                ForEach(sortedLectures) { lecture in
                    LectureGridCardView(
                        lecture: lecture,
                        onAddMaterial: {
                            activeLectureForMaterial = lecture
                            showingMaterialOptions = true
                        },
                        onAddTask: {
                            taskEditorContext = TaskEditorContext(lecture: lecture, task: nil)
                        },
                        onEditTask: { task in
                            taskEditorContext = TaskEditorContext(lecture: lecture, task: task)
                        }
                    )
                    .onTapGesture {
                        selectedLecture = lecture
                    }
                }
            }
        }
    }

    // MARK: - Assignments section (unchanged)
    private var assignmentsSection: some View {
        VStack(spacing: 16) {
            if course.assignments.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No Assignments Yet",
                    message: "Track homework, projects, and exams",
                    action: { showingAddAssignmentSheet = true },
                    actionTitle: "Add Assignment"
                )
            } else {
                ForEach(course.assignments.sorted(by: {
                    if let date1 = $0.dueDate, let date2 = $1.dueDate {
                        return date1 < date2
                    }
                    return $0.createdDate > $1.createdDate
                })) { assignment in
                    AssignmentCardView(assignment: assignment)
                }

                // Add assignment button
                AddButton(action: { showingAddAssignmentSheet = true }, title: "Add Assignment")
            }
        }
    }
}

// MARK: - LectureGridCardView with add material button
struct LectureGridCardView: View {
    let lecture: Lecture
    let onAddMaterial: () -> Void
    let onAddTask: () -> Void
    let onEditTask: (LectureTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill((lecture.course?.colorValue ?? .accentColor))
                    .frame(width: 14, height: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(lecture.course?.name ?? "Course")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(meetingLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    onAddMaterial()
                } label: {
                    Label("Add material", systemImage: "paperclip")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add material to \(lecture.course?.name ?? "course")")

                Button {
                    onAddTask()
                } label: {
                    Label("Add meeting task", systemImage: "checklist")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add meeting task")
            }

            if hasDistinctTitle {
                Text(lecture.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(lecture.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(lecture.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let notes = lecture.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            tasksSummary
        }
        .padding(16)
        .frame(minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.platformCardBackground)
        )
    }

    private var hasDistinctTitle: Bool {
        return lecture.title.trimmingCharacters(in: .whitespacesAndNewlines) != meetingLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var meetingLabel: String {
        let trimmed = (lecture.meetingType ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? lecture.title : trimmed
    }

    private var tasksSummary: some View {
        let tasks = sortedTasks
        return Group {
            if tasks.isEmpty {
                Button(action: onAddTask) {
                    HStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .foregroundStyle(.accentColor)
                        Text("Add meeting tasks")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("Meeting tasks", systemImage: "checklist")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(completedTaskCount)/\(tasks.count) done")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(tasks.prefix(2))) { task in
                        LectureTaskSummaryRow(task: task) {
                            onEditTask(task)
                        }
                    }

                    if tasks.count > 2 {
                        Text("+\(tasks.count - 2) more tasks")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var sortedTasks: [LectureTask] {
        lecture.lectureTasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted && rhs.isCompleted
            }

            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?):
                return l < r
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.createdAt < rhs.createdAt
            }
        }
    }

    private var completedTaskCount: Int {
        lecture.lectureTasks.filter { $0.isCompleted }.count
    }
}

struct LectureTaskSummaryRow: View {
    let task: LectureTask
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .strikethrough(task.isCompleted, color: .primary.opacity(0.6))
                    HStack(spacing: 6) {
                        if let dueDate = task.dueDate {
                            Text(dueDate, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let assignment = task.assignment {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                Text(assignment.title)
                                    .lineLimit(1)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.08))
                            )
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

struct TaskEditorContext: Identifiable {
    let lecture: Lecture
    let task: LectureTask?

    var id: UUID {
        task?.id ?? lecture.id
    }
}

struct LectureTaskEditorSheet: View {
    let lecture: Lecture
    let task: LectureTask?
    let assignments: [Assignment]
    let onSave: (String, String?, Date?, Assignment?) -> Void
    let onDelete: ((LectureTask) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var details: String
    @State private var includeDueDate: Bool
    @State private var dueDate: Date
    @State private var selectedAssignment: Assignment?

    init(
        lecture: Lecture,
        task: LectureTask?,
        assignments: [Assignment],
        onSave: @escaping (String, String?, Date?, Assignment?) -> Void,
        onDelete: ((LectureTask) -> Void)? = nil
    ) {
        self.lecture = lecture
        self.task = task
        self.assignments = assignments
        self.onSave = onSave
        self.onDelete = onDelete

        _title = State(initialValue: task?.title ?? "")
        _details = State(initialValue: task?.details ?? "")
        _includeDueDate = State(initialValue: task?.dueDate != nil)
        _dueDate = State(initialValue: task?.dueDate ?? lecture.date)
        _selectedAssignment = State(initialValue: task?.assignment)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task basics") {
                    TextField("What needs to happen?", text: $title)

                    Toggle("Add due date", isOn: $includeDueDate.animation())

                    if includeDueDate {
                        DatePicker(
                            "Due",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section("Details") {
                    TextEditor(text: $details)
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.secondary.opacity(0.2))
                        )
                }

                Section("Link to assignment") {
                    if assignments.isEmpty {
                        Text("Create an assignment first to link it here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Menu {
                            Button("No linked assignment") {
                                selectedAssignment = nil
                            }
                            ForEach(assignments, id: \.id) { assignment in
                                Button {
                                    selectedAssignment = assignment
                                } label: {
                                    if selectedAssignment?.id == assignment.id {
                                        Label(assignment.title, systemImage: "checkmark")
                                    } else {
                                        Text(assignment.title)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedAssignment?.title ?? "Select assignment")
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? "New Meeting Task" : "Edit Meeting Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedTitle.isEmpty else { return }

                        let normalizedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
                        let resolvedDetails = normalizedDetails.isEmpty ? nil : normalizedDetails
                        let resolvedDueDate = includeDueDate ? dueDate : nil

                        onSave(trimmedTitle, resolvedDetails, resolvedDueDate, selectedAssignment)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let task, let onDelete {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            onDelete(task)
                            dismiss()
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - LectureNoteComposerSheet
struct LectureNoteComposerSheet: View {
    let lecture: Lecture
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Lecture") {
                    Text(lecture.title)
                        .font(.subheadline.weight(.semibold))
                    Text(lecture.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lecture.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Quick Note") {
                    TextField("Capture key points...", text: $noteText, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("New Lecture Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed)
                        dismiss()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - CourseMiniCalendarView placeholder filtered for this course's lectures
struct CourseMiniCalendarView: View {
    let course: Course

    // For simplicity, a minimal calendar showing lecture dates in a horizontal scroll
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(course.lectures.sorted(by: { $0.date < $1.date })) { lecture in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lecture.date, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(course.colorValue)
                                .frame(width: 8, height: 8)
                            Text(meetingLabel(for: lecture))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(course.colorValue.opacity(0.18))
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - SyllabusListView to view syllabi (used for sheet when tapping View Syllabus button)
struct SyllabusListView: View {
    let course: Course
    @State private var selectedSyllabus: Syllabus? = nil

    var body: some View {
        NavigationStack {
            List {
                if course.syllabi.isEmpty {
                    Text("No syllabus items available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(course.syllabi.sorted(by: { $0.lastModified > $1.lastModified })) { syllabus in
                        Button {
                            selectedSyllabus = syllabus
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(syllabus.title)
                                    .font(.headline)
                                Text(syllabus.content)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Syllabus")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        // Dismiss handled by parent sheet
                    }
                }
            }
            .sheet(item: $selectedSyllabus) { syllabus in
                NavigationStack {
                    ScrollView {
                        Text(syllabus.content)
                            .padding()
                    }
                    .navigationTitle(syllabus.title)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {}
                        }
                    }
                }
            }
        }
    }
}

private func meetingLabel(for lecture: Lecture) -> String {
    let trimmed = (lecture.meetingType ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? lecture.title : trimmed
}

// MARK: - TabButton (unchanged except updated for two tabs)
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.1))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: () -> Void
    let actionTitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2)
                .foregroundStyle(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: action) {
                Text(actionTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct AssignmentCardView: View {
    let assignment: Assignment

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(assignment.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Circle()
                            .fill(assignment.priorityColor)
                            .frame(width: 8, height: 8)
                    }
                    if let description = assignment.assignmentDescription {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let dueDate = assignment.dueDate {
                        Text("Due: \(dueDate, style: .date)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: assignment.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(assignment.isCompleted ? .green : .secondary)
                    .font(.title2)
            }
            .padding(16)
        }
    }
}

struct AddButton: View {
    let action: () -> Void
    let title: String

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(height: 60)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct LectureCardView: View {
    let lecture: Lecture

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lecture.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(lecture.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(lecture.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let notes = lecture.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }
}

struct CourseEditSheet: View {
    @Bindable var course: Course
    var modelContext: ModelContext
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    private struct MeetingConfiguration {
        var start: Date
        var end: Date
        var type: String
    }

    private let weekdayOrder: [(label: String, index: Int)] = [
        ("Mon", 2), ("Tue", 3), ("Wed", 4), ("Thu", 5), ("Fri", 6), ("Sat", 7), ("Sun", 1)
    ]
    private let meetingTypeOptions = ["Class", "Discussion", "Lab", "Workshop", "Study Session", "Office Hours"]
    private let termTypes = ["Semester", "Quarter"]
    private let defaultMeetingDuration: TimeInterval = 75 * 60

    @State private var showDeleteAlert = false
    @State private var didLoadInitialState = false

    @State private var name: String = ""
    @State private var detail: String = ""
    @State private var unitsText: String = ""
    @State private var selectedColor: Color = .accentColor
    @State private var termType: String = "Semester"
    @State private var termStartDate: Date = Date()
    @State private var termEndDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var isAsynchronous: Bool = false
    @State private var selectedDays: Set<Int> = []
    @State private var meetingConfigurations: [Int: MeetingConfiguration] = [:]

    private var orderedSelectedDays: [(label: String, index: Int)] {
        weekdayOrder.filter { selectedDays.contains($0.index) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    identityCard
                    schedulingCard
                    previewCard
                    dangerZoneCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            )
            .navigationTitle("Edit Course")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCourse()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .onAppear(perform: loadInitialState)
            .alert("Delete Course?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(course)
                    onDismiss()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                    Text(courseInitial)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Course name", text: $name)
                        .font(.title3.weight(.semibold))
                        .textInputAutocapitalization(.words)

                    TextField("Short description", text: $detail, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Picker("Term", selection: $termType) {
                            ForEach(termTypes, id: \.self) { term in
                                Text(term)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField("Units", text: $unitsText)
                            .frame(width: 70)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Term timeline")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    DatePicker("Start", selection: $termStartDate, displayedComponents: .date)
                    DatePicker("End", selection: $termEndDate, in: termStartDate..., displayedComponents: .date)
                }

                HStack {
                    Label("Course color", systemImage: "paintpalette")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ColorPicker("Course color", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.platformCardBackground)
        )
    }

    private var schedulingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Meeting pattern", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                if !orderedSelectedDays.isEmpty && !isAsynchronous {
                    Text(summaryHeadline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("This course doesn't meet at a regular time", isOn: $isAsynchronous)
                .toggleStyle(.switch)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !isAsynchronous {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select the days we meet")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(weekdayOrder, id: \.index) { day in
                            let isSelected = selectedDays.contains(day.index)
                            Button {
                                toggleDaySelection(day.index)
                            } label: {
                                Text(day.label)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isSelected ? selectedColor.opacity(0.18) : Color.platformChipBackground)
                                    )
                                    .foregroundStyle(isSelected ? selectedColor : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if orderedSelectedDays.isEmpty {
                        Text("Choose at least one day to configure time and type.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(orderedSelectedDays, id: \.index) { day in
                                meetingEditorCard(for: day.index, label: day.label)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.platformCardBackground)
        )
    }

    private func meetingEditorCard(for dayIndex: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(label) session")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(currentTypeLabel(for: dayIndex))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                DatePicker(
                    "Start",
                    selection: startBinding(for: dayIndex),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                DatePicker(
                    "End",
                    selection: endBinding(for: dayIndex),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Meeting time for \(label)")
            .accessibilityValue(formattedSummary(for: dayIndex))

            Picker("Session type", selection: typeBinding(for: dayIndex)) {
                ForEach(meetingTypeOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.platformChipBackground)
        )
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Meeting preview", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
            }

            if isAsynchronous {
                Text("No scheduled meetings — use this course for independent work or online modules.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if orderedSelectedDays.isEmpty {
                Text("Add at least one meeting day to see the weekly outline.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(orderedSelectedDays, id: \.index) { day in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(day.label)")
                                .font(.subheadline.weight(.semibold))
                            Text(formattedSummary(for: day.index))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.platformCardBackground)
        )
    }

    private var dangerZoneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger zone")
                .font(.headline)
                .foregroundStyle(.red)
            Text("Deleting a course will remove all of its lectures, materials, and assignments.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete course", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.platformCardBackground)
        )
    }

    private var courseInitial: String {
        if let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first {
            return String(first).uppercased()
        }
        return String(course.name.prefix(1)).uppercased()
    }

    private var summaryHeadline: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let summaries = orderedSelectedDays.compactMap { day -> String? in
            guard let config = meetingConfigurations[day.index] else { return nil }
            return "\(day.label) \(formatter.string(from: config.start))"
        }
        return summaries.joined(separator: " · ")
    }

    private var isSaveDisabled: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return true }

        if !isAsynchronous {
            guard !orderedSelectedDays.isEmpty else { return true }
            for day in orderedSelectedDays {
                guard let config = meetingConfigurations[day.index] else { return true }
                if config.end <= config.start { return true }
            }
        }

        return false
    }

    private func loadInitialState() {
        guard !didLoadInitialState else { return }
        didLoadInitialState = true

        name = course.name
        detail = course.detail ?? ""
        unitsText = course.units.map { String($0) } ?? ""
        selectedColor = Color(hex: course.color) ?? .accentColor
        termType = course.termType ?? "Semester"
        termStartDate = course.termStartDate ?? Date()
        termEndDate = course.termEndDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

        let meetings = course.meetings
        isAsynchronous = meetings.isEmpty
        selectedDays = Set(meetings.map { $0.dayOfWeek })

        for meeting in meetings {
            let start = Calendar.current.date(bySettingHour: meeting.startHour, minute: meeting.startMinute, second: 0, of: Date()) ?? Date()
            let end = Calendar.current.date(bySettingHour: meeting.endHour, minute: meeting.endMinute, second: 0, of: Date()) ?? start.addingTimeInterval(defaultMeetingDuration)
        meetingConfigurations[meeting.dayOfWeek] = MeetingConfiguration(
            start: start,
            end: end,
            type: sanitizedType(meeting.meetingType)
        )
        }
    }

    private func toggleDaySelection(_ dayIndex: Int) {
        if selectedDays.contains(dayIndex) {
            selectedDays.remove(dayIndex)
            meetingConfigurations[dayIndex] = nil
        } else {
            selectedDays.insert(dayIndex)
            if meetingConfigurations[dayIndex] == nil {
                let start = defaultStart
                meetingConfigurations[dayIndex] = MeetingConfiguration(
                    start: start,
                    end: defaultEnd(from: start),
                    type: meetingTypeOptions.first ?? "Class"
                )
            }
        }
    }

    private func startBinding(for dayIndex: Int) -> Binding<Date> {
        Binding<Date>(
            get: { meetingConfigurations[dayIndex]?.start ?? defaultStart },
            set: { newValue in
                var config = meetingConfigurations[dayIndex] ?? MeetingConfiguration(
                    start: newValue,
                    end: defaultEnd(from: newValue),
                    type: meetingTypeOptions.first ?? "Class"
                )
                config.start = newValue
                if config.end <= newValue {
                    config.end = defaultEnd(from: newValue)
                }
                meetingConfigurations[dayIndex] = config
            }
        )
    }

    private func endBinding(for dayIndex: Int) -> Binding<Date> {
        Binding<Date>(
            get: {
                if let config = meetingConfigurations[dayIndex] {
                    return config.end
                }
                let start = meetingConfigurations[dayIndex]?.start ?? defaultStart
                return defaultEnd(from: start)
            },
            set: { newValue in
                var config = meetingConfigurations[dayIndex] ?? MeetingConfiguration(
                    start: defaultStart,
                    end: newValue,
                    type: meetingTypeOptions.first ?? "Class"
                )
                config.end = newValue
                if config.end <= config.start {
                    config.start = Calendar.current.date(byAdding: .minute, value: -Int(defaultMeetingDuration / 60), to: newValue)
                        ?? newValue.addingTimeInterval(-defaultMeetingDuration)
                }
                meetingConfigurations[dayIndex] = config
            }
        )
    }

    private func typeBinding(for dayIndex: Int) -> Binding<String> {
        Binding<String>(
            get: { meetingConfigurations[dayIndex]?.type ?? meetingTypeOptions.first ?? "Class" },
            set: { newValue in
                var config = meetingConfigurations[dayIndex] ?? MeetingConfiguration(
                    start: defaultStart,
                    end: defaultEnd(from: defaultStart),
                    type: newValue
                )
                config.type = newValue
                meetingConfigurations[dayIndex] = config
            }
        )
    }

    private func currentTypeLabel(for dayIndex: Int) -> String {
        sanitizedType(meetingConfigurations[dayIndex]?.type ?? meetingTypeOptions.first ?? "Class")
    }

    private func formattedSummary(for dayIndex: Int) -> String {
        guard let config = meetingConfigurations[dayIndex] else { return "Time not set" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let startText = formatter.string(from: config.start)
        let endText = formatter.string(from: config.end)
        return "\(sanitizedType(config.type)) • \(startText) – \(endText)"
    }

    private var defaultStart: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func defaultEnd(from start: Date) -> Date {
        Calendar.current.date(byAdding: .minute, value: Int(defaultMeetingDuration / 60), to: start)
            ?? start.addingTimeInterval(defaultMeetingDuration)
    }

    private func sanitizedType(_ type: String) -> String {
        let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? meetingTypeOptions.first ?? "Class" : trimmed
    }

    private func saveCourse() {
        course.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        course.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : detail.trimmingCharacters(in: .whitespacesAndNewlines)
        course.color = selectedColor.toHexString() ?? course.color
        course.termType = termType
        course.termStartDate = termStartDate
        course.termEndDate = termEndDate
        course.units = Int(unitsText)

        // Remove existing meetings
        for meeting in course.meetings {
            modelContext.delete(meeting)
        }
        course.meetings.removeAll()

        if isAsynchronous {
            // Remove all lectures for asynchronous courses
            for lecture in course.lectures {
                modelContext.delete(lecture)
            }
            course.lectures.removeAll()
        } else {
            let meetingsToCreate = orderedSelectedDays.compactMap { day -> CourseMeeting? in
                guard let config = meetingConfigurations[day.index] else { return nil }
                let startComponents = Calendar.current.dateComponents([.hour, .minute], from: config.start)
                let endComponents = Calendar.current.dateComponents([.hour, .minute], from: config.end)
                return CourseMeeting(
                    dayOfWeek: day.index,
                    startHour: startComponents.hour ?? 9,
                    startMinute: startComponents.minute ?? 0,
                    endHour: endComponents.hour ?? 10,
                    endMinute: endComponents.minute ?? 0,
                    meetingType: sanitizedType(config.type),
                    course: course
                )
            }

            for meeting in meetingsToCreate {
                modelContext.insert(meeting)
                course.meetings.append(meeting)
            }

            regenerateLectures()
        }

        try? modelContext.save()
        onDismiss()
        dismiss()
    }

    private func regenerateLectures() {
        for lecture in course.lectures {
            modelContext.delete(lecture)
        }
        course.lectures.removeAll()

        let calendar = Calendar.current
        var date = termStartDate
        let endDate = termEndDate

        while date <= endDate {
            let weekday = calendar.component(.weekday, from: date)
            for meeting in course.meetings where meeting.dayOfWeek == weekday {
                let startDateTime = calendar.date(bySettingHour: meeting.startHour, minute: meeting.startMinute, second: 0, of: date) ?? date
                let lecture = Lecture(
                    title: sanitizedType(meeting.meetingType),
                    date: startDateTime,
                    meetingType: sanitizedType(meeting.meetingType),
                    course: course
                )
                modelContext.insert(lecture)
                course.lectures.append(lecture)
            }
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
    }
}
// MARK: - File import handling
extension CourseDetailView {
    // Handle imported files to create a Syllabus entry.
    fileprivate func handleImportedFile(url: URL) {
        // Try to read textual content where possible; otherwise use filename as title
        let title = url.deletingPathExtension().lastPathComponent
        var content = ""

        // Read data and attempt to decode as text first
        if let data = try? Data(contentsOf: url) {
            if let str = String(data: data, encoding: .utf8) {
                content = str
            } else {
                // Try platform-specific image detection
                #if canImport(UIKit)
                if let _ = UIImage(data: data) {
                    content = "Uploaded image: \(title)"
                } else {
                    content = "Uploaded file: \(url.lastPathComponent)"
                }
                #elseif os(macOS)
                if let _ = NSImage(data: data) {
                    content = "Uploaded image: \(title)"
                } else {
                    content = "Uploaded file: \(url.lastPathComponent)"
                }
                #else
                content = "Uploaded file: \(url.lastPathComponent)"
                #endif
            }
        }

        // Create Syllabus model and insert
        let newSyllabus = Syllabus(title: title, content: content, course: course)
        modelContext.insert(newSyllabus)
        try? modelContext.save()
    }
}
