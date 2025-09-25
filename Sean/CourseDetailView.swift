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
                    ForEach(termTypes, id: \.self) { term in
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
