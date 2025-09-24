//
//  ContentView.swift
//  Sean
//
//  Created by Sean Wirkus on 9/21/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.createdDate, order: .reverse) private var courses: [Course]

    @State private var showingAddCourseSheet = false
    @State private var selectedCourse: Course? = nil
    @State private var showingCalendar = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Liquid glass background
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("My Courses")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Button(action: { showingCalendar = true }) {
                            Image(systemName: "calendar")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Course cards grid
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                            ForEach(courses) { course in
                                CourseCardView(course: course)
                                    .onTapGesture {
                                        selectedCourse = course
                                    }
                            }

                            // Add new course card
                            Button(action: { showingAddCourseSheet = true }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .frame(height: 120)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                                    VStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.largeTitle)
                                            .foregroundStyle(.secondary)
                                        Text("Add Course")
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
            .navigationDestination(item: $selectedCourse) { course in
                CourseDetailView(course: course)
            }
            .sheet(isPresented: $showingAddCourseSheet) {
                AddCourseSheet { name, description, color in
                    let newCourse = Course(name: name, detail: description, color: color)
                    modelContext.insert(newCourse)
                }
            }
            .sheet(isPresented: $showingCalendar) {
                CalendarView()
            }
        }
    }
}

struct CourseCardView: View {
    let course: Course

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(course.colorValue)
                        .frame(width: 12, height: 12)
                    Spacer()
                    Text("\(course.lectures.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(course.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let det = course.detail {
                    Text(det)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(16)
        }
        .frame(height: 120)
    }
}

struct AddCourseSheet: View {
    let onSave: (String, String?, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var color = "#4ECDC4"

    let colors = ["#4ECDC4", "#45B7D1", "#96CEB4", "#FECA57", "#FF9FF3", "#54A0FF"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Course Info") {
                    TextField("Course Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(colors, id: \.self) { hex in
                            Button(action: { color = hex }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex) ?? .blue)
                                        .frame(width: 40, height: 40)
                                    if color == hex {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .font(.caption.bold())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Course")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, description.isEmpty ? nil : description, color)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Course.self, Lecture.self, LectureNote.self, LectureFile.self], inMemory: true)
}
