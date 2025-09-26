import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Combine
import UIKit

// MARK: - Content View

struct ContentView: View {
    @State private var courseToDelete: Course? = nil
    @State private var showDeleteAlert: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \\Course.createdDate, order: .reverse) private var courses: [Course]
    @Query(sort: \\Lecture.date, order: .forward) private var lectures: [Lecture]

    @State private var showingAddCourseSheet = false
    @State private var selectedCourse: Course? = nil
    @State private var showingCalendar = false
    @State private var showingQuickNoteSheet = false
    @State private var showingQuickFileImporter = false
    @State private var showingQuickAssignmentSheet = false
    @State private var showingQuickFileCourseSelector = false
    @State private var pendingFileURLs: [URL] = []

    @StateObject private var dashboardModel = HomeDashboardViewModel()
    @State private var quickCaptureText: String = ""
    @State private var quickCaptureSelectedCourse: Course? = nil
    @State private var showingQuickCaptureCoursePicker: Bool = false

    @State private var showWidgetLibrary: Bool = false
    @State private var showWorkspaceInspector: Bool = false
    @State private var widgetInspectorSelection: HomeWidgetItem.ID? = nil
    @State private var workspacePalette = NeutralWorkspacePalette.default
    @State private var presentedWidgetStyle: HomeWidgetStyle? = nil

    @State private var timelineSelection = TimelineViewSelection.overview
    @State private var timelineVisibleDate = Date()
    @State private var timelineScrollOffset: CGFloat = .zero
    @State private var timelineMagnification: CGFloat = 1.0

    @State private var pinnedAnnouncements: [HomeAnnouncement] = []
    @State private var dismissedAnnouncements: Set<HomeAnnouncement.ID> = []

    @State private var highlightHoveringWidget: HomeWidgetItem.ID? = nil
    @State private var gridCrosshairPosition: CGPoint? = nil
    @State private var showAlignmentGuides: Bool = false
    @State private var alignmentGuideOpacity: Double = 0.0

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let size = proxy.size
                let isCompactWidth = size.width < 700

                ZStack {
                    NeutralHomeBackground(palette: workspacePalette)
                        .ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 40) {
                            header(isCompactWidth: isCompactWidth)

                            quickCapturePanel(isCompactWidth: isCompactWidth)
                                .padding(.horizontal, layoutHorizontalPadding(for: size.width))

                            workspaceEditorContainer(for: size)

                            announcementsSection()
                                .padding(.horizontal, layoutHorizontalPadding(for: size.width))

                            focusTimelineSection()
                                .padding(.horizontal, layoutHorizontalPadding(for: size.width))
                        }
                        .padding(.vertical, 40)
                    }

                    if showWidgetLibrary {
                        widgetLibraryOverlay(size: size)
                    }

                    if showWorkspaceInspector {
                        workspaceInspectorOverlay(size: size)
                    }
                }
                .frame(width: size.width, height: size.height)
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
                generateLectures(for: newCourse, meetings: meetings)
                dashboardModel.refreshCourseWidgets(from: courses + [newCourse])
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
                dashboardModel.registerNoteCapture(content, for: course)
            }
        }
        .sheet(isPresented: $showingQuickAssignmentSheet) {
            QuickAssignmentSheet(courses: courses) { title, description, dueDate, priority, course in
                let newAssignment = Assignment(title: title, assignmentDescription: description, dueDate: dueDate, priority: priority, course: course)
                modelContext.insert(newAssignment)
                dashboardModel.registerAssignmentCapture(title, dueDate: dueDate, for: course)
            }
        }
        .fileImporter(isPresented: $showingQuickFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                showingQuickFileCourseSelector = true
                pendingFileURLs = urls
            case .failure(let error):
                print("File import failed: \(error)")
            }
        }
        .sheet(isPresented: $showingQuickFileCourseSelector) {
            QuickFileCourseSelector(courses: courses) { course in
                let targetLecture = findNearestLecture(for: course)
                for url in pendingFileURLs {
                    do {
                        let data = try Data(contentsOf: url)
                        let filename = url.lastPathComponent
                        let newFile = LectureFile(filename: filename, fileData: data, lecture: targetLecture)
                        modelContext.insert(newFile)
                    } catch {
                        print("Error loading file: \(error)")
                    }
                }
                pendingFileURLs = []
                dashboardModel.registerFileCapture(for: course, count: pendingFileURLs.count)
            }
        }
        .alert("Delete Course?", isPresented: $showDeleteAlert, presenting: courseToDelete) { course in
            Button("Delete", role: .destructive) {
                modelContext.delete(course)
                courseToDelete = nil
                dashboardModel.refreshCourseWidgets(from: courses.filter { $0.id != course.id })
            }
            Button("Cancel", role: .cancel) {
                courseToDelete = nil
            }
        } message: { _ in
            Text("This action cannot be undone.")
        }
        .task(id: courses) {
            dashboardModel.refreshCourseWidgets(from: courses)
        }
        .task(id: lectures) {
            dashboardModel.updateLectures(lectures)
        }
        .onChange(of: showWidgetLibrary) { _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .onChange(of: showWorkspaceInspector) { newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                alignmentGuideOpacity = newValue ? 1 : 0
            }
        }
    }

    private func layoutHorizontalPadding(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<640: return 20
        case ..<1024: return 28
        default: return 40
        }
    }

    // MARK: Header

    @ViewBuilder
    private func header(isCompactWidth: Bool) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Home workspace")
                    .font(.system(size: isCompactWidth ? 34 : 42, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.94))
                Text("Customize your neutral dashboard and rearrange what matters for the week ahead.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Toggle(isOn: $dashboardModel.isEditingLayout.animation(.easeInOut(duration: 0.25))) {
                    Label("Layout editing", systemImage: dashboardModel.isEditingLayout ? "hand.tap" : "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                }
                .toggleStyle(SwitchToggleStyle(tint: workspacePalette.accentColor))
                .accessibilityLabel("Toggle layout editing mode")
                .onChange(of: dashboardModel.isEditingLayout) { newValue in
                    if !newValue {
                        highlightHoveringWidget = nil
                        gridCrosshairPosition = nil
                    }
                }

                Button {
                    showWidgetLibrary.toggle()
                } label: {
                    Label("Add widgets", systemImage: "square.grid.3x2")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            Capsule(style: .continuous)
                                .fill(workspacePalette.accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    showWorkspaceInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "slider.horizontal.3")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            Capsule(style: .continuous)
                                .fill(workspacePalette.neutralBorder.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens workspace palette and grid settings")
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(workspacePalette.panelBackground)
                    .shadow(color: workspacePalette.neutralShadow.opacity(0.18), radius: 20, x: 0, y: 12)
            )
        }
        .padding(.horizontal, layoutHorizontalPadding(for: UIScreen.main.bounds.width))
        .padding(.top, isCompactWidth ? 10 : 24)
    }

    // MARK: Quick Capture Panel

    @ViewBuilder
    private func quickCapturePanel(isCompactWidth: Bool) -> some View {
        VStack(spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick capture")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(workspacePalette.primaryText)
                    Text("Jot a note, add an assignment, or attach a file to the nearest lecture.")
                        .font(.callout)
                        .foregroundStyle(workspacePalette.secondaryText)
                }
                Spacer()
                Button {
                    showingQuickNoteSheet = true
                } label: {
                    Label("Note", systemImage: "note.text")
                        .labelStyle(.iconOnly)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(workspacePalette.accentColor.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
                Button {
                    showingQuickAssignmentSheet = true
                } label: {
                    Label("Assignment", systemImage: "checkmark.circle")
                        .labelStyle(.iconOnly)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(workspacePalette.accentColor.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
                Button {
                    showingQuickFileImporter = true
                } label: {
                    Label("File", systemImage: "paperclip")
                        .labelStyle(.iconOnly)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(workspacePalette.accentColor.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 16) {
                TextField("Capture an idea, to-do, or reminder", text: $quickCaptureText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(workspacePalette.surfaceBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(workspacePalette.neutralBorder, lineWidth: 1)
                    )

                HStack(spacing: 12) {
                    Button {
                        showingQuickCaptureCoursePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "graduationcap")
                            Text(quickCaptureSelectedCourse?.name ?? "Link to course")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(workspacePalette.primaryText)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(workspacePalette.surfaceBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(workspacePalette.neutralBorder.opacity(0.9), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        guard quickCaptureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
                        let capture = HomeQuickCaptureEntry(content: quickCaptureText, course: quickCaptureSelectedCourse)
                        dashboardModel.registerQuickCapture(capture)
                        quickCaptureText = ""
                        quickCaptureSelectedCourse = nil
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(workspacePalette.accentColor)
                            )
                            .foregroundStyle(workspacePalette.buttonText)
                    }
                    .buttonStyle(.plain)
                    .disabled(quickCaptureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(workspacePalette.panelBackground)
                .shadow(color: workspacePalette.neutralShadow.opacity(0.12), radius: 20, x: 0, y: 18)
        )
        .sheet(isPresented: $showingQuickCaptureCoursePicker) {
            NavigationView {
                List {
                    ForEach(courses) { course in
                        Button {
                            quickCaptureSelectedCourse = course
                            showingQuickCaptureCoursePicker = false
                        } label: {
                            HStack {
                                ColorChipLabel(color: course.color, title: course.name)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Link capture")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            showingQuickCaptureCoursePicker = false
                        }
                    }
                }
            }
        }
    }

    // MARK: Workspace Editor Container

    @ViewBuilder
    private func workspaceEditorContainer(for size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workspace layout")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(workspacePalette.primaryText)
                    Text("Drag, resize, and organize your dashboard widgets. Your arrangement stays pinned.")
                        .font(.callout)
                        .foregroundStyle(workspacePalette.secondaryText)
                }
                Spacer()
                Menu {
                    Picker("Density", selection: $dashboardModel.gridDensity) {
                        ForEach(HomeWorkspaceDensity.allCases) { density in
                            Text(density.label).tag(density)
                        }
                    }

                    Section("Guides") {
                        Toggle("Alignment guides", isOn: $showAlignmentGuides)
                        Toggle("Show crosshair", isOn: Binding(
                            get: { gridCrosshairPosition != nil },
                            set: { newValue in
                                gridCrosshairPosition = newValue ? CGPoint(x: size.width / 2, y: 0) : nil
                            }
                        ))
                    }

                    Button(role: .destructive) {
                        dashboardModel.resetLayout()
                    } label: {
                        Label("Reset layout", systemImage: "arrow.uturn.backward")
                    }
                } label: {
                    Label("Layout options", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(workspacePalette.surfaceBackground)
                                .shadow(color: workspacePalette.neutralShadow.opacity(0.12), radius: 6, x: 0, y: 4)
                        )
                }
                .buttonStyle(.plain)
            }

            HomeWorkspaceGrid(
                model: dashboardModel,
                palette: workspacePalette,
                timelineSelection: $timelineSelection,
                timelineVisibleDate: $timelineVisibleDate,
                timelineScrollOffset: $timelineScrollOffset,
                timelineMagnification: $timelineMagnification,
                courses: courses,
                lectures: lectures,
                isShowingAlignmentGuides: $showAlignmentGuides,
                highlightHoveringWidget: $highlightHoveringWidget,
                gridCrosshairPosition: $gridCrosshairPosition,
                widgetInspectorSelection: $widgetInspectorSelection,
                presentedWidgetStyle: $presentedWidgetStyle
            )
            .frame(maxWidth: .infinity)
            .frame(height: dashboardModel.gridHeight(for: size))
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(workspacePalette.workspaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .strokeBorder(workspacePalette.neutralBorder.opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: workspacePalette.neutralShadow.opacity(0.1), radius: 26, x: 0, y: 20)
            )
            .padding(.horizontal, layoutHorizontalPadding(for: size.width))
        }
    }

    // MARK: Announcements Section

    @ViewBuilder
    private func announcementsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Announcements")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(workspacePalette.primaryText)
                Spacer()
                Button {
                    pinnedAnnouncements.removeAll()
                } label: {
                    Label("Clear pins", systemImage: "pin.slash")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(pinnedAnnouncements.isEmpty)
            }

            if dashboardModel.quickCaptures.isEmpty && pinnedAnnouncements.isEmpty {
                Text("Capture notes or pin updates to see them here.")
                    .font(.callout)
                    .foregroundStyle(workspacePalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(workspacePalette.surfaceBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(workspacePalette.neutralBorder, lineWidth: 1)
                    )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(dashboardModel.quickCaptures.filter { !dismissedAnnouncements.contains($0.id) }) { capture in
                        announcementRow(for: capture)
                    }
                    ForEach(pinnedAnnouncements.filter { !dismissedAnnouncements.contains($0.id) }) { announcement in
                        announcementRow(for: announcement)
                    }
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(workspacePalette.panelBackground)
                .shadow(color: workspacePalette.neutralShadow.opacity(0.12), radius: 20, x: 0, y: 18)
        )
    }

    @ViewBuilder
    private func announcementRow(for announcement: HomeAnnouncement) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(announcement.badgeColor.opacity(0.2))
                .overlay(
                    Image(systemName: announcement.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(announcement.badgeColor)
                )
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(announcement.title)
                        .font(.headline)
                        .foregroundStyle(workspacePalette.primaryText)
                    Spacer()
                    Text(announcement.relativeDate)
                        .font(.caption)
                        .foregroundStyle(workspacePalette.secondaryText)
                }
                if let subtitle = announcement.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(workspacePalette.secondaryText)
                }
                if let detail = announcement.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(workspacePalette.tertiaryText)
                        .lineSpacing(4)
                }

                HStack(spacing: 12) {
                    if let actionTitle = announcement.primaryActionTitle {
                        Button(actionTitle) {
                            pinnedAnnouncements.append(announcement)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(workspacePalette.accentColor)
                    }

                    Button("Dismiss") {
                        dismissedAnnouncements.insert(announcement.id)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(workspacePalette.surfaceBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(workspacePalette.neutralBorder.opacity(0.9), lineWidth: 1)
        )
    }

    // MARK: Focus Timeline Section

    @ViewBuilder
    private func focusTimelineSection() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Focus timeline")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(workspacePalette.primaryText)
                Spacer()
                SegmentedPicker(selection: $timelineSelection) {
                    ForEach(TimelineViewSelection.allCases) { selection in
                        Text(selection.label)
                            .tag(selection)
                    }
                }
                .frame(maxWidth: 320)
            }

            FocusTimelineView(
                selection: timelineSelection,
                palette: workspacePalette,
                visibleDate: $timelineVisibleDate,
                scrollOffset: $timelineScrollOffset,
                magnification: $timelineMagnification,
                courses: courses,
                lectures: lectures
            )
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(workspacePalette.panelBackground)
                .shadow(color: workspacePalette.neutralShadow.opacity(0.12), radius: 20, x: 0, y: 18)
        )
    }

    // MARK: Overlays

    @ViewBuilder
    private func widgetLibraryOverlay(size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showWidgetLibrary = false
                    }
                }
            WidgetLibraryPanel(
                model: dashboardModel,
                palette: workspacePalette,
                courses: courses,
                announcements: pinnedAnnouncements,
                quickCaptures: dashboardModel.quickCaptures,
                onSelect: { widget in
                    dashboardModel.addWidget(widget)
                    showWidgetLibrary = false
                },
                onClose: {
                    showWidgetLibrary = false
                }
            )
            .frame(width: min(size.width - 40, 480))
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func workspaceInspectorOverlay(size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showWorkspaceInspector = false
                    }
                }

            WorkspaceInspectorPanel(
                palette: $workspacePalette,
                model: dashboardModel,
                isVisible: $showWorkspaceInspector,
                presentedWidgetStyle: $presentedWidgetStyle,
                widgetInspectorSelection: $widgetInspectorSelection,
                alignmentGuideOpacity: $alignmentGuideOpacity
            )
            .frame(width: min(size.width - 40, 520))
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    // MARK: Helpers

    private func findNearestLecture(for course: Course) -> Lecture? {
        let now = Date()
        let todayLectures = course.lectures.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
        if let todayLecture = todayLectures.sorted(by: { $0.date < $1.date }).first(where: { $0.date >= now }) {
            return todayLecture
        }
        if let firstTodayLecture = todayLectures.sorted(by: { $0.date < $1.date }).first {
            return firstTodayLecture
        }
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

// MARK: - Workspace Model

final class HomeDashboardViewModel: ObservableObject {
    @Published var widgets: [HomeWidgetItem]
    @Published var quickCaptures: [HomeAnnouncement]
    @Published var isEditingLayout: Bool
    @Published var gridDensity: HomeWorkspaceDensity
    @Published var gridColumns: Int
    @Published var gridRows: Int
    @Published var gridInsets: EdgeInsets
    @Published var dragState: HomeWidgetDragState
    @Published var layoutSnapshots: [HomeWidgetLayoutSnapshot]
    @Published var alignmentGuides: [HomeAlignmentGuide]
    @Published var dragOverlay: HomeDragOverlay?
    @Published var lectureTimelineCache: [UUID: [Lecture]]
    @Published var recentCaptures: [HomeQuickCaptureEntry]
    @Published var recentlyInteractedWidgetID: HomeWidgetItem.ID?

    private var cancellables: Set<AnyCancellable> = []

    init() {
        self.widgets = HomeWidgetItem.defaultWidgets
        self.quickCaptures = []
        self.isEditingLayout = false
        self.gridDensity = .comfortable
        self.gridColumns = 6
        self.gridRows = 8
        self.gridInsets = EdgeInsets(top: 42, leading: 42, bottom: 42, trailing: 42)
        self.dragState = HomeWidgetDragState()
        self.layoutSnapshots = []
        self.alignmentGuides = []
        self.dragOverlay = nil
        self.lectureTimelineCache = [:]
        self.recentCaptures = []
        self.recentlyInteractedWidgetID = nil

        setupAutoSnapshot()
    }

    func refreshCourseWidgets(from courses: [Course]) {
        let courseWidgets = courses.map { course in
            HomeWidgetItem(kind: .courseSummary(courseID: course.id), preferredSpan: .init(columns: 2, rows: 1))
        }
        mergeCourseWidgets(courseWidgets)
    }

    func updateLectures(_ lectures: [Lecture]) {
        lectureTimelineCache = Dictionary(grouping: lectures, by: { $0.course?.id ?? UUID() })
    }

    func registerQuickCapture(_ entry: HomeQuickCaptureEntry) {
        quickCaptures.insert(entry.asAnnouncement, at: 0)
        recentCaptures.insert(entry, at: 0)
        recentCaptures = Array(recentCaptures.prefix(12))
        propagateRecentCaptures()
        recordSnapshot(reason: .widgetUpdated)
    }

    func registerNoteCapture(_ text: String, for course: Course?) {
        let announcement = HomeAnnouncement(
            id: UUID(),
            title: "Note saved",
            subtitle: course?.name ?? "General",
            detail: text,
            date: Date(),
            badgeColor: .accentColor,
            symbol: "note.text",
            primaryActionTitle: nil
        )
        quickCaptures.insert(announcement, at: 0)
    }

    func registerAssignmentCapture(_ title: String, dueDate: Date, for course: Course?) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let announcement = HomeAnnouncement(
            id: UUID(),
            title: "Assignment added",
            subtitle: course?.name ?? "General",
            detail: "\(title) due \(formatter.string(from: dueDate))",
            date: Date(),
            badgeColor: .orange,
            symbol: "checkmark.circle",
            primaryActionTitle: "View"
        )
        quickCaptures.insert(announcement, at: 0)
    }

    func registerFileCapture(for course: Course?, count: Int) {
        guard count > 0 else { return }
        let announcement = HomeAnnouncement(
            id: UUID(),
            title: "Files linked",
            subtitle: course?.name ?? "General",
            detail: "Attached \(count) file\(count == 1 ? "" : "s")",
            date: Date(),
            badgeColor: .teal,
            symbol: "paperclip",
            primaryActionTitle: nil
        )
        quickCaptures.insert(announcement, at: 0)
    }

    func addWidget(_ widget: HomeWidgetItem) {
        var newWidget = widget
        newWidget.position = findNextAvailablePosition(for: newWidget)
        widgets.append(newWidget)
        recordSnapshot(reason: .userAdded)
    }

    func removeWidget(_ widget: HomeWidgetItem) {
        widgets.removeAll { $0.id == widget.id }
        recordSnapshot(reason: .userRemoved)
    }

    func updateWidget(_ widget: HomeWidgetItem) {
        guard let index = widgets.firstIndex(where: { $0.id == widget.id }) else { return }
        widgets[index] = widget
        recentlyInteractedWidgetID = widget.id
        recordSnapshot(reason: .widgetUpdated)
    }

    func resetLayout() {
        widgets = HomeWidgetItem.defaultWidgets
        gridColumns = 6
        gridRows = 8
        gridInsets = EdgeInsets(top: 42, leading: 42, bottom: 42, trailing: 42)
        recordSnapshot(reason: .reset)
    }

    func layout(for size: CGSize) -> HomeWorkspaceLayout {
        let columnWidth = size.width - gridInsets.leading - gridInsets.trailing
        let unitWidth = columnWidth / CGFloat(max(gridColumns, 1))
        let unitHeight = gridDensity.unitHeight
        return HomeWorkspaceLayout(
            columns: gridColumns,
            rows: gridRows,
            unitSize: CGSize(width: unitWidth, height: unitHeight),
            insets: gridInsets
        )
    }

    func gridHeight(for size: CGSize) -> CGFloat {
        let layout = layout(for: size)
        let height = CGFloat(gridRows) * layout.unitSize.height + gridInsets.top + gridInsets.bottom
        return max(height, 400)
    }

    func snapshotTimeline() -> [HomeWidgetLayoutSnapshot] {
        layoutSnapshots.sorted(by: { $0.timestamp > $1.timestamp })
    }

    func undoLastSnapshot() {
        guard let last = layoutSnapshots.last else { return }
        widgets = last.widgets
        layoutSnapshots.removeLast()
    }

    private func setupAutoSnapshot() {
        $widgets
            .dropFirst()
            .debounce(for: .seconds(1.2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recordSnapshot(reason: .auto)
            }
            .store(in: &cancellables)
    }

    private func mergeCourseWidgets(_ newWidgets: [HomeWidgetItem]) {
        let courseWidgets = widgets.filter { $0.kind.isCourseKind }
        let nonCourseWidgets = widgets.filter { !$0.kind.isCourseKind }
        let merged = nonCourseWidgets + newWidgets
        widgets = merged.uniqued()
        recordSnapshot(reason: .syncedCourses)
    }

    private func propagateRecentCaptures() {
        widgets = widgets.map { widget in
            var copy = widget
            if widget.kind == .quickCapture {
                copy.recentCaptures = recentCaptures
            }
            return copy
        }
    }

    private func findNextAvailablePosition(for widget: HomeWidgetItem) -> HomeWidgetPosition {
        var position = widget.position
        var attempts = 0
        while widgets.contains(where: { $0.position == position }) && attempts < 200 {
            position.column = (position.column + widget.preferredSpan.columns) % max(gridColumns, 1)
            if position.column + widget.preferredSpan.columns > gridColumns {
                position.column = 0
                position.row += widget.preferredSpan.rows
            }
            attempts += 1
        }
        return position
    }

    private func recordSnapshot(reason: HomeSnapshotReason) {
        let snapshot = HomeWidgetLayoutSnapshot(
            id: UUID(),
            timestamp: Date(),
            widgets: widgets,
            reason: reason
        )
        layoutSnapshots.append(snapshot)
        layoutSnapshots = Array(layoutSnapshots.suffix(40))
    }
}

// MARK: - Workspace Grid View

struct HomeWorkspaceGrid: View {
    @ObservedObject var model: HomeDashboardViewModel
    let palette: NeutralWorkspacePalette

    @Binding var timelineSelection: TimelineViewSelection
    @Binding var timelineVisibleDate: Date
    @Binding var timelineScrollOffset: CGFloat
    @Binding var timelineMagnification: CGFloat

    let courses: [Course]
    let lectures: [Lecture]

    @Binding var isShowingAlignmentGuides: Bool
    @Binding var highlightHoveringWidget: HomeWidgetItem.ID?
    @Binding var gridCrosshairPosition: CGPoint?
    @Binding var widgetInspectorSelection: HomeWidgetItem.ID?
    @Binding var presentedWidgetStyle: HomeWidgetStyle?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let layout = model.layout(for: geometry.size)

            ZStack(alignment: .topLeading) {
                palette.workspaceBackground
                    .overlay(
                        GridPatternOverlay(
                            columns: model.gridColumns,
                            rows: model.gridRows,
                            layout: layout,
                            palette: palette,
                            isVisible: model.isEditingLayout
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))

                ForEach(model.widgets) { widget in
                    widgetView(widget, layout: layout, size: geometry.size)
                        .frame(
                            width: layout.size(for: widget).width,
                            height: layout.size(for: widget).height
                        )
                        .position(layout.origin(for: widget))
                        .zIndex(zIndex(for: widget))
                        .animation(.easeInOut(duration: 0.22), value: widget.position)
                        .accessibilityIdentifier("widget-\(widget.kind.id)")
                        .overlay(alignment: .topTrailing) {
                            if model.isEditingLayout {
                                widgetEditOverlay(widget)
                            }
                        }
                }

                if isShowingAlignmentGuides {
                    AlignmentGuideOverlay(
                        layout: layout,
                        palette: palette,
                        opacity: paletteGuideOpacity,
                        highlightedColumn: highlightColumn,
                        highlightedRow: highlightRow,
                        crosshairPosition: gridCrosshairPosition
                    )
                    .transition(.opacity)
                }
            }
            .onChange(of: model.widgets) { _ in
                updateGuides(layout: layout)
            }
            .onChange(of: model.dragState.activeWidgetID) { _ in
                updateGuides(layout: layout)
            }
        }
    }

    private var paletteGuideOpacity: Double {
        isShowingAlignmentGuides ? 0.75 : 0
    }

    private var highlightColumn: Int? {
        guard let active = model.dragState.activeWidgetID,
              let widget = model.widgets.first(where: { $0.id == active }) else { return nil }
        return widget.position.column
    }

    private var highlightRow: Int? {
        guard let active = model.dragState.activeWidgetID,
              let widget = model.widgets.first(where: { $0.id == active }) else { return nil }
        return widget.position.row
    }

    @ViewBuilder
    private func widgetView(_ widget: HomeWidgetItem, layout: HomeWorkspaceLayout, size: CGSize) -> some View {
        let context = HomeWidgetContext(
            widget: widget,
            palette: palette,
            courses: courses,
            lectures: lectures,
            lectureTimeline: model.lectureTimelineCache,
            timelineSelection: timelineSelection,
            timelineVisibleDate: timelineVisibleDate,
            timelineScrollOffset: timelineScrollOffset,
            timelineMagnification: timelineMagnification,
            updateWidget: { updated in
                model.updateWidget(updated)
            }
        )

        HomeWidgetContainer(
            context: context,
            isEditing: model.isEditingLayout,
            dragState: $model.dragState,
            layout: layout,
            highlightHoveringWidget: $highlightHoveringWidget,
            widgetInspectorSelection: $widgetInspectorSelection,
            presentedWidgetStyle: $presentedWidgetStyle
        )
        .onTapGesture {
            if !model.isEditingLayout {
                widgetInspectorSelection = widget.id
            }
        }
    }

    @ViewBuilder
    private func widgetEditOverlay(_ widget: HomeWidgetItem) -> some View {
        HStack(spacing: 8) {
            Button {
                widgetInspectorSelection = widget.id
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.footnote.weight(.semibold))
                    .padding(8)
            }
            .buttonStyle(.borderless)
            .background(Circle().fill(palette.surfaceBackground.opacity(0.9)))

            Button(role: .destructive) {
                model.removeWidget(widget)
            } label: {
                Image(systemName: "trash")
                    .font(.footnote.weight(.semibold))
                    .padding(8)
            }
            .buttonStyle(.borderless)
            .background(Circle().fill(palette.surfaceBackground.opacity(0.9)))
        }
        .padding(8)
    }

    private func zIndex(for widget: HomeWidgetItem) -> Double {
        if model.dragState.activeWidgetID == widget.id {
            return 999
        }
        if model.recentlyInteractedWidgetID == widget.id {
            return 500
        }
        return Double(model.widgets.firstIndex(of: widget) ?? 0)
    }

    private func updateGuides(layout: HomeWorkspaceLayout) {
        guard isShowingAlignmentGuides else {
            model.alignmentGuides = []
            return
        }
        model.alignmentGuides = model.widgets.map { widget in
            let origin = layout.origin(for: widget)
            return HomeAlignmentGuide(
                widgetID: widget.id,
                column: widget.position.column,
                row: widget.position.row,
                x: origin.x,
                y: origin.y
            )
        }
    }
}

