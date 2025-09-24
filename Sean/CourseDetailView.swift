//
//  CourseDetailView.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI
import SwiftData

struct CourseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let course: Course

    @State private var showingAddScheduleSheet = false
    @State private var selectedLecture: Lecture? = nil
    @State private var showingAddSyllabusSheet = false
    @State private var showingAddAssignmentSheet = false
    @State private var selectedTab = 0
    @State private var showingSyllabusView = false
    @State private var showingEditCourseSheet = false

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

                    // Syllabus access button (new requirement)
                    if course.syllabi.isEmpty {
                        Button {
                            showingAddSyllabusSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.15))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                        .accessibilityLabel("Add Syllabus")
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
        .sheet(isPresented: $showingAddScheduleSheet) {
            AddScheduleSheet(course: course) {
                // No-op on complete; list will refresh from model
            }
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
                    message: "Create your meeting schedule to generate lectures.",
                    action: { showingAddScheduleSheet = true },
                    actionTitle: "Edit Meetings"
                )
            } else {
                ForEach(sortedLectures) { lecture in
                    LectureGridCardView(lecture: lecture) {
                        // Action for add material button
                    }
                    .onTapGesture {
                        selectedLecture = lecture
                    }
                }

                AddButton(action: { showingAddScheduleSheet = true }, title: "Edit Meetings")
                    .gridCellColumns(2)
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

    var body: some View {
        NavigationStack {
            List {
                if course.syllabi.isEmpty {
                    Text("No syllabus items available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(course.syllabi.sorted(by: { $0.lastModified > $1.lastModified })) { syllabus in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(syllabus.title)
                                .font(.headline)
                            Text(syllabus.content)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
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
    @State private var showDeleteAlert = false
    
    @State private var selectedDays: Set<Int> = []
    @State private var meetingTimes: [Int: (start: Date, end: Date)] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                Section(header: Text("Details & Appearance")) {
                    TextField("Units", value: $course.units, formatter: NumberFormatter())
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 2)
                    ColorPicker("Course Color", selection: Binding<Color>(
                        get: { Color(hex: course.color) ?? .blue },
                        set: { newColor in
                            course.color = newColor.toHexString() ?? course.color
                        }
                    ))
                        .padding(.vertical, 2)
                }
                Section {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Course", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Course")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        // Update course meetings
                        let meetings = selectedDays.compactMap { dayIndex -> CourseMeeting? in
                            guard let times = meetingTimes[dayIndex] else { return nil }
                            let startComponents = Calendar.current.dateComponents([.hour, .minute], from: times.start)
                            let endComponents = Calendar.current.dateComponents([.hour, .minute], from: times.end)
                            return CourseMeeting(
                                dayOfWeek: dayIndex,
                                startHour: startComponents.hour ?? 9,
                                startMinute: startComponents.minute ?? 0,
                                endHour: endComponents.hour ?? 10,
                                endMinute: endComponents.minute ?? 0
                            )
                        }
                        course.meetings = meetings
                        onDismiss()
                        dismiss()
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
}
