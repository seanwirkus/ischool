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
    @State private var assignmentFilter: AssignmentFilter = .upcoming
    @State private var assignmentSort: AssignmentSort = .smart
    @State private var selectedTab = 0
    @State private var showingSyllabusView = false
    @State private var showingEditCourseSheet = false
    @State private var activeLectureForMaterial: Lecture? = nil
    @State private var noteTargetLecture: Lecture? = nil
    @State private var fileTargetLecture: Lecture? = nil
    @State private var showingMaterialOptions = false
    @State private var showingLectureFileImporter = false

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
                    LectureGridCardView(lecture: lecture) {
                        activeLectureForMaterial = lecture
                        showingMaterialOptions = true
                    }
                    .onTapGesture {
                        selectedLecture = lecture
                    }
                }
            }
        }
    }

    // MARK: - Assignments section (unchanged)
    private var assignmentsSection: some View {
        let assignments = course.assignments
        let stats = assignmentStats(for: assignments)
        let sortedAssignments = sortAssignments(assignments)
        let filteredAssignments = sortedAssignments.filter { assignmentFilter.includes($0) }

        return VStack(spacing: 20) {
            AssignmentSummaryCard(
                total: stats.total,
                completed: stats.completed,
                overdue: stats.overdue,
                upcoming: stats.upcoming
            )

            if assignments.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No Assignments Yet",
                    message: "Track homework, projects, and exams",
                    action: { showingAddAssignmentSheet = true },
                    actionTitle: "Add Assignment"
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(assignmentFilter.descriptionText(filteredCount: filteredAssignments.count, totalCount: stats.total))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            ForEach(AssignmentSort.allCases) { option in
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        assignmentSort = option
                                    }
                                } label: {
                                    Label(option.menuTitle, systemImage: option.icon)
                                    if option == assignmentSort {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.accentColor.opacity(0.12))
                                )
                        }
                    }

                    AssignmentFilterBar(selectedFilter: $assignmentFilter)
                }

                if filteredAssignments.isEmpty {
                    FilteredAssignmentsEmptyState(filter: assignmentFilter) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            assignmentFilter = .all
                            assignmentSort = .smart
                        }
                    }
                } else {
                    VStack(spacing: 14) {
                        ForEach(filteredAssignments) { assignment in
                            AssignmentCardView(assignment: assignment)
                        }
                    }
                }

                AddButton(action: { showingAddAssignmentSheet = true }, title: "Add Assignment")
                    .padding(.top, 8)
            }
        }
    }

    private func assignmentStats(for assignments: [Assignment]) -> (total: Int, completed: Int, overdue: Int, upcoming: Int) {
        let total = assignments.count
        let completed = assignments.filter { $0.isCompleted }.count
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let overdue = assignments.filter { assignment in
            guard let dueDate = assignment.dueDate else { return false }
            return !assignment.isCompleted && dueDate < startOfToday
        }.count
        let upcoming = assignments.filter { assignment in
            guard let dueDate = assignment.dueDate else { return !assignment.isCompleted }
            return !assignment.isCompleted && dueDate >= startOfToday
        }.count
        return (total, completed, overdue, upcoming)
    }

    private func sortAssignments(_ assignments: [Assignment]) -> [Assignment] {
        switch assignmentSort {
        case .smart:
            return assignments.sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted {
                    return !lhs.isCompleted
                }
                if let due1 = lhs.dueDate, let due2 = rhs.dueDate, due1 != due2 {
                    return due1 < due2
                }
                if (lhs.dueDate != nil) != (rhs.dueDate != nil) {
                    return lhs.dueDate != nil
                }
                if priorityRank(for: lhs) != priorityRank(for: rhs) {
                    return priorityRank(for: lhs) < priorityRank(for: rhs)
                }
                return lhs.createdDate > rhs.createdDate
            }
        case .dueDate:
            return assignments.sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?):
                    if l == r { return lhs.createdDate > rhs.createdDate }
                    return l < r
                case (nil, nil):
                    return lhs.createdDate > rhs.createdDate
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                }
            }
        case .priority:
            return assignments.sorted { lhs, rhs in
                let lhsRank = priorityRank(for: lhs)
                let rhsRank = priorityRank(for: rhs)
                if lhsRank == rhsRank {
                    return lhs.createdDate > rhs.createdDate
                }
                return lhsRank < rhsRank
            }
        case .recent:
            return assignments.sorted { $0.createdDate > $1.createdDate }
        }
    }

    private func priorityRank(for assignment: Assignment) -> Int {
        switch assignment.priority.lowercased() {
        case "high": return 0
        case "medium": return 1
        case "low": return 2
        default: return 3
        }
    }
}