// Additional views and helpers continue below ...

// MARK: - Grid Pattern Overlay

struct GridPatternOverlay: View {
    let columns: Int
    let rows: Int
    let layout: HomeWorkspaceLayout
    let palette: NeutralWorkspacePalette
    let isVisible: Bool

    var body: some View {
        Canvas { context, size in
            guard isVisible else { return }
            let columnWidth = layout.unitSize.width
            let rowHeight = layout.unitSize.height
            for column in 0...columns {
                let x = layout.insets.leading + CGFloat(column) * columnWidth
                var path = Path()
                path.move(to: CGPoint(x: x, y: layout.insets.top))
                path.addLine(to: CGPoint(x: x, y: size.height - layout.insets.bottom))
                context.stroke(path, with: .color(palette.neutralBorder.opacity(0.28)), lineWidth: 1)
            }

            for row in 0...rows {
                let y = layout.insets.top + CGFloat(row) * rowHeight
                var path = Path()
                path.move(to: CGPoint(x: layout.insets.leading, y: y))
                path.addLine(to: CGPoint(x: size.width - layout.insets.trailing, y: y))
                context.stroke(path, with: .color(palette.neutralBorder.opacity(0.28)), lineWidth: 1)
            }
        }
    }
}

// MARK: - Alignment Guide Overlay

