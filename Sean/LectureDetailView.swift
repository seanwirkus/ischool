//
//  LectureDetailView.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LectureDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let lecture: Lecture

    @State private var showingAddNoteSheet = false
    @State private var showingFileImporter = false
    @State private var showingTaskEditor = false
    @State private var taskToEdit: LectureTask? = nil

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(lecture.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                    HStack {
                        Text(lecture.date, style: .date)
                        Text("at")
                        Text(lecture.date, style: .time)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if let notes = lecture.notes {
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Notes and Files
                ScrollView {
                    VStack(spacing: 20) {
                        // Tasks section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Meeting Tasks")
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)
                                Spacer()
                                Button(action: {
                                    taskToEdit = nil
                                    showingTaskEditor = true
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityLabel("Add meeting task")
                            }

                            let tasks = lecture.lectureTasks.sorted { lhs, rhs in
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

                            if tasks.isEmpty {
                                Text("Capture readings, prep work, or follow-up tasks for this meeting.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 20)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(tasks) { task in
                                        LectureTaskRow(task: task) {
                                            withAnimation(.spring()) {
                                                task.isCompleted.toggle()
                                            }
                                        } onEdit: {
                                            taskToEdit = task
                                            showingTaskEditor = true
                                        } onDelete: {
                                            withAnimation(.easeInOut) {
                                                modelContext.delete(task)
                                            }
                                        }

                                        if task.id != tasks.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        // Notes section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Notes")
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)
                                Spacer()
                                Button(action: { showingAddNoteSheet = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if lecture.lectureNotes.isEmpty {
                                Text("No notes yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 20)
                            } else {
                                ForEach(lecture.lectureNotes.sorted(by: { $0.timestamp > $1.timestamp })) { note in
                                    NoteCardView(note: note)
                                }
                            }
                        }

                        // Files section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Files")
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)
                                Spacer()
                                Button(action: { showingFileImporter = true }) {
                                    Image(systemName: "paperclip.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if lecture.lectureFiles.isEmpty {
                                Text("No files attached")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 20)
                            } else {
                                ForEach(lecture.lectureFiles.sorted(by: { $0.timestamp > $1.timestamp })) { file in
                                    FileCardView(file: file)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showingTaskEditor) {
            let assignments = (lecture.course?.assignments ?? []).sorted { lhs, rhs in
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
                lecture: lecture,
                task: taskToEdit,
                assignments: assignments
            ) { title, details, dueDate, assignment in
                if let editingTask = taskToEdit {
                    editingTask.title = title
                    editingTask.details = details
                    editingTask.dueDate = dueDate
                    editingTask.assignment = assignment
                } else {
                    let newTask = LectureTask(
                        title: title,
                        details: details,
                        dueDate: dueDate,
                        lecture: lecture,
                        assignment: assignment
                    )
                    modelContext.insert(newTask)
                }
                taskToEdit = nil
            } onDelete: { task in
                modelContext.delete(task)
                taskToEdit = nil
            }
        }
        .sheet(isPresented: $showingAddNoteSheet) {
            AddNoteSheet(lecture: lecture) { content in
                let newNote = LectureNote(content: content, lecture: lecture)
                modelContext.insert(newNote)
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    do {
                        let data = try Data(contentsOf: url)
                        let filename = url.lastPathComponent
                        let newFile = LectureFile(filename: filename, fileData: data, lecture: lecture)
                        modelContext.insert(newFile)
                    } catch {
                        print("Error loading file: \(error)")
                    }
                }
            case .failure(let error):
                print("File import failed: \(error)")
            }
        }
    }
}

struct LectureTaskRow: View {
    @Bindable var task: LectureTask
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .strikethrough(task.isCompleted, color: .primary.opacity(0.6))

                HStack(spacing: 10) {
                    if let dueDate = task.dueDate {
                        Label {
                            Text(
                                dueDate,
                                format: Date.FormatStyle(date: .abbreviated, time: .shortened)
                            )
                        } icon: {
                            Image(systemName: "calendar.badge.clock")
                        }
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if let assignment = task.assignment {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text(assignment.title)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.08))
                        )
                    }
                }

                if let details = task.details, !details.isEmpty {
                    Text(details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu {
                Button("Edit", action: onEdit)
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(taskBackground)
        )
    }

    private var taskBackground: Color {
        if task.isCompleted {
            return Color.green.opacity(0.08)
        }
        return Color.accentColor.opacity(0.08)
    }
}

struct NoteCardView: View {
    let note: LectureNote

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 8) {
                Text(note.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(note.timestamp, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }
}

struct FileCardView: View {
    let file: LectureFile

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            HStack {
                Image(systemName: "doc.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.filename)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(file.timestamp, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { /* Share or open file */ }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }
}

struct AddNoteSheet: View {
    let lecture: Lecture
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var content = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Enter your note", text: $content, axis: .vertical)
                        .lineLimit(5...20)
                }
            }
            .navigationTitle("Add Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(content)
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}