// MARK: - LectureGridCardView with add material button
struct LectureGridCardView: View {
    let lecture: Lecture
    let addMaterialAction: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 10) {
                Text(lecture.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
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

                Spacer()

                HStack {
                    Spacer()
                    Button {
                        addMaterialAction()
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add Material")
                }
            }
            .padding(16)
            .frame(minHeight: 140) // Ensure minimum height for consistency
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
                    VStack(spacing: 4) {
                        Text(lecture.date, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(lecture.title)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(width: 100)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(course.colorValue.opacity(0.2))
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

struct FilteredAssignmentsEmptyState: View {
    let filter: AssignmentFilter
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: filter.emptyIcon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(filter.emptyTitle)
                .font(.title3.weight(.semibold))
            Text(filter.emptyMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
            Button(action: onReset) {
                Label("Reset Filters", systemImage: "arrow.counterclockwise")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

struct AssignmentSummaryCard: View {
    let total: Int
    let completed: Int
    let overdue: Int
    let upcoming: Int

    private var completionProgress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Assignment Progress")
                    .font(.headline)
                Spacer()
                Text("\(completed)/\(total) done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: completionProgress)
                .tint(.accentColor)

            HStack(spacing: 12) {
                AssignmentSummaryItem(icon: "clock.badge.checkmark", title: "Upcoming", value: upcoming, tint: .blue)
                AssignmentSummaryItem(icon: "exclamationmark.triangle.fill", title: "Overdue", value: overdue, tint: .orange)
                AssignmentSummaryItem(icon: "checkmark.circle.fill", title: "Completed", value: completed, tint: .green)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 18, x: 0, y: 10)
    }
}

struct AssignmentSummaryItem: View {
    let icon: String
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(tint.opacity(0.15))
        )
    }
}

struct AssignmentFilterBar: View {
    @Binding var selectedFilter: AssignmentFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AssignmentFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                            Text(filter.title)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .foregroundStyle(selectedFilter == filter ? Color.accentColor : .secondary)
                        .background(
                            Capsule()
                                .fill(
                                    selectedFilter == filter
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.primary.opacity(0.06)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct PriorityTag: View {
    let priority: String

    private var color: Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(priority.capitalized)
                .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(color.opacity(0.16))
        )
        .foregroundStyle(color)
    }
}

struct DueStatusBadge: View {
    let assignment: Assignment

    private var tint: Color {
        if assignment.isCompleted { return .green }
        if assignment.isOverdue { return .orange }
        return assignment.dueDate == nil ? .secondary : .accentColor
    }

    private var icon: String {
        assignment.dueDate == nil ? "calendar.badge.questionmark" : "calendar"
    }

    private var text: String {
        if let dueDate = assignment.dueDate {
            return dueDate.formatted(date: .abbreviated, time: .omitted)
        }
        return assignment.isCompleted ? "Wrapped up" : "No due date"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tint.opacity(0.12))
        )
        .foregroundStyle(tint)
    }
}

struct StatusChip: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(tint.opacity(0.15))
        )
        .foregroundStyle(tint)
        .font(.caption.weight(.semibold))
    }
}

enum AssignmentFilter: String, CaseIterable, Identifiable {
    case upcoming
    case overdue
    case completed
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .overdue: return "Overdue"
        case .completed: return "Completed"
        case .all: return "All"
        }
    }

    var icon: String {
        switch self {
        case .upcoming: return "clock.badge.checkmark"
        case .overdue: return "exclamationmark.triangle"
        case .completed: return "checkmark.circle"
        case .all: return "square.stack"
        }
    }

    var emptyIcon: String {
        switch self {
        case .upcoming: return "sparkles"
        case .overdue: return "party.popper"
        case .completed: return "checkmark.seal"
        case .all: return "tray"
        }
    }

    var emptyTitle: String {
        switch self {
        case .upcoming: return "No Upcoming Work"
        case .overdue: return "Nothing Overdue"
        case .completed: return "No Completed Tasks Yet"
        case .all: return "No Assignments"
        }
    }

    var emptyMessage: String {
        switch self {
        case .upcoming: return "You’re all caught up. Schedule the next assignment to stay ahead."
        case .overdue: return "Great job staying on top of deadlines!"
        case .completed: return "Mark assignments complete as you finish them."
        case .all: return "Start by adding your first assignment."
        }
    }

    func includes(_ assignment: Assignment) -> Bool {
        switch self {
        case .upcoming:
            return !assignment.isCompleted && !assignment.isOverdue
        case .overdue:
            return assignment.isOverdue
        case .completed:
            return assignment.isCompleted
        case .all:
            return true
        }
    }

    func descriptionText(filteredCount: Int, totalCount: Int) -> String {
        let pluralized = filteredCount == 1 ? "assignment" : "assignments"
        switch self {
        case .all:
            let totalLabel = totalCount == 1 ? "assignment" : "assignments"
            return "Showing all \(totalCount) \(totalLabel)"
        case .upcoming:
            return filteredCount == 0 ? "No upcoming assignments" : "\(filteredCount) upcoming \(pluralized)"
        case .overdue:
            return filteredCount == 0 ? "No overdue assignments" : "\(filteredCount) overdue \(pluralized)"
        case .completed:
            return filteredCount == 0 ? "Nothing marked complete yet" : "\(filteredCount) completed \(pluralized)"
        }
    }
}

