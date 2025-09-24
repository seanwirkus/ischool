# Sean - Course Tracker

A beautiful, liquid glass-themed macOS and iOS app for tracking your courses, lectures, notes, and files. Stay organized with a modern, Apple-inspired interface that syncs seamlessly with your iCloud calendar.

## ✨ Features

### 🎨 **Liquid Glass UI**
- Modern, translucent interface using Apple's `.ultraThinMaterial`
- Rounded corners, subtle shadows, and smooth animations
- Dark mode optimized for a premium feel

### 📚 **Course Management**
- Create and organize courses with custom colors and units
- **Smart Lecture Scheduling**: Auto-generate sequential lecture series with intelligent naming
- Course cards show lecture count, assignments, and color tags
- Add syllabus items and track assignments per course

### 📅 **Lecture Tracking**
- View auto-generated lectures with smart naming (e.g., "Lecture 1 - Sep 25")
- Week schedule on main screen shows current week's lectures
- One-tap access to lectures from course and calendar views
- Sequential numbering prevents redundant naming

### 📝 **Notes & Files**
- **Quick Capture**: Add notes or attach files directly from home screen
- **Smart Defaults**: Automatically links to today's or next lecture
- Notes timestamped for session history
- File attachments (documents, images, etc.) stored with lecture context

### 📋 **Syllabus Management**
- Add syllabus items with titles and detailed content
- Track important course information and policies
- Timestamped for modification history

### ✅ **Assignment Tracking**
- Create assignments with due dates and priority levels
- Color-coded priority system (High/Medium/Low)
- Sort by due date or creation date
- Mark completion status

### ☁️ **iCloud Calendar Sync**
- Seamless sync of lecture schedules with your iCloud calendar
- Automatic event creation for all scheduled lectures
- Request permissions only once for background updates

### 💾 **Data Persistence**
- Local storage powered by SwiftData
- All courses, lectures, notes, files, syllabi, and assignments saved automatically
- Cross-platform: data syncs across macOS and iOS

## 🚀 Getting Started

### Quick Setup
1. **Add Your First Course**: Tap the "+" chip on the main screen
2. **Enter Details**: Name, description, units, and pick a color
3. **Auto-Generate Schedule**: Choose Quarter/Semester/Custom → app fills dates automatically
4. **Pick Meeting Pattern**: Select MWF, TuTh, etc. → app creates sequential lectures instantly

### Daily Workflow
- **Quick Capture**: Use note/file/assignment buttons in header (auto-links to current lecture)
- **View Schedule**: Check week view or calendar for upcoming lectures
- **Organize Content**: Tap course chips to access syllabus, assignments, and lecture details

## 🧭 Navigation

### Main Screen
- Horizontal course chips at the top for quick access
- Week schedule view showing current week's lectures
- **Quick action buttons**: Note, File, Assignment (smart defaults to current lecture)
- Calendar button in header for full calendar view

### Course Detail
- **Tabbed interface**: Syllabus, Lectures, Assignments
- Course header shows units, lecture count, and assignment count
- Add content to any section with dedicated buttons

### Lecture Detail
- Notes editor with automatic timestamps
- File attachment viewer and uploader
- All content organized by lecture context

### Calendar View
- Apple-style calendar with today/tomorrow highlights
- Toggle for iCloud calendar sync
- View all upcoming lectures across courses

## 🛠️ Technologies Used

- **SwiftUI**: Declarative, modern UI framework
- **SwiftData**: Native persistence for Apple platforms
- **EventKit**: iCloud Calendar integration
- **UniformTypeIdentifiers**: File attachment support

## 📱 Platforms

- macOS 14.0+
- iOS 17.0+

## 🏗️ Building the Project

1. Clone the repository
2. Open `Sean.xcodeproj` in Xcode
3. Ensure you have the latest Xcode version
4. Build and run on your target device/simulator

## 📋 Requirements

- Xcode 15.0+
- Swift 5.9+
- iCloud account (optional, for calendar sync)

## 🤝 Contributing

This README serves as the primary specification for the app. When making changes:

1. Update this README to reflect new features or modifications
2. Ensure all features listed here are implemented and working
3. Test thoroughly on both macOS and iOS

## 📄 License

This project is private and for personal use.

---

## 📊 User Workflow

```
Main Screen
├── Quick Actions (Header)
│   ├── 📝 Note → auto-links to today's/next lecture
│   ├── 📎 File → select course → auto-links to lecture
│   └── ✅ Assignment → select course → set due date/priority
├── + Add Course
│   ├── Enter name, description, units, color
│   ├── Pick Quarter/Semester/Custom → auto-fill dates
│   ├── Select meeting pattern → auto-generate lectures
│   │   └── Smart naming: "Lecture 1 - Sep 25", "Lecture 2 - Sep 27"...
│   └── Save → Course chip appears
├── Course Chip → Course Detail
│   ├── 📋 Syllabus Tab
│   │   ├── View syllabus items
│   │   └── + Add Syllabus → title + content
│   ├── 📖 Lectures Tab
│   │   ├── View auto-generated lectures
│   │   └── + Add Schedule → create more lectures
│   └── ✅ Assignments Tab
│       ├── View assignments (sorted by due date)
│       └── + Add Assignment → title, due date, priority
├── Lecture Card → Lecture Detail
│   ├── View/edit notes
│   └── Add/attach files
└── Calendar Icon → Calendar View
    ├── View upcoming lectures
    └── Toggle iCloud sync
```

*Built with ❤️ using SwiftUI and Apple's design guidelines*