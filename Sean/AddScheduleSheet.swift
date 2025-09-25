import SwiftUI
import SwiftData

struct AddScheduleSheet: View {
    let course: Course
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var termType: String = "Semester"
    @State private var units: Int = 4
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    @State private var selectedWeekdays: Set<Int> = []
    @State private var time: Date = Date()
    @State private var meetingType: String = "Class"

    private let termTypes = ["Semester", "Quarter"]
    private let weekdays = Array(1...7) // 1=Sun ... 7=Sat
    private let meetingTypeOptions = ["Class", "Discussion", "Lab", "Workshop", "Study Session", "Office Hours"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                Text("Edit Course Schedule")
                    .font(.largeTitle.bold())
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.top, .horizontal], 24)

                ScrollView {
                    VStack(spacing: 24) {
                        // Card: Term & Dates
                        VStack(spacing: 16) {
                            HStack {
                                Picker("Term Type", selection: $termType) {
                                    ForEach(termTypes, id: \.self) { term in
                                        Text(term)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Spacer()
                                Stepper("Units: \(units)", value: $units, in: 1...6)
                                    .frame(width: 120)
                            }
                            HStack(spacing: 16) {
                                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                                DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.platformCardBackground))

                        // Card: Meeting Days & Time
                        VStack(spacing: 16) {
                            Text("Meeting Days")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 12) {
                                ForEach(weekdays, id: \.self) { day in
                                    Button(action: { toggleWeekday(day) }) {
                                        Text(weekdayLabel(day))
                                            .font(.subheadline)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(selectedWeekdays.contains(day) ? Color.accentColor.opacity(0.2) : Color.platformChipBackground)
                                            .foregroundColor(selectedWeekdays.contains(day) ? Color.accentColor : Color.primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            HStack {
                                Text("Meeting Time")
                                    .font(.headline)
                                Spacer()
                                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.platformCardBackground))

                        // Card: Schedule Preview
                        VStack(spacing: 12) {
                            Text("Schedule Preview")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if selectedWeekdays.isEmpty {
                                Text("No meetings scheduled.")
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(selectedWeekdays.sorted(), id: \.self) { day in
                                    HStack {
                                        Text(weekdayLabel(day))
                                            .font(.subheadline.bold())
                                            .frame(width: 80, alignment: .leading)
                                        Spacer()
                                        Text(time.formatted(date: .omitted, time: .shortened))
                                            .font(.subheadline)
                                            .foregroundColor(.accentColor)
                                        Text(meetingType)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.platformCardBackground))

                        // Card: Session Type
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Session Type")
                                .font(.headline)
                            Picker("Session Type", selection: $meetingType) {
                                ForEach(meetingTypeOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.platformCardBackground))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Update", action: createLectures)
                        .buttonStyle(.borderedProminent)
                }
                .padding([.horizontal, .bottom], 24)
            }
        }
    }
// ...existing code...
    
    private func toggleWeekday(_ day: Int) {
        if selectedWeekdays.contains(day) {
            selectedWeekdays.remove(day)
        } else {
            selectedWeekdays.insert(day)
        }
    }
    
    private func weekdayLabel(_ weekday: Int) -> String {
        let symbolIndex = (weekday + 5) % 7 // convert 1=Sun to Sunday symbol index 0
        let symbols = Calendar.current.shortWeekdaySymbols
        return symbols[symbolIndex]
    }
    
    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second
        
        return calendar.date(from: combined) ?? date
    }
    
    private func createLectures() {
        // Save term info and meetings to course, but do NOT auto-create lectures
        modelContext.insert(self.course) // ensure it's in context
        self.course.termType = termType
        self.course.units = units
        self.course.termStartDate = startDate
        self.course.termEndDate = endDate

        // Remove all meetings
        for meeting in self.course.meetings {
            modelContext.delete(meeting)
        }
        self.course.meetings.removeAll()

        // If no days selected, also remove all lectures for this course
        if selectedWeekdays.isEmpty {
            for lecture in self.course.lectures {
                modelContext.delete(lecture)
            }
        } else {
            // Add new meetings
            for weekday in selectedWeekdays {
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: time)
                let minute = calendar.component(.minute, from: time)
                // For now, set endHour/endMinute to startHour/startMinute (single time)
                let meeting = CourseMeeting(
                    dayOfWeek: weekday,
                    startHour: hour,
                    startMinute: minute,
                    endHour: hour,
                    endMinute: minute,
                    meetingType: meetingType,
                    course: self.course
                )
                modelContext.insert(meeting)
                self.course.meetings.append(meeting)
            }
            // Regenerate lectures
            regenerateLectures()
        }

        do {
            try modelContext.save()
        } catch {
            // handle error silently, or add alert if desired
        }

    self.onComplete()
    dismiss()
    }
    
    private func regenerateLectures() {
        // Remove existing lectures
        for lecture in self.course.lectures {
            modelContext.delete(lecture)
        }
        self.course.lectures.removeAll()

        // Generate new lectures
        let term = self.course.term ?? Term(name: "Default Term", startDate: self.course.termStartDate ?? Date(), endDate: self.course.termEndDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date())!)
        let calendar = Calendar.current
        var date = term.startDate
        while date <= term.endDate {
            let weekday = calendar.component(.weekday, from: date)
            for meeting in self.course.meetings where meeting.dayOfWeek == weekday {
                let startDateTime = calendar.date(bySettingHour: meeting.startHour, minute: meeting.startMinute, second: 0, of: date)!
                let lecture = Lecture(title: meeting.meetingType, date: startDateTime, meetingType: meeting.meetingType, course: self.course)
                modelContext.insert(lecture)
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
    }
}

struct AddScheduleSheet_Previews: PreviewProvider {
    static var previews: some View {
        AddScheduleSheet(course: Course(name: "Preview Course")) {}
            .modelContainer(for: [Course.self, Lecture.self, LectureNote.self, LectureFile.self, CourseMeeting.self, Syllabus.self, Assignment.self], inMemory: true)
    }
}