enum AssignmentSort: CaseIterable, Identifiable {
    case smart
    case dueDate
    case priority
    case recent

    var id: Self { self }

    var menuTitle: String {
        switch self {
        case .smart: return "Smart Order"
        case .dueDate: return "Due Date"
        case .priority: return "Priority"
        case .recent: return "Recently Added"
        }
    }

    var icon: String {
        switch self {
        case .smart: return "wand.and.stars"
        case .dueDate: return "calendar"
        case .priority: return "flag"
        case .recent: return "clock.arrow.circlepath"
        }
    }
}

private extension Assignment {
    var isOverdue: Bool {
        guard let dueDate else { return false }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return !isCompleted && dueDate < startOfToday
    }

    var dueCountdownText: String {
        guard let dueDate else {
            return isCompleted ? "Finished" : "No deadline"
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDue = calendar.startOfDay(for: dueDate)
        guard let dayDifference = calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day else {
            return dueDate.formatted(date: .abbreviated, time: .omitted)
        }

        switch dayDifference {
        case ..<0:
            return "Overdue"
        case 0:
            return "Due today"
        case 1:
            return "Due tomorrow"
        default:
            return "Due in \(dayDifference) days"
        }
    }
}

struct AssignmentCardView: View {
    @Bindable var assignment: Assignment

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(assignment.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let description = assignment.assignmentDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer()

                PriorityTag(priority: assignment.priority)
            }

