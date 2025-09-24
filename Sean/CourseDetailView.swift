//
//  ClassDetailView.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI
import SwiftData

struct CourseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let course: Course

    @State private var showingAddLectureSheet = false
    @State private var selectedLecture: Lecture? = nil

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
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
                    }
                    Spacer()
                    Circle()
                        .fill(course.colorValue)
                        .frame(width: 20, height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Lectures list
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(course.lectures.sorted(by: { $0.date > $1.date })) { lecture in
                            LectureCardView(lecture: lecture)
                                .onTapGesture {
                                    selectedLecture = lecture
                                }
                        }

                        // Add lecture button
                        Button(action: { showingAddLectureSheet = true }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .frame(height: 80)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title)
                                        .foregroundStyle(.secondary)
                                    Text("Add Lecture")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationDestination(item: $selectedLecture) { lecture in
            LectureDetailView(lecture: lecture)
        }
                    .sheet(isPresented: $showingAddLectureSheet) {
                AddLectureSheet(course: course) { title, date, notes in
                    let newLecture = Lecture(title: title, date: date, notes: notes, course: course)
                    modelContext.insert(newLecture)
                }
            }
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(lecture.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(lecture.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let notes = lecture.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(lecture.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("\(lecture.lectureNotes.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: "note.text")
                            .font(.caption2)
                        Text("\(lecture.lectureFiles.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: "paperclip")
                            .font(.caption2)
                    }
                }
            }
            .padding(16)
        }
        .frame(height: 80)
    }
}

struct AddLectureSheet: View {
    let course: Course
    let onSave: (String, Date, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Lecture Info") {
                    TextField("Title", text: $title)
                    DatePicker("Date & Time", selection: $date)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Lecture")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, date, notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}