struct AlignmentGuideOverlay: View {
    let layout: HomeWorkspaceLayout
    let palette: NeutralWorkspacePalette
    let opacity: Double
    let highlightedColumn: Int?
    let highlightedRow: Int?
    let crosshairPosition: CGPoint?

    var body: some View {
        Canvas { context, size in
            context.opacity = opacity
            let guideColor = palette.accentColor.opacity(0.6)
            let columnWidth = layout.unitSize.width
            let rowHeight = layout.unitSize.height

            if let column = highlightedColumn {
                let x = layout.insets.leading + CGFloat(column) * columnWidth
                var path = Path()
                path.move(to: CGPoint(x: x, y: layout.insets.top))
                path.addLine(to: CGPoint(x: x, y: size.height - layout.insets.bottom))
                context.stroke(path, with: .color(guideColor), lineWidth: 2)
            }

            if let row = highlightedRow {
                let y = layout.insets.top + CGFloat(row) * rowHeight
                var path = Path()
                path.move(to: CGPoint(x: layout.insets.leading, y: y))
                path.addLine(to: CGPoint(x: size.width - layout.insets.trailing, y: y))
                context.stroke(path, with: .color(guideColor), lineWidth: 2)
            }

            if let crosshair = crosshairPosition {
                var horizontal = Path()
                horizontal.move(to: CGPoint(x: layout.insets.leading, y: crosshair.y))
                horizontal.addLine(to: CGPoint(x: size.width - layout.insets.trailing, y: crosshair.y))
                context.stroke(horizontal, with: .color(palette.neutralBorder.opacity(0.7)), lineWidth: 1)

                var vertical = Path()
                vertical.move(to: CGPoint(x: crosshair.x, y: layout.insets.top))
                vertical.addLine(to: CGPoint(x: crosshair.x, y: size.height - layout.insets.bottom))
                context.stroke(vertical, with: .color(palette.neutralBorder.opacity(0.7)), lineWidth: 1)
            }
        }
    }
}