            HStack(spacing: 10) {
                DueStatusBadge(assignment: assignment)

                if assignment.isCompleted {
                    StatusChip(icon: "checkmark.seal.fill", text: "Completed", tint: .green)
                } else if assignment.isOverdue {
                    StatusChip(icon: "exclamationmark.triangle.fill", text: "Overdue", tint: .orange)
                } else {
                    StatusChip(icon: "clock", text: assignment.dueCountdownText, tint: .blue)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        assignment.isCompleted.toggle()
                    }
                } label: {
                    Label(assignment.isCompleted ? "Mark Incomplete" : "Mark Complete",
                          systemImage: assignment.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(assignment.isCompleted ? Color.primary.opacity(0.08) : Color.accentColor.opacity(0.18))
                        )
                        .foregroundStyle(assignment.isCompleted ? .primary : Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            .font(.caption)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [assignment.priorityColor.opacity(0.18), Color.primary.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var components: [String] = [assignment.title]
        if let description = assignment.assignmentDescription, !description.isEmpty {
            components.append(description)
        }
        if let dueDate = assignment.dueDate {
            components.append("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
        }
        components.append("Priority \(assignment.priority)")
        components.append(assignment.isCompleted ? "Completed" : "Incomplete")
        return components.joined(separator: ", ")
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
    @State private var showDeleteAlert = false
    
    @State private var selectedDays: Set<Int> = []
    @State private var meetingTimes: [Int: (start: Date, end: Date)] = [:]
    @State private var isAsynchronous = false
    @State private var termType: String = "Semester"
    @State private var termStartDate: Date = Date()
    @State private var termEndDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    
    private let weekdayOrder: [(label: String, index: Int)] = [
        ("Mon", 2), ("Tue", 3), ("Wed", 4), ("Thu", 5), ("Fri", 6), ("Sat", 7), ("Sun", 1)
    ]
    private let termTypes = ["Semester", "Quarter"]
    
    var body: some View {
        NavigationStack {
            Form {
                courseInfoSection
                courseDetailsSection
                meetingScheduleSection
                dangerZoneSection
            }
            .navigationTitle("Edit Course")
            .onAppear {
                // Initialize form values from course
                selectedDays = Set(course.meetings.map { $0.dayOfWeek })
                isAsynchronous = course.meetings.isEmpty
                termType = course.termType ?? "Semester"
                termStartDate = course.termStartDate ?? Date()
                termEndDate = course.termEndDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
                
                // Initialize meeting times
                for meeting in course.meetings {
                    let startDate = Calendar.current.date(bySettingHour: meeting.startHour, minute: meeting.startMinute, second: 0, of: Date()) ?? Date()
                    let endDate = Calendar.current.date(bySettingHour: meeting.endHour, minute: meeting.endMinute, second: 0, of: Date()) ?? Date()
                    meetingTimes[meeting.dayOfWeek] = (start: startDate, end: endDate)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveCourse()
                    }
                }
            }
            .alert("Delete Course?", isPresented: $showDeleteAlert, actions: {
                Button("Delete", role: .destructive) {
                    modelContext.delete(course)
                    onDismiss()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }, message: {
                Text("This action cannot be undone.")
            })
        }
    }

    private var courseInfoSection: some View {
        Section(header: Text("Course Info")) {
            TextField("Course Name", text: $course.name)
                .font(.title3)
                .padding(.vertical, 2)
            TextField("Description", text: Binding(
                get: { course.detail ?? "" },
                set: { course.detail = $0.isEmpty ? nil : $0 }
            ))
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.vertical, 2)
        }
    }

    private var courseDetailsSection: some View {
        Section(header: Text("Course Details")) {
            HStack {
                Picker("Term Type", selection: $termType) {
                    ForEach(termTypes, id: \ .self) { term in
                        Text(term)
                    }
                }
                .pickerStyle(.segmented)
                Spacer()
                TextField("Units", value: $course.units, formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.vertical, 2)
            
            HStack(spacing: 16) {
                DatePicker("Start", selection: $termStartDate, displayedComponents: .date)
                DatePicker("End", selection: $termEndDate, in: termStartDate..., displayedComponents: .date)
            }
            .padding(.vertical, 2)
            
            ColorPicker("Course Color", selection: Binding<Color>(
                get: { Color(hex: course.color) ?? .blue },
                set: { newColor in
                    course.color = newColor.toHexString() ?? course.color
                }
            ))
                .padding(.vertical, 2)
        }
    }

    private var meetingScheduleSection: some View {
        Section(header: Text("Meeting Schedule")) {
            Toggle("Asynchronous Course", isOn: $isAsynchronous)
                .padding(.vertical, 2)

            if !isAsynchronous {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meeting Days")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(weekdayOrder, id: \.index) { weekday in
                            Button(action: {
                                toggleWeekday(weekday.index)
                            }) {
                                Text(weekday.label)
                                    .font(.caption)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(selectedDays.contains(weekday.index) ? Color.accentColor.opacity(0.2) : Color.platformChipBackground)
                                    .foregroundColor(selectedDays.contains(weekday.index) ? Color.accentColor : Color.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !selectedDays.isEmpty {
                        ForEach(Array(selectedDays).sorted(), id: \.self) { dayIndex in
                            MeetingTimeRow(dayIndex: dayIndex,
                                           label: weekdayLabel(for: dayIndex),
                                           start: meetingTimes[dayIndex]?.start ?? defaultTime,
                                           end: meetingTimes[dayIndex]?.end ?? Calendar.current.date(byAdding: .hour, value: 1, to: defaultTime) ?? defaultTime,
                                           onStartChange: { newTime in
                                               let endTime = meetingTimes[dayIndex]?.end ?? Calendar.current.date(byAdding: .hour, value: 1, to: newTime) ?? newTime
                                               meetingTimes[dayIndex] = (start: newTime, end: endTime)
                                           },
                                           onEndChange: { newTime in
                                               let startTime = meetingTimes[dayIndex]?.start ?? defaultTime
                                               meetingTimes[dayIndex] = (start: startTime, end: newTime)
                                           })
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var dangerZoneSection: some View {
        Section(header: Text("Danger Zone")) {
            Button {
                showDeleteAlert = true
            } label: {
                Label("Delete Course", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var defaultTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }
    
    private func toggleWeekday(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
            meetingTimes[day] = nil
        } else {
            selectedDays.insert(day)
            meetingTimes[day] = (start: defaultTime, end: Calendar.current.date(byAdding: .hour, value: 1, to: defaultTime) ?? defaultTime)
        }
    }
    
    private func weekdayLabel(for index: Int) -> String {
        switch index {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return ""
        }
    }
    
    private func saveCourse() {
        // Update course properties
        course.termType = termType
        course.termStartDate = termStartDate
        course.termEndDate = termEndDate
        
        // Clear existing meetings
        for meeting in course.meetings {
            modelContext.delete(meeting)
        }
        course.meetings.removeAll()
        
        if !isAsynchronous && !selectedDays.isEmpty {
            // Create new meetings
            let newMeetings = selectedDays.compactMap { dayIndex -> CourseMeeting? in
                guard let times = meetingTimes[dayIndex] else { return nil }
                let startComponents = Calendar.current.dateComponents([.hour, .minute], from: times.start)
                let endComponents = Calendar.current.dateComponents([.hour, .minute], from: times.end)
                return CourseMeeting(
                    dayOfWeek: dayIndex,
                    startHour: startComponents.hour ?? 9,
                    startMinute: startComponents.minute ?? 0,
                    endHour: endComponents.hour ?? 10,
                    endMinute: endComponents.minute ?? 0,
                    course: course
                )
            }
            
            for meeting in newMeetings {
                modelContext.insert(meeting)
                course.meetings.append(meeting)
            }
            
            // Regenerate lectures if there are meetings
            regenerateLectures()
        } else {
            // For asynchronous courses, remove all lectures
            for lecture in course.lectures {
                modelContext.delete(lecture)
            }
            course.lectures.removeAll()
        }
        
        try? modelContext.save()
        onDismiss()
        dismiss()
    }

    
    
    private func regenerateLectures() {
        // Remove existing lectures
        for lecture in course.lectures {
            modelContext.delete(lecture)
        }
        course.lectures.removeAll()

        // Generate new lectures based on meetings
        let calendar = Calendar.current
        var date = termStartDate
        
        while date <= termEndDate {
            let weekday = calendar.component(.weekday, from: date)
            for meeting in course.meetings where meeting.dayOfWeek == weekday {
                let startDateTime = calendar.date(bySettingHour: meeting.startHour, minute: meeting.startMinute, second: 0, of: date) ?? date
                let lecture = Lecture(title: "Lecture", date: startDateTime, course: course)
                modelContext.insert(lecture)
                course.lectures.append(lecture)
            }
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
    }
}

// Helper view to break up complex HStack for meeting times
struct MeetingTimeRow: View {
    let dayIndex: Int
    let label: String
    let start: Date
    let end: Date
    let onStartChange: (Date) -> Void
    let onEndChange: (Date) -> Void

    var body: some View {
        VStack {
            HStack {
                Text(label)
                    .font(.subheadline.bold())
                    .frame(width: 60, alignment: .leading)
                Spacer()
                DatePicker("", selection: Binding(get: { start }, set: { onStartChange($0) }), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Text("to")
                DatePicker("", selection: Binding(get: { end }, set: { onEndChange($0) }), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            .padding(.vertical, 4)
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