// MARK: - Widget Container

struct HomeWidgetContainer: View {
    let context: HomeWidgetContext
    let isEditing: Bool
    @Binding var dragState: HomeWidgetDragState
    let layout: HomeWorkspaceLayout
    @Binding var highlightHoveringWidget: HomeWidgetItem.ID?
    @Binding var widgetInspectorSelection: HomeWidgetItem.ID?
    @Binding var presentedWidgetStyle: HomeWidgetStyle?

    @GestureState private var dragOffset: CGSize = .zero
    @State private var isHovering = false

    var body: some View {
        let gesture = DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onChanged { value in
                guard isEditing else { return }
                dragState.activeWidgetID = context.widget.id
                dragState.translation = value.translation
                highlightHoveringWidget = context.widget.id
            }
            .onEnded { value in
                guard isEditing else { return }
                dragState.translation = .zero
                dragState.activeWidgetID = nil
                highlightHoveringWidget = nil
                let updatedWidget = layout.widget(context.widget, movedBy: value.translation)
                context.updateWidget(updatedWidget)
            }

        return ZStack {
            widgetBody
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isEditing ? 2 : 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(context.widget.style.backgroundColor(palette: context.palette))
                )
                .overlay(alignment: .bottom) {
                    if isEditing {
                        resizeHandle
                    }
                }
        }
        .scaleEffect(dragScale)
        .opacity(isEditing ? 0.96 : 1)
        .shadow(color: shadowColor, radius: isEditing ? 16 : 10, x: 0, y: isEditing ? 12 : 6)
        .gesture(isEditing ? gesture : nil)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(context.widget.kind.accessibilityLabel)
        .onHover { hovering in
            guard isEditing else { return }
            isHovering = hovering
            highlightHoveringWidget = hovering ? context.widget.id : nil
        }
        .contextMenu {
            if !isEditing {
                Button("Open inspector") {
                    widgetInspectorSelection = context.widget.id
                }
            }
            Button("Change style") {
                presentedWidgetStyle = context.widget.style
            }
        }
    }

    private var widgetBody: some View {
        Group {
            switch context.widget.kind {
            case .quickCapture:
                QuickCaptureWidgetView(context: context)
            case .courseSummary:
                CourseSummaryWidgetView(context: context)
            case .schedule:
                ScheduleWidgetView(context: context)
            case .assignments:
                AssignmentWidgetView(context: context)
            case .notes:
                NotesWidgetView(context: context)
            case .files:
                FilesWidgetView(context: context)
            case .upNext:
                UpNextWidgetView(context: context)
            case .custom(let info):
                CustomWidgetView(context: context, info: info)
            }
        }
    }

    private var dragScale: CGFloat {
        if dragState.activeWidgetID == context.widget.id {
            return 1.04
        }
        return 1
    }

    private var shadowColor: Color {
        if isEditing {
            return context.palette.neutralShadow.opacity(0.3)
        }
        return context.palette.neutralShadow.opacity(0.18)
    }

    private var borderColor: Color {
        if isEditing {
            return context.palette.accentColor.opacity(0.8)
        }
        if isHovering {
            return context.palette.accentColor.opacity(0.6)
        }
        return context.palette.neutralBorder
    }

    private var resizeHandle: some View {
        HStack {
            Spacer()
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption2.weight(.bold))
                .padding(10)
                .background(Circle().fill(context.palette.surfaceBackground.opacity(0.92)))
                .offset(x: -14, y: -14)
                .gesture(resizeGesture)
        }
    }

    private var resizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard isEditing else { return }
                dragState.activeWidgetID = context.widget.id
                let updated = layout.widget(context.widget, resizedBy: value.translation)
                context.updateWidget(updated)
            }
            .onEnded { _ in
                dragState.activeWidgetID = nil
            }
    }
}

// MARK: - Widget Body Views

struct QuickCaptureWidgetView: View {
    let context: HomeWidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            widgetHeader(title: "Quick capture", subtitle: "Create a note on the fly")
            VStack(alignment: .leading, spacing: 12) {
                ForEach(context.recentCaptures.prefix(3)) { capture in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(capture.content)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(context.palette.primaryText)
                        if let courseName = capture.courseName {
                            Text(courseName)
                                .font(.caption)
                                .foregroundStyle(context.palette.secondaryText)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(context.palette.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                if context.recentCaptures.isEmpty {
                    Text("Saved captures will appear here.")
                        .font(.callout)
                        .foregroundStyle(context.palette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(24)
    }

    private func widgetHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(context.palette.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(context.palette.secondaryText)
        }
    }
}

struct CourseSummaryWidgetView: View {
    let context: HomeWidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            widgetHeader(title: context.widget.title ?? "Course", subtitle: "Upcoming lecture overview")
            VStack(alignment: .leading, spacing: 12) {
                if let courseID = context.widget.courseID,
                   let lectures = context.lectureTimeline[courseID]?.sorted(by: { $0.date < $1.date }).prefix(3),
                   let first = lectures.first {
                    ForEach(lectures, id: \.id) { lecture in
                        lectureRow(lecture)
                    }
                    Divider()
                    Text("Next lecture: \(first.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(context.palette.secondaryText)
                } else {
                    Text("Schedule lectures to see them here.")
                        .font(.callout)
                        .foregroundStyle(context.palette.secondaryText)
                }
            }
        }
        .padding(24)
    }

    private func widgetHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(context.palette.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(context.palette.secondaryText)
        }
    }

    @ViewBuilder
    private func lectureRow(_ lecture: Lecture) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lecture.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(context.palette.primaryText)
            Text(lecture.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(context.palette.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(context.palette.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ScheduleWidgetView: View {
    let context: HomeWidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader(title: "Schedule", subtitle: "This week's meetings")
            if context.lectures.isEmpty {
                Text("Add lectures to populate your schedule.")
                    .font(.callout)
                    .foregroundStyle(context.palette.secondaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(context.palette.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(context.lectures.prefix(4)) { lecture in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lecture.course?.name ?? "Course")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(context.palette.primaryText)
                            Text(lecture.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(context.palette.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundStyle(context.palette.secondaryText)
                    }
                    .padding(12)
                    .background(context.palette.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .padding(24)
    }

    private func widgetHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(context.palette.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(context.palette.secondaryText)
        }
    }
}

struct AssignmentWidgetView: View {
    let context: HomeWidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            widgetHeader(title: "Assignments", subtitle: "Monitor deadlines")
            Text("Stay tuned — assignments populate when created from the quick actions.")
                .font(.callout)
                .foregroundStyle(context.palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
    }

    private func widgetHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(context.palette.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(context.palette.secondaryText)
        }
    }
}

struct NotesWidgetView: View {
    let context: HomeWidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            widgetHeader(title: "Notes", subtitle: "Pin lecture notes here")
            Text("View or create notes from lectures to see them here.")
                .font(.callout)
                .foregroundStyle(context.palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
    }

    private func widgetHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(context.palette.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(context.palette.secondaryText)
        }
    }
}

struct FilesWidgetView: View {
    let context: HomeWidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            widgetHeader(title: "Files", subtitle: "Latest uploads")
            Text("Imported files will surface here automatically.")
                .font(.callout)
                .foregroundStyle(context.palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
    }

    private func widgetHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(context.palette.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(context.palette.secondaryText)
        }
    }
}

struct UpNextWidgetView: View {
    let context: HomeWidgetContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            widgetHeader(title: "Up next", subtitle: "Your focus highlights")
            if let upcoming = context.lectures.sorted(by: { $0.date < $1.date }).first {
                Text(upcoming.course?.name ?? "Course")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(context.palette.primaryText)
                Text(upcoming.date.formatted(date: .complete, time: .shortened))
                    .font(.callout)
                    .foregroundStyle(context.palette.secondaryText)
            } else {
                Text("Schedule lectures to see what's coming up.")
                    .font(.callout)
                    .foregroundStyle(context.palette.secondaryText)
            }
        }
        .padding(24)
    }

    private func widgetHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(context.palette.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(context.palette.secondaryText)
        }
    }
}

struct CustomWidgetView: View {
    let context: HomeWidgetContext
    let info: HomeCustomWidgetInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(info.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(context.palette.primaryText)
            Text(info.detail)
                .font(.callout)
                .foregroundStyle(context.palette.secondaryText)
            if !info.items.isEmpty {
                Divider()
                ForEach(info.items.indices, id: \.self) { index in
                    HStack {
                        Text(info.items[index])
                            .font(.subheadline)
                            .foregroundStyle(context.palette.primaryText)
                        Spacer()
                        Text("#\(index + 1)")
                            .font(.caption)
                            .foregroundStyle(context.palette.tertiaryText)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(24)
    }
}

// MARK: - Widget Context

struct HomeWidgetContext {
    var widget: HomeWidgetItem
    var palette: NeutralWorkspacePalette
    var courses: [Course]
    var lectures: [Lecture]
    var lectureTimeline: [UUID: [Lecture]]
    var timelineSelection: TimelineViewSelection
    var timelineVisibleDate: Date
    var timelineScrollOffset: CGFloat
    var timelineMagnification: CGFloat
    var updateWidget: (HomeWidgetItem) -> Void

    var recentCaptures: [HomeQuickCaptureEntry] {
        widget.recentCaptures
    }
}

// MARK: - Widget Models

struct HomeWidgetItem: Identifiable, Equatable, Hashable {
    let id: UUID
    var kind: HomeWidgetKind
    var position: HomeWidgetPosition
    var preferredSpan: HomeWidgetSpan
    var style: HomeWidgetStyle
    var title: String?
    var recentCaptures: [HomeQuickCaptureEntry]

    init(id: UUID = UUID(), kind: HomeWidgetKind, position: HomeWidgetPosition = .zero, preferredSpan: HomeWidgetSpan, style: HomeWidgetStyle = .neutral, title: String? = nil, recentCaptures: [HomeQuickCaptureEntry] = []) {
        self.id = id
        self.kind = kind
        self.position = position
        self.preferredSpan = preferredSpan
        self.style = style
        self.title = title
        self.recentCaptures = recentCaptures
    }

    var courseID: UUID? {
        if case let .courseSummary(courseID) = kind {
            return courseID
        }
        return nil
    }

    static var defaultWidgets: [HomeWidgetItem] {
        [
            HomeWidgetItem(kind: .quickCapture, position: .init(column: 0, row: 0), preferredSpan: .init(columns: 3, rows: 2)),
            HomeWidgetItem(kind: .schedule, position: .init(column: 3, row: 0), preferredSpan: .init(columns: 3, rows: 2)),
            HomeWidgetItem(kind: .upNext, position: .init(column: 0, row: 2), preferredSpan: .init(columns: 2, rows: 2)),
            HomeWidgetItem(kind: .assignments, position: .init(column: 2, row: 2), preferredSpan: .init(columns: 2, rows: 2)),
            HomeWidgetItem(kind: .notes, position: .init(column: 4, row: 2), preferredSpan: .init(columns: 2, rows: 2)),
            HomeWidgetItem(kind: .files, position: .init(column: 0, row: 4), preferredSpan: .init(columns: 3, rows: 2))
        ]
    }
}

enum HomeWidgetKind: Hashable {
    case quickCapture
    case courseSummary(courseID: UUID)
    case schedule
    case assignments
    case notes
    case files
    case upNext
    case custom(HomeCustomWidgetInfo)

    var id: String {
        switch self {
        case .quickCapture: return "quickCapture"
        case let .courseSummary(courseID): return "courseSummary-\(courseID)"
        case .schedule: return "schedule"
        case .assignments: return "assignments"
        case .notes: return "notes"
        case .files: return "files"
        case .upNext: return "upNext"
        case let .custom(info): return "custom-\(info.id.uuidString)"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .quickCapture: return "Quick capture"
        case .courseSummary: return "Course summary"
        case .schedule: return "Schedule overview"
        case .assignments: return "Assignments"
        case .notes: return "Notes"
        case .files: return "Files"
        case .upNext: return "Up next"
        case .custom(let info): return info.title
        }
    }

    var isCourseKind: Bool {
        if case .courseSummary = self { return true }
        return false
    }
}

struct HomeWidgetSpan: Hashable {
    var columns: Int
    var rows: Int

    static let single = HomeWidgetSpan(columns: 1, rows: 1)
}

struct HomeWidgetPosition: Hashable {
    var column: Int
    var row: Int

    static let zero = HomeWidgetPosition(column: 0, row: 0)
}

enum HomeWidgetStyle: String, CaseIterable, Identifiable {
    case neutral
    case softContrast
    case outline
    case filled

    var id: String { rawValue }

    func backgroundColor(palette: NeutralWorkspacePalette) -> Color {
        switch self {
        case .neutral: return palette.surfaceBackground
        case .softContrast: return palette.panelBackground
        case .outline: return palette.workspaceBackground
        case .filled: return palette.accentColor.opacity(0.12)
        }
    }
}

struct HomeWidgetDragState {
    var activeWidgetID: HomeWidgetItem.ID?
    var translation: CGSize

    init(activeWidgetID: HomeWidgetItem.ID? = nil, translation: CGSize = .zero) {
        self.activeWidgetID = activeWidgetID
        self.translation = translation
    }
}

struct HomeWorkspaceLayout {
    var columns: Int
    var rows: Int
    var unitSize: CGSize
    var insets: EdgeInsets

    func size(for widget: HomeWidgetItem) -> CGSize {
        CGSize(width: CGFloat(widget.preferredSpan.columns) * unitSize.width - 16, height: CGFloat(widget.preferredSpan.rows) * unitSize.height - 16)
    }

    func origin(for widget: HomeWidgetItem) -> CGPoint {
        let x = insets.leading + CGFloat(widget.position.column) * unitSize.width + size(for: widget).width / 2 + 8
        let y = insets.top + CGFloat(widget.position.row) * unitSize.height + size(for: widget).height / 2 + 8
        return CGPoint(x: x, y: y)
    }

    func widget(_ widget: HomeWidgetItem, movedBy translation: CGSize) -> HomeWidgetItem {
        var updated = widget
        let deltaColumns = Int((translation.width / unitSize.width).rounded())
        let deltaRows = Int((translation.height / unitSize.height).rounded())
        updated.position.column = max(0, min(columns - updated.preferredSpan.columns, widget.position.column + deltaColumns))
        updated.position.row = max(0, min(rows - updated.preferredSpan.rows, widget.position.row + deltaRows))
        return updated
    }

    func widget(_ widget: HomeWidgetItem, resizedBy translation: CGSize) -> HomeWidgetItem {
        var updated = widget
        let deltaColumns = Int((translation.width / unitSize.width).rounded())
        let deltaRows = Int((translation.height / unitSize.height).rounded())
        updated.preferredSpan.columns = max(1, min(columns, widget.preferredSpan.columns + deltaColumns))
        updated.preferredSpan.rows = max(1, min(rows, widget.preferredSpan.rows + deltaRows))
        return updated
    }
}

enum HomeWorkspaceDensity: CaseIterable, Identifiable {
    case comfortable
    case compact
    case spacious

    var id: String { label }

    var label: String {
        switch self {
        case .comfortable: return "Comfortable"
        case .compact: return "Compact"
        case .spacious: return "Spacious"
        }
    }

    var unitHeight: CGFloat {
        switch self {
        case .comfortable: return 160
        case .compact: return 130
        case .spacious: return 190
        }
    }
}

struct HomeDragOverlay {
    var widgetID: HomeWidgetItem.ID
    var translation: CGSize
}

struct HomeWidgetLayoutSnapshot: Identifiable {
    let id: UUID
    let timestamp: Date
    let widgets: [HomeWidgetItem]
    let reason: HomeSnapshotReason
}

enum HomeSnapshotReason: String {
    case auto
    case userAdded
    case userRemoved
    case widgetUpdated
    case reset
    case syncedCourses
}

struct HomeAlignmentGuide: Identifiable {
    let id = UUID()
    let widgetID: HomeWidgetItem.ID
    let column: Int
    let row: Int
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Neutral Palette

struct NeutralWorkspacePalette: Equatable {
    var accentColor: Color
    var workspaceBackground: Color
    var panelBackground: Color
    var surfaceBackground: Color
    var neutralBorder: Color
    var neutralShadow: Color
    var primaryText: Color
    var secondaryText: Color
    var tertiaryText: Color
    var buttonText: Color

    static let `default` = NeutralWorkspacePalette(
        accentColor: Color(red: 0.46, green: 0.55, blue: 0.83),
        workspaceBackground: Color(red: 0.93, green: 0.94, blue: 0.95),
        panelBackground: Color(red: 0.97, green: 0.97, blue: 0.98),
        surfaceBackground: Color.white,
        neutralBorder: Color(red: 0.82, green: 0.83, blue: 0.85),
        neutralShadow: Color.black,
        primaryText: Color(red: 0.1, green: 0.12, blue: 0.16),
        secondaryText: Color(red: 0.32, green: 0.34, blue: 0.38),
        tertiaryText: Color(red: 0.46, green: 0.48, blue: 0.52),
        buttonText: Color.white
    )

    static let warm = NeutralWorkspacePalette(
        accentColor: Color(red: 0.72, green: 0.49, blue: 0.3),
        workspaceBackground: Color(red: 0.95, green: 0.93, blue: 0.9),
        panelBackground: Color(red: 0.98, green: 0.96, blue: 0.93),
        surfaceBackground: Color(red: 0.99, green: 0.98, blue: 0.96),
        neutralBorder: Color(red: 0.86, green: 0.82, blue: 0.76),
        neutralShadow: Color(red: 0.24, green: 0.2, blue: 0.18),
        primaryText: Color(red: 0.18, green: 0.17, blue: 0.16),
        secondaryText: Color(red: 0.36, green: 0.34, blue: 0.32),
        tertiaryText: Color(red: 0.52, green: 0.5, blue: 0.48),
        buttonText: Color.white
    )

    static let slate = NeutralWorkspacePalette(
        accentColor: Color(red: 0.38, green: 0.51, blue: 0.65),
        workspaceBackground: Color(red: 0.18, green: 0.2, blue: 0.23),
        panelBackground: Color(red: 0.24, green: 0.26, blue: 0.3),
        surfaceBackground: Color(red: 0.18, green: 0.2, blue: 0.24),
        neutralBorder: Color(red: 0.34, green: 0.36, blue: 0.4),
        neutralShadow: Color.black,
        primaryText: Color.white,
        secondaryText: Color(red: 0.76, green: 0.79, blue: 0.82),
        tertiaryText: Color(red: 0.58, green: 0.61, blue: 0.66),
        buttonText: Color.white
    )
}

// MARK: - Neutral Background

struct NeutralHomeBackground: View {
    let palette: NeutralWorkspacePalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: [
                palette.workspaceBackground,
                palette.workspaceBackground.opacity(colorScheme == .dark ? 0.94 : 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Widget Library Panel

struct WidgetLibraryPanel: View {
    @ObservedObject var model: HomeDashboardViewModel
    let palette: NeutralWorkspacePalette
    let courses: [Course]
    let announcements: [HomeAnnouncement]
    let quickCaptures: [HomeAnnouncement]
    let onSelect: (HomeWidgetItem) -> Void
    let onClose: () -> Void

    @State private var searchText: String = ""
    @State private var selectedFilter: WidgetLibraryFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Widget library")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") {
                    onClose()
                }
            }

            Text("Active widgets: \(model.widgets.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search widgets", text: $searchText)
                .textFieldStyle(.roundedBorder)

            Picker("Filter", selection: $selectedFilter) {
                ForEach(WidgetLibraryFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if !announcements.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent activity")
                                .font(.headline)
                            ForEach(announcements.prefix(3)) { announcement in
                                Text(announcement.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(palette.panelBackground)
                        )
                    }

                    if !quickCaptures.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick captures")
                                .font(.headline)
                            ForEach(quickCaptures.prefix(3)) { capture in
                                Text(capture.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(palette.panelBackground)
                        )
                    }

                    ForEach(filteredWidgets) { descriptor in
                        Button {
                            onSelect(descriptor.widget)
                        } label: {
                            HStack(alignment: .center, spacing: 16) {
                                Image(systemName: descriptor.icon)
                                    .font(.title3)
                                    .frame(width: 42, height: 42)
                                    .background(Circle().fill(palette.accentColor.opacity(0.12)))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(descriptor.title)
                                        .font(.headline)
                                    Text(descriptor.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(palette.accentColor)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(palette.panelBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(palette.neutralBorder.opacity(0.8), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.workspaceBackground)
                .shadow(color: palette.neutralShadow.opacity(0.24), radius: 30, x: 0, y: 20)
        )
    }

    private var filteredWidgets: [WidgetDescriptor] {
        let all = WidgetDescriptor.allWidgets(courses: courses)
        return all.filter { descriptor in
            (searchText.isEmpty || descriptor.title.localizedCaseInsensitiveContains(searchText)) &&
            (selectedFilter == .all || descriptor.categories.contains(selectedFilter))
        }
    }
}

enum WidgetLibraryFilter: String, CaseIterable, Identifiable {
    case all
    case planning
    case capture
    case insight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .planning: return "Planning"
        case .capture: return "Capture"
        case .insight: return "Insight"
        }
    }
}

struct WidgetDescriptor: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let categories: [WidgetLibraryFilter]
    let widget: HomeWidgetItem

    static func allWidgets(courses: [Course]) -> [WidgetDescriptor] {
        var descriptors: [WidgetDescriptor] = [
            WidgetDescriptor(
                title: "Quick capture",
                subtitle: "Save reminders and notes",
                icon: "square.and.pencil",
                categories: [.capture],
                widget: HomeWidgetItem(kind: .quickCapture, preferredSpan: .init(columns: 2, rows: 2))
            ),
            WidgetDescriptor(
                title: "Schedule",
                subtitle: "Week at a glance",
                icon: "calendar",
                categories: [.planning],
                widget: HomeWidgetItem(kind: .schedule, preferredSpan: .init(columns: 3, rows: 2))
            ),
            WidgetDescriptor(
                title: "Up next",
                subtitle: "Focus on the next lecture",
                icon: "figure.walk",
                categories: [.planning, .insight],
                widget: HomeWidgetItem(kind: .upNext, preferredSpan: .init(columns: 2, rows: 2))
            )
        ]

        descriptors += courses.map { course in
            WidgetDescriptor(
                title: course.name,
                subtitle: "Course summary",
                icon: "graduationcap",
                categories: [.planning, .insight],
                widget: HomeWidgetItem(kind: .courseSummary(courseID: course.id), preferredSpan: .init(columns: 2, rows: 2), title: course.name)
            )
        }

        return descriptors
    }
}

// MARK: - Workspace Inspector

struct WorkspaceInspectorPanel: View {
    @Binding var palette: NeutralWorkspacePalette
    @ObservedObject var model: HomeDashboardViewModel
    @Binding var isVisible: Bool
    @Binding var presentedWidgetStyle: HomeWidgetStyle?
    @Binding var widgetInspectorSelection: HomeWidgetItem.ID?
    @Binding var alignmentGuideOpacity: Double

    @State private var selectedPalette: NeutralPaletteOption = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Workspace inspector")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") {
                    isVisible = false
                }
            }

            paletteSection
            gridSection
            snapshotSection
            inspectorSection
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.workspaceBackground)
                .shadow(color: palette.neutralShadow.opacity(0.24), radius: 30, x: 0, y: 20)
        )
        .onChange(of: selectedPalette) { newValue in
            switch newValue {
            case .default: palette = .default
            case .warm: palette = .warm
            case .slate: palette = .slate
            }
        }
    }

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Palette")
                .font(.headline)
            Picker("Palette", selection: $selectedPalette) {
                ForEach(NeutralPaletteOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grid")
                .font(.headline)
            Stepper(value: $model.gridColumns, in: 3...10) {
                Text("Columns: \(model.gridColumns)")
            }
            Stepper(value: $model.gridRows, in: 4...14) {
                Text("Rows: \(model.gridRows)")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Insets")
                Slider(value: Binding(get: { Double(model.gridInsets.leading) }, set: { model.gridInsets.leading = CGFloat($0); model.gridInsets.trailing = CGFloat($0) }), in: 24...80) {
                    Text("Horizontal")
                }
                Slider(value: Binding(get: { Double(model.gridInsets.top) }, set: { model.gridInsets.top = CGFloat($0); model.gridInsets.bottom = CGFloat($0) }), in: 24...80) {
                    Text("Vertical")
                }
            }
        }
    }

    private var snapshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Snapshots")
                .font(.headline)
            if model.snapshotTimeline().isEmpty {
                Text("Snapshots will appear as you edit the layout.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(model.snapshotTimeline()) { snapshot in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(snapshot.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.caption.weight(.semibold))
                                Text(snapshot.reason.rawValue.capitalized)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Button("Restore") {
                                    model.widgets = snapshot.widgets
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(palette.accentColor)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.panelBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(palette.neutralBorder.opacity(0.7), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }

    private var inspectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Widget inspector")
                .font(.headline)
            if let selectedID = widgetInspectorSelection,
               let widget = model.widgets.first(where: { $0.id == selectedID }) {
                WidgetInspectorView(widget: widget, palette: palette) { updated in
                    model.updateWidget(updated)
                }
            } else {
                Text("Select a widget to view its details.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

enum NeutralPaletteOption: String, CaseIterable, Identifiable {
    case `default`
    case warm
    case slate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .default: return "Default"
        case .warm: return "Warm"
        case .slate: return "Slate"
        }
    }
}

struct WidgetInspectorView: View {
    var widget: HomeWidgetItem
    let palette: NeutralWorkspacePalette
    var onUpdate: (HomeWidgetItem) -> Void

    @State private var title: String = ""
    @State private var style: HomeWidgetStyle = .neutral
    @State private var spanColumns: Double = 2
    @State private var spanRows: Double = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("Style", selection: $style) {
                ForEach(HomeWidgetStyle.allCases) { style in
                    Text(style.rawValue.capitalized).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Stepper(value: $spanColumns, in: 1...4, step: 1) {
                Text("Columns: \(Int(spanColumns))")
            }
            Stepper(value: $spanRows, in: 1...4, step: 1) {
                Text("Rows: \(Int(spanRows))")
            }

            Button("Apply") {
                var updated = widget
                updated.title = title.isEmpty ? widget.title : title
                updated.style = style
                updated.preferredSpan = HomeWidgetSpan(columns: Int(spanColumns), rows: Int(spanRows))
                onUpdate(updated)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accentColor)
        }
        .onAppear {
            title = widget.title ?? ""
            style = widget.style
            spanColumns = Double(widget.preferredSpan.columns)
            spanRows = Double(widget.preferredSpan.rows)
        }
    }
}

// MARK: - Quick Capture Model

struct HomeQuickCaptureEntry: Identifiable, Hashable {
    let id: UUID
    let content: String
    let courseID: UUID?
    let courseName: String?
    let date: Date

    init(id: UUID = UUID(), content: String, course: Course?) {
        self.id = id
        self.content = content
        self.courseID = course?.id
        self.courseName = course?.name
        self.date = Date()
    }

    var asAnnouncement: HomeAnnouncement {
        HomeAnnouncement(
            id: id,
            title: "Capture saved",
            subtitle: courseName,
            detail: content,
            date: date,
            badgeColor: .blue,
            symbol: "square.and.pencil",
            primaryActionTitle: nil
        )
    }
}

struct HomeAnnouncement: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String?
    let detail: String?
    let date: Date
    let badgeColor: Color
    let symbol: String
    let primaryActionTitle: String?

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Focus Timeline

enum TimelineViewSelection: String, CaseIterable, Identifiable {
    case overview
    case day
    case week

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Overview"
        case .day: return "Day"
        case .week: return "Week"
        }
    }
}

struct SegmentedPicker<SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue
    @ViewBuilder var content: () -> Content

    var body: some View {
        Picker("", selection: $selection) {
            content()
        }
        .pickerStyle(.segmented)
    }
}

struct FocusTimelineView: View {
    let selection: TimelineViewSelection
    let palette: NeutralWorkspacePalette
    @Binding var visibleDate: Date
    @Binding var scrollOffset: CGFloat
    @Binding var magnification: CGFloat
    let courses: [Course]
    let lectures: [Lecture]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(selectionDescription)
                .font(.callout)
                .foregroundStyle(palette.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(groupedLectures, id: \.key) { key, lectures in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(key)
                                .font(.headline)
                                .foregroundStyle(palette.primaryText)
                            ForEach(lectures) { lecture in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lecture.course?.name ?? "Course")
                                        .font(.subheadline.weight(.medium))
                                    Text(lecture.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryText)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(palette.surfaceBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(palette.panelBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(palette.neutralBorder.opacity(0.8), lineWidth: 1)
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var selectionDescription: String {
        switch selection {
        case .overview: return "A neutral overview of all upcoming lectures." 
        case .day: return "Focus on what's scheduled today." 
        case .week: return "Zoom into the current week's commitments." 
        }
    }

    private var groupedLectures: [(key: String, value: [Lecture])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        switch selection {
        case .overview:
            return Dictionary(grouping: lectures, by: { formatter.string(from: $0.date) })
                .sorted(by: { $0.key < $1.key })
        case .day:
            let today = Calendar.current.startOfDay(for: Date())
            let filtered = lectures.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
            return Dictionary(grouping: filtered, by: { formatter.string(from: $0.date) })
                .sorted(by: { $0.key < $1.key })
        case .week:
            let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date())
            let filtered = lectures.filter { lecture in
                guard let interval = weekInterval else { return false }
                return interval.contains(lecture.date)
            }
            return Dictionary(grouping: filtered, by: { formatter.string(from: $0.date) })
                .sorted(by: { $0.key < $1.key })
        }
    }
}

// MARK: - Custom Widget Info

struct HomeCustomWidgetInfo: Hashable {
    let id: UUID
    let title: String
    let detail: String
    let items: [String]

    static let sample = HomeCustomWidgetInfo(
        id: UUID(),
        title: "Focus list",
        detail: "Highlight tasks you want to keep top of mind.",
        items: ["Outline essay intro", "Review lab prep", "Email project partner"]
    )
}

// MARK: - Extensions

extension Array where Element == HomeWidgetItem {
    func uniqued() -> [HomeWidgetItem] {
        var seen: Set<HomeWidgetItem.ID> = []
        return self.filter { item in
            guard !seen.contains(item.id) else { return false }
            seen.insert(item.id)
            return true
        }
    }
}

// MARK: - End of File

