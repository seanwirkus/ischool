import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

// MARK: - HomeDashboardModel

final class HomeDashboardModel: ObservableObject {
    @Published var modules: [DashboardModule]
    @Published var activeEditModuleID: DashboardModule.ID?
    @Published var isEditing: Bool
    @Published var dragState: DashboardDragState
    @Published var lastSyncedCourses: [Course] = []
    @Published var lastSyncedLectures: [Lecture] = []
    @Published var lastSyncedAssignments: [Assignment] = []
    @Published var lastSyncedQuickActions: [QuickActionItem] = []

    init(modules: [DashboardModule] = []) {
        self.modules = modules
        self.isEditing = false
        self.dragState = DashboardDragState()
    }

    func configureIfNeeded(
        courses: [Course],
        lectures: [Lecture],
        assignments: [Assignment],
        quickActions: [QuickActionItem]
    ) {
        if modules.isEmpty {
            modules = DashboardModule.defaultModules(
                courses: courses,
                lectures: lectures,
                assignments: assignments,
                quickActions: quickActions
            )
        }
        updateCourses(courses)
        updateLectures(lectures)
        updateAssignments(assignments)
        updateQuickActions(quickActions)
    }

    func updateCourses(_ courses: [Course]) {
        guard courses != lastSyncedCourses else { return }
        lastSyncedCourses = courses
        modules = modules.map { module in
            var updated = module
            updated.metadata.courses = courses
            return updated
        }
    }

    func updateLectures(_ lectures: [Lecture]) {
        guard lectures != lastSyncedLectures else { return }
        lastSyncedLectures = lectures
        modules = modules.map { module in
            var updated = module
            updated.metadata.lectures = lectures
            return updated
        }
    }

    func updateAssignments(_ assignments: [Assignment]) {
        guard assignments != lastSyncedAssignments else { return }
        lastSyncedAssignments = assignments
        modules = modules.map { module in
            var updated = module
            updated.metadata.assignments = assignments
            return updated
        }
    }

    func updateQuickActions(_ actions: [QuickActionItem]) {
        guard actions != lastSyncedQuickActions else { return }
        lastSyncedQuickActions = actions
        modules = modules.map { module in
            var updated = module
            updated.metadata.quickActions = actions
            return updated
        }
    }

    func toggleEditMode() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.2)) {
            isEditing.toggle()
            dragState = DashboardDragState()
        }
    }

    func moveModule(_ moduleID: DashboardModule.ID, to destinationID: DashboardModule.ID?) {
        guard let fromIndex = modules.firstIndex(where: { $0.id == moduleID }) else { return }
        var targetIndex = destinationID.flatMap { id in modules.firstIndex(where: { $0.id == id }) } ?? modules.count - 1
        if fromIndex == targetIndex { return }
        let module = modules.remove(at: fromIndex)
        if targetIndex >= modules.count {
            modules.append(module)
        } else {
            if fromIndex < targetIndex { targetIndex -= 1 }
            modules.insert(module, at: max(0, targetIndex))
        }
    }

    func updateModule(_ module: DashboardModule) {
        guard let index = modules.firstIndex(where: { $0.id == module.id }) else { return }
        modules[index] = module
    }

    func duplicateModule(_ module: DashboardModule) {
        var copy = module
        copy.id = UUID()
        copy.title = module.title.appending(" Copy")
        copy.metadata.isPinned = false
        modules.append(copy)
    }

    func removeModule(_ module: DashboardModule) {
        modules.removeAll { $0.id == module.id }
    }
}

// MARK: - EditableHomeDashboard

struct EditableHomeDashboard: View {
    @ObservedObject var model: HomeDashboardModel
    let layoutWidth: CGFloat
    let courses: [Course]
    let lectures: [Lecture]
    let assignments: [Assignment]
    let quickActions: [QuickActionItem]
    let onTriggerAction: (QuickActionItem) -> Void
    let onAddCourse: () -> Void
    let onSelectCourse: (Course) -> Void

    @State private var editingModule: DashboardModule?
    @Namespace private var dragNamespace

    var body: some View {
        VStack(spacing: 28) {
            dashboardHeader
            moduleGrid
        }
        .padding(.horizontal, horizontalPadding)
        .sheet(item: $editingModule) { module in
            DashboardModuleEditor(module: module) { updatedModule in
                editingModule = nil
                model.updateModule(updatedModule)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var horizontalPadding: CGFloat {
        layoutWidth > 1024 ? 64 : 24
    }

    private var dashboardHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Personalize your day")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                    Text("Drag to rearrange, tap to edit, and choose the modules that matter most to you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                editModeToggle
            }
            .padding(.top, 8)

            if model.isEditing {
                editingToolbox
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var editModeToggle: some View {
        Button {
            model.toggleEditMode()
        } label: {
            Label(model.isEditing ? "Done" : "Edit", systemImage: model.isEditing ? "checkmark.circle.fill" : "slider.horizontal.3")
                .font(.headline)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.platformElevatedBackground.opacity(0.8))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.isEditing ? "Stop Editing Home" : "Edit Home Layout")
    }

    private var editingToolbox: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(DashboardModule.Kind.allCases) { kind in
                    Button {
                        withAnimation(.spring) {
                            let newModule = DashboardModule(kind: kind)
                            model.modules.append(newModule)
                            editingModule = newModule
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: kind.defaultIcon)
                                .font(.title3.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(kind.defaultAccent.gradient.start)
                                )
                                .foregroundStyle(.primary.opacity(0.75))
                            Text(kind.displayTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 92)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.platformElevatedBackground.opacity(0.9))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(kind.displayTitle) Module")
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
        }
    }

    private var moduleGrid: some View {
        LazyVStack(spacing: 24) {
            ForEach(model.modules) { module in
                let binding = Binding(
                    get: { moduleByID(module.id) ?? module },
                    set: { updated in model.updateModule(updated) }
                )
                DashboardModuleCard(
                    module: binding,
                    isEditing: model.isEditing,
                    dragState: $model.dragState,
                    namespace: dragNamespace,
                    onMove: { draggedID, destinationID in
                        model.moveModule(draggedID, to: destinationID)
                    },
                    onEdit: { editingModule = moduleByID(module.id) },
                    onDuplicate: { moduleToDuplicate in model.duplicateModule(moduleToDuplicate) },
                    onDelete: { moduleToRemove in model.removeModule(moduleToRemove) },
                    contentBuilder: { module in
                        DashboardModuleContent(
                            module: module,
                            courses: courses,
                            lectures: lectures,
                            assignments: assignments,
                            quickActions: quickActions,
                            onTriggerAction: onTriggerAction,
                            onAddCourse: onAddCourse,
                            onSelectCourse: onSelectCourse
                        )
                    }
                )
                .id(module.id)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: model.modules)
    }

    private func moduleByID(_ id: DashboardModule.ID) -> DashboardModule? {
        model.modules.first(where: { $0.id == id })
    }
}

// MARK: - DashboardModuleCard

struct DashboardModuleCard<Content: View>: View {
    @Binding var module: DashboardModule
    let isEditing: Bool
    @Binding var dragState: DashboardDragState
    let namespace: Namespace.ID
    let onMove: (_ moduleID: DashboardModule.ID, _ destinationID: DashboardModule.ID?) -> Void
    let onEdit: () -> Void
    let onDuplicate: (DashboardModule) -> Void
    let onDelete: (DashboardModule) -> Void
    let contentBuilder: (DashboardModule) -> Content

    @State private var isPressed: Bool = false

    private var dragIdentifier: NSItemProvider {
        NSItemProvider(object: module.id.uuidString as NSString)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.06)
            contentBuilder(module)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(module.layout.contentInsets)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(module.accent.gradient.linearGradient)
                        .matchedGeometryEffect(id: module.id, in: namespace)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(module.accent.overlayGradient, lineWidth: 1.2)
                )
                .shadow(color: module.accent.shadow, radius: 24, x: 0, y: 18)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.platformElevatedBackground.opacity(0.85))
        )
        .overlay(alignment: .topTrailing) {
            if isEditing {
                editingControls
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
        )
        .padding(.horizontal, module.layout.horizontalPadding)
        .padding(.vertical, module.layout.verticalPadding)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.25), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.2) {
            guard isEditing else { return }
            isPressed = true
        } onPressingChanged: { pressing in
            if !pressing { isPressed = false }
        }
        .onDrag {
            dragState.draggingModuleID = module.id
            return dragIdentifier
        }
        .onDrop(of: [UTType.text], delegate: ModuleDropDelegate(
            currentModule: module,
            dragState: $dragState,
            onMove: onMove
        ))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(module.title)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: module.metadata.iconName)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(module.accent.thumbnailGradient)
                )
                .foregroundStyle(.primary.opacity(0.82))
            VStack(alignment: .leading, spacing: 4) {
                Text(module.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(module.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if isEditing {
                dragHandle
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.headline.weight(.medium))
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .accessibilityLabel("Reorder Module")
    }

    private var editingControls: some View {
        HStack(spacing: 8) {
            ControlButton(symbol: "slider.horizontal.3") { onEdit() }
            ControlButton(symbol: "plus.square.on.square") { onDuplicate(module) }
            ControlButton(symbol: "trash") { onDelete(module) }
        }
        .padding(12)
        .background(
            Capsule(style: .continuous)
                .fill(Color.platformElevatedBackground.opacity(0.95))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .padding(18)
    }
}

// MARK: - ControlButton

private struct ControlButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ModuleDropDelegate

struct ModuleDropDelegate: DropDelegate {
    let currentModule: DashboardModule
    @Binding var dragState: DashboardDragState
    let onMove: (_ moduleID: DashboardModule.ID, _ destinationID: DashboardModule.ID?) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        guard dragState.activeDropTarget != currentModule.id else { return }
        dragState.activeDropTarget = currentModule.id
        if let draggedID = dragState.draggingModuleID {
            onMove(draggedID, currentModule.id)
        }
    }

    func dropExited(info: DropInfo) {
        if dragState.activeDropTarget == currentModule.id {
            dragState.activeDropTarget = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        dragState.draggingModuleID = dragState.draggingModuleID ?? extractModuleID(from: info)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragState.activeDropTarget = nil
        dragState.draggingModuleID = nil
        guard let draggedID = extractModuleID(from: info) else { return false }
        onMove(draggedID, currentModule.id)
        return true
    }

    private func extractModuleID(from info: DropInfo) -> DashboardModule.ID? {
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return nil }
        var extractedID: DashboardModule.ID?
        let semaphore = DispatchSemaphore(value: 0)
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            defer { semaphore.signal() }
            if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                extractedID = UUID(uuidString: string)
            } else if let string = item as? String {
                extractedID = UUID(uuidString: string)
            }
        }
        semaphore.wait()
        return extractedID
    }
}

// MARK: - DashboardDragState

struct DashboardDragState: Equatable {
    var draggingModuleID: DashboardModule.ID?
    var activeDropTarget: DashboardModule.ID?
}

// MARK: - DashboardModuleContent

struct DashboardModuleContent: View {
    let module: DashboardModule
    let courses: [Course]
    let lectures: [Lecture]
    let assignments: [Assignment]
    let quickActions: [QuickActionItem]
    let onTriggerAction: (QuickActionItem) -> Void
    let onAddCourse: () -> Void
    let onSelectCourse: (Course) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: module.layout.verticalSpacing) {
            switch module.kind {
            case .welcome:
                welcomeModule
            case .quickActions:
                quickActionsModule
            case .coursesGrid:
                coursesModule
            case .assignmentsTimeline:
                assignmentsModule
            case .weeklySchedule:
                scheduleModule
            case .focusTasks:
                focusModule
            case .pinnedNotes:
                pinnedNotesModule
            case .upcomingTests:
                examsModule
            case .resourceShortcuts:
                resourcesModule
            case .customText:
                customTextModule
            }
        }
    }

    private var welcomeModule: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(module.metadata.customTitle ?? "Welcome back")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text(module.metadata.customMessage ?? "Here's a quick overview of everything happening across your courses today.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider().opacity(0.15)
            AdaptiveTagCloud(tags: module.metadata.highlightedTags)
        }
    }

    private var quickActionsModule: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(.secondary)
            DashboardQuickActionGrid(
                actions: quickActions,
                layoutStyle: module.metadata.quickActionLayout,
                onTriggerAction: onTriggerAction
            )
        }
    }

    private var coursesModule: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Courses")
                .font(.headline)
                .foregroundStyle(.secondary)
            DashboardCourseGrid(
                courses: courses,
                configuration: module.metadata.courseConfiguration,
                onAddCourse: onAddCourse,
                onSelectCourse: onSelectCourse
            )
        }
    }

    private var assignmentsModule: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(module.metadata.assignmentTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
            DashboardAssignmentTimeline(
                assignments: assignments,
                configuration: module.metadata.assignmentConfiguration,
                accent: module.accent
            )
        }
    }

    private var scheduleModule: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.headline)
                .foregroundStyle(.secondary)
            DashboardWeeklySchedule(
                lectures: lectures,
                configuration: module.metadata.scheduleConfiguration
            )
        }
    }

    private var focusModule: some View {
        DashboardFocusList(configuration: module.metadata.focusConfiguration)
    }

    private var pinnedNotesModule: some View {
        DashboardPinnedNotes(configuration: module.metadata.noteConfiguration)
    }

    private var examsModule: some View {
        DashboardExamTimeline(configuration: module.metadata.examConfiguration)
    }

    private var resourcesModule: some View {
        DashboardResourceGrid(configuration: module.metadata.resourceConfiguration)
    }

    private var customTextModule: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(module.metadata.customTitle ?? "Custom Module")
                .font(.headline)
            Text(module.metadata.customMessage ?? "Add your own notes or reminders here to keep track of personal goals.")
                .font(.body)
                .foregroundStyle(.primary.opacity(0.8))
        }
    }
}

// MARK: - AdaptiveTagCloud

struct AdaptiveTagCloud: View {
    let tags: [String]

    var body: some View {
        FlexibleView(
            data: tags,
            spacing: 8,
            alignment: .leading
        ) { tag in
            Text(tag)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
        }
    }
}

// MARK: - FlexibleView

struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    init(data: Data, spacing: CGFloat, alignment: HorizontalAlignment, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        let items = Array(data)
        return GeometryReader { geometry in
            generateContent(items: items, in: geometry)
        }
        .frame(minHeight: 24)
    }

    private func generateContent(items: [Data.Element], in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, element in
                content(element)
                    .padding(.all, 4)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height + spacing
                        }
                        let result = width
                        if index == items.count - 1 {
                            width = 0
                        } else {
                            width -= dimension.width + spacing
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if index == items.count - 1 {
                            height = 0
                        }
                        return result
                    }
            }
        }
    }
}


// MARK: - DashboardModule Definitions

struct DashboardModule: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Identifiable, Codable {
        case welcome
        case quickActions
        case coursesGrid
        case assignmentsTimeline
        case weeklySchedule
        case focusTasks
        case pinnedNotes
        case upcomingTests
        case resourceShortcuts
        case customText

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .welcome: return "Welcome"
            case .quickActions: return "Quick Actions"
            case .coursesGrid: return "Courses"
            case .assignmentsTimeline: return "Assignments"
            case .weeklySchedule: return "Week Schedule"
            case .focusTasks: return "Focus Tasks"
            case .pinnedNotes: return "Pinned Notes"
            case .upcomingTests: return "Upcoming Tests"
            case .resourceShortcuts: return "Resources"
            case .customText: return "Custom"
            }
        }

        var defaultIcon: String {
            switch self {
            case .welcome: return "sparkles"
            case .quickActions: return "bolt.fill"
            case .coursesGrid: return "rectangle.grid.2x2"
            case .assignmentsTimeline: return "checklist"
            case .weeklySchedule: return "calendar"
            case .focusTasks: return "target"
            case .pinnedNotes: return "pin"
            case .upcomingTests: return "graduationcap"
            case .resourceShortcuts: return "books.vertical"
            case .customText: return "text.alignleft"
            }
        }

        var defaultAccent: DashboardAccent {
            switch self {
            case .welcome: return .softSand
            case .quickActions: return .coolSlate
            case .coursesGrid: return .stoneBlue
            case .assignmentsTimeline: return .warmTaupe
            case .weeklySchedule: return .mistGreen
            case .focusTasks: return .slateBlue
            case .pinnedNotes: return .vintageRose
            case .upcomingTests: return .amberGlow
            case .resourceShortcuts: return .steelBlue
            case .customText: return .minimalGraphite
            }
        }
    }

    var id: UUID
    var kind: Kind
    var title: String
    var subtitle: String
    var accent: DashboardAccent
    var layout: DashboardModuleLayout
    var metadata: DashboardModuleMetadata

    init(id: UUID = UUID(), kind: Kind) {
        self.id = id
        self.kind = kind
        self.title = kind.displayTitle
        self.subtitle = ""
        self.accent = kind.defaultAccent
        self.layout = DashboardModuleLayout()
        self.metadata = DashboardModuleMetadata(iconName: kind.defaultIcon)
        configureDefaults()
    }

    private mutating func configureDefaults() {
        switch kind {
        case .welcome:
            subtitle = "Stay grounded and focused"
            metadata.customTitle = "Welcome back"
            metadata.customMessage = "Your dashboard adjusts as you work. Move cards, rename sections, and highlight the priorities that will keep you inspired and on-track."
            metadata.highlightedTags = DashboardTagLibrary.defaultHighlights
        case .quickActions:
            subtitle = "Capture ideas instantly"
            metadata.quickActionLayout = .adaptive
        case .coursesGrid:
            subtitle = "Keep tabs on every class"
            layout.contentInsets = EdgeInsets(top: 18, leading: 20, bottom: 22, trailing: 20)
            metadata.courseConfiguration = DashboardCourseConfiguration()
        case .assignmentsTimeline:
            subtitle = "Deadlines at a glance"
            metadata.assignmentConfiguration = DashboardAssignmentConfiguration()
        case .weeklySchedule:
            subtitle = "Upcoming sessions"
            layout.contentInsets = EdgeInsets(top: 22, leading: 20, bottom: 24, trailing: 20)
        case .focusTasks:
            subtitle = "Anchor tasks for today"
            metadata.focusConfiguration = DashboardFocusConfiguration.samples()
        case .pinnedNotes:
            subtitle = "Keep references handy"
            metadata.noteConfiguration = DashboardPinnedNoteConfiguration.samples()
        case .upcomingTests:
            subtitle = "Assessments"
            metadata.examConfiguration = DashboardExamConfiguration.samples()
        case .resourceShortcuts:
            subtitle = "Go-to materials"
            metadata.resourceConfiguration = DashboardResourceConfiguration.samples()
        case .customText:
            subtitle = "Add a personal reminder"
            metadata.customTitle = "Untitled section"
            metadata.customMessage = "Type anything you want to remember later."
        }
    }

    static func defaultModules(
        courses: [Course],
        lectures: [Lecture],
        assignments: [Assignment],
        quickActions: [QuickActionItem]
    ) -> [DashboardModule] {
        var modules: [DashboardModule] = []

        var welcome = DashboardModule(kind: .welcome)
        welcome.metadata.courses = courses
        welcome.metadata.highlightedTags = DashboardTagLibrary.defaultHighlights
        modules.append(welcome)

        var actions = DashboardModule(kind: .quickActions)
        actions.metadata.quickActions = quickActions
        modules.append(actions)

        var courseModule = DashboardModule(kind: .coursesGrid)
        courseModule.metadata.courses = courses
        modules.append(courseModule)

        var assignmentModule = DashboardModule(kind: .assignmentsTimeline)
        assignmentModule.metadata.assignments = assignments
        assignmentModule.metadata.assignmentConfiguration = DashboardAssignmentConfiguration()
        modules.append(assignmentModule)

        var scheduleModule = DashboardModule(kind: .weeklySchedule)
        scheduleModule.metadata.lectures = lectures
        modules.append(scheduleModule)

        var focusModule = DashboardModule(kind: .focusTasks)
        modules.append(focusModule)

        var noteModule = DashboardModule(kind: .pinnedNotes)
        modules.append(noteModule)

        var examModule = DashboardModule(kind: .upcomingTests)
        modules.append(examModule)

        var resourceModule = DashboardModule(kind: .resourceShortcuts)
        modules.append(resourceModule)

        var customModule = DashboardModule(kind: .customText)
        modules.append(customModule)

        return modules
    }
}

// MARK: - DashboardModuleLayout

struct DashboardModuleLayout: Hashable {
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var contentInsets: EdgeInsets
    var verticalSpacing: CGFloat

    init(
        horizontalPadding: CGFloat = 0,
        verticalPadding: CGFloat = 0,
        contentInsets: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 24, trailing: 20),
        verticalSpacing: CGFloat = 16
    ) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.contentInsets = contentInsets
        self.verticalSpacing = verticalSpacing
    }
}

// MARK: - DashboardModuleMetadata

struct DashboardModuleMetadata: Hashable {
    var courses: [Course]
    var lectures: [Lecture]
    var assignments: [Assignment]
    var quickActions: [QuickActionItem]
    var iconName: String
    var isPinned: Bool
    var highlightedTags: [String]
    var quickActionLayout: DashboardQuickActionLayout
    var courseConfiguration: DashboardCourseConfiguration
    var assignmentConfiguration: DashboardAssignmentConfiguration
    var scheduleConfiguration: DashboardScheduleConfiguration
    var focusConfiguration: DashboardFocusConfiguration
    var noteConfiguration: DashboardPinnedNoteConfiguration
    var examConfiguration: DashboardExamConfiguration
    var resourceConfiguration: DashboardResourceConfiguration
    var customTitle: String?
    var customMessage: String?
    var accentOverride: DashboardAccent?

    init(
        courses: [Course] = [],
        lectures: [Lecture] = [],
        assignments: [Assignment] = [],
        quickActions: [QuickActionItem] = [],
        iconName: String = "square.grid.2x2",
        isPinned: Bool = false,
        highlightedTags: [String] = [],
        quickActionLayout: DashboardQuickActionLayout = .adaptive,
        courseConfiguration: DashboardCourseConfiguration = DashboardCourseConfiguration(),
        assignmentConfiguration: DashboardAssignmentConfiguration = DashboardAssignmentConfiguration(),
        scheduleConfiguration: DashboardScheduleConfiguration = DashboardScheduleConfiguration(),
        focusConfiguration: DashboardFocusConfiguration = DashboardFocusConfiguration.empty(),
        noteConfiguration: DashboardPinnedNoteConfiguration = DashboardPinnedNoteConfiguration.empty(),
        examConfiguration: DashboardExamConfiguration = DashboardExamConfiguration.empty(),
        resourceConfiguration: DashboardResourceConfiguration = DashboardResourceConfiguration.empty(),
        customTitle: String? = nil,
        customMessage: String? = nil,
        accentOverride: DashboardAccent? = nil
    ) {
        self.courses = courses
        self.lectures = lectures
        self.assignments = assignments
        self.quickActions = quickActions
        self.iconName = iconName
        self.isPinned = isPinned
        self.highlightedTags = highlightedTags
        self.quickActionLayout = quickActionLayout
        self.courseConfiguration = courseConfiguration
        self.assignmentConfiguration = assignmentConfiguration
        self.scheduleConfiguration = scheduleConfiguration
        self.focusConfiguration = focusConfiguration
        self.noteConfiguration = noteConfiguration
        self.examConfiguration = examConfiguration
        self.resourceConfiguration = resourceConfiguration
        self.customTitle = customTitle
        self.customMessage = customMessage
        self.accentOverride = accentOverride
    }
}

// MARK: - DashboardAccent

struct DashboardAccent: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var gradient: DashboardGradient
    var overlayGradient: LinearGradient
    var thumbnailGradient: LinearGradient
    var shadow: Color

    init(
        id: UUID = UUID(),
        name: String,
        gradient: DashboardGradient,
        overlayGradient: LinearGradient,
        thumbnailGradient: LinearGradient,
        shadow: Color
    ) {
        self.id = id
        self.name = name
        self.gradient = gradient
        self.overlayGradient = overlayGradient
        self.thumbnailGradient = thumbnailGradient
        self.shadow = shadow
    }
}

struct DashboardGradient: Hashable, Codable {
    var start: Color
    var end: Color

    var linearGradient: LinearGradient {
        LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension DashboardAccent {
    static let softSand = DashboardAccent(
        name: "Soft Sand",
        gradient: DashboardGradient(
            start: Color(hex: "#F1EEE6") ?? Color(red: 0.95, green: 0.94, blue: 0.9),
            end: Color(hex: "#DED7CC") ?? Color(red: 0.87, green: 0.84, blue: 0.8)
        ),
        overlayGradient: LinearGradient(
            colors: [Color.white.opacity(0.3), Color.white.opacity(0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        thumbnailGradient: LinearGradient(
            colors: [Color(hex: "#E6DED1") ?? .init(white: 0.88), Color(hex: "#D1C6B8") ?? .init(white: 0.81)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        shadow: Color.black.opacity(0.08)
    )

    static let coolSlate = DashboardAccent(
        name: "Cool Slate",
        gradient: DashboardGradient(
            start: Color(hex: "#E5E8EC") ?? Color(red: 0.9, green: 0.91, blue: 0.93),
            end: Color(hex: "#D0D5DB") ?? Color(red: 0.82, green: 0.84, blue: 0.86)
        ),
        overlayGradient: LinearGradient(
            colors: [Color.white.opacity(0.25), Color.white.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        ),
        thumbnailGradient: LinearGradient(
            colors: [Color(hex: "#DCE0E6") ?? .init(white: 0.88), Color(hex: "#C4CAD3") ?? .init(white: 0.77)],
            startPoint: .top,
            endPoint: .bottom
        ),
        shadow: Color.black.opacity(0.07)
    )

    static let stoneBlue = DashboardAccent(
        name: "Stone Blue",
        gradient: DashboardGradient(
            start: Color(hex: "#E0E8F0") ?? Color(red: 0.88, green: 0.92, blue: 0.94),
            end: Color(hex: "#C4D2DD") ?? Color(red: 0.77, green: 0.82, blue: 0.87)
        ),
        overlayGradient: LinearGradient(
            colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
            startPoint: .leading,
            endPoint: .trailing
        ),
        thumbnailGradient: LinearGradient(
            colors: [Color(hex: "#CED9E4") ?? .init(white: 0.84), Color(hex: "#B2C2D0") ?? .init(white: 0.74)],
            startPoint: .leading,
            endPoint: .trailing
        ),
        shadow: Color.black.opacity(0.09)
    )

    static let warmTaupe = DashboardAccent(
        name: "Warm Taupe",
        gradient: DashboardGradient(
            start: Color(hex: "#F2E8E2") ?? Color(red: 0.94, green: 0.91, blue: 0.89),
            end: Color(hex: "#DCCFC7") ?? Color(red: 0.86, green: 0.81, blue: 0.78)
        ),
        overlayGradient: LinearGradient(
            colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        thumbnailGradient: LinearGradient(
            colors: [Color(hex: "#E8DDD6") ?? .init(white: 0.89), Color(hex: "#CCBFB5") ?? .init(white: 0.79)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        shadow: Color.black.opacity(0.08)
    )

    static let mistGreen = DashboardAccent(
        name: "Mist Green",
        gradient: DashboardGradient(
            start: Color(hex: "#E6EFE7") ?? Color(red: 0.9, green: 0.94, blue: 0.91),
            end: Color(hex: "#CBDDCF") ?? Color(red: 0.8, green: 0.87, blue: 0.81)
        ),
        overlayGradient: LinearGradient(
            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        ),
        thumbnailGradient: LinearGradient(
            colors: [Color(hex: "#D8E7DA") ?? .init(white: 0.86), Color(hex: "#B9CEBB") ?? .init(white: 0.73)],
            startPoint: .top,
            endPoint: .bottom
        ),
        shadow: Color.black.opacity(0.07)
    )

    static let slateBlue = DashboardAccent(
        name: "Slate Blue",
        gradient: DashboardGradient(
            start: Color(hex: "#E6E6F4") ?? Color(red: 0.9, green: 0.9, blue: 0.96),
            end: Color(hex: "#CACBE0") ?? Color(red: 0.79, green: 0.8, blue: 0.88)
        ),
        overlayGradient: LinearGradient(
            colors: [Color.white.opacity(0.25), Color.white.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        thumbnailGradient: LinearGradient(
            colors: [Color(hex: "#D4D4EA") ?? .init(white: 0.85), Color(hex: "#B9BCD5") ?? .init(white: 0.74)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        shadow: Color.black.opacity(0.09)
    )

    static let vintageRose = DashboardAccent(
        name: "Vintage Rose",
        gradient: DashboardGradient(
            start: Color(hex: "#F2E4E7") ?? Color(red: 0.95, green: 0.89, blue: 0.9),
            end: Color(hex: "#DEC8CC") ?? Color(red: 0.87, green: 0.78, blue: 0.8)
        ),
        overlayGradient: LinearGradient(
            colors: [Color.white.opacity(0.26), Color.white.opacity(0.03)],
            startPoint: .top,
            endPoint: .bottom
        ),
        thumbnailGradient: LinearGradient(
            colors: [Color(hex: "#E6D3D7") ?? .init(white: 0.89), Color(hex: "#CDB2B8") ?? .init(white: 0.77)],
            startPoint: .top,
            endPoint: .bottom
        ),
        shadow: Color.black.opacity(0.08)
    )

    static let amberGlow = DashboardAccent(
        name: "Amber Glow",
        gradient: DashboardGradient(
            start: Color(hex: "#F3EEE3") ?? Color(red: 0.95, green: 0.93, blue: 0.89),
            end: Color(hex: "#DFD2C0") ?? Color(red: 0.87, green: 0.82, blue: 0.75)
        ),
        overlayGradient: LinearGradient(
            colors: [Color.white.opacity(0.27), Color.white.opacity(0.03)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        thumbnailGradient: LinearGradient(
            colors: [Color(hex: "#E6DAC7") ?? .init(white: 0.9), Color(hex: "#CABDA6") ?? .init(white: 0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        shadow: Color.black.opacity(0.07)
    )

    static let steelBlue = DashboardAccent(
        name: "Steel Blue",
        gradient: DashboardGradient(
            start: Color(hex: "#E3E8EE") ?? Color(red: 0.89, green: 0.91, blue: 0.93),
            end: Color(hex: "#C8D1DA") ?? Color(red: 0.78, green: 0.82, blue: 0.85)
        ),
        overlayGradient: LinearGradient(
            colors: [Color.white.opacity(0.24), Color.white.opacity(0.04)],
            startPoint: .top,
            endPoint: .bottom
        ),
        thumbnailGradient: LinearGradient(
            colors: [Color(hex: "#D2D9E2") ?? .init(white: 0.83), Color(hex: "#B6C1CD") ?? .init(white: 0.73)],
            startPoint: .top,
            endPoint: .bottom
        ),
        shadow: Color.black.opacity(0.09)
    )

    static let minimalGraphite = DashboardAccent(
        name: "Minimal Graphite",
        gradient: DashboardGradient(
            start: Color(hex: "#F2F2F2") ?? Color(white: 0.95),
            end: Color(hex: "#D9D9D9") ?? Color(white: 0.85)
        ),
        overlayGradient: LinearGradient(
            colors: [Color.white.opacity(0.3), Color.white.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        ),
        thumbnailGradient: LinearGradient(
            colors: [Color(hex: "#E6E6E6") ?? .init(white: 0.9), Color(hex: "#CCCCCC") ?? .init(white: 0.8)],
            startPoint: .top,
            endPoint: .bottom
        ),
        shadow: Color.black.opacity(0.06)
    )

    static let palette: [DashboardAccent] = [
        .softSand,
        .coolSlate,
        .stoneBlue,
        .warmTaupe,
        .mistGreen,
        .slateBlue,
        .vintageRose,
        .amberGlow,
        .steelBlue,
        .minimalGraphite
    ]
}

// MARK: - Dashboard Tag Library

enum DashboardTagLibrary {
    static let defaultHighlights: [String] = [
        "Clarity",
        "Momentum",
        "Focus time",
        "Deep work",
        "Active learning",
        "Relationships",
        "Reflection",
        "Balance",
        "Health break",
        "Curiosity"
    ]

    static func curatedHighlights(for courses: [Course]) -> [String] {
        var tags = defaultHighlights
        for course in courses.prefix(6) {
            tags.append("\(course.name) goals")
        }
        return Array(Set(tags)).sorted()
    }
}

// MARK: - Supporting Layout Configurations

enum DashboardQuickActionLayout: String, CaseIterable, Identifiable, Codable {
    case singleRow
    case adaptive
    case stacked
    case compactList

    var id: String { rawValue }

    var label: String {
        switch self {
        case .singleRow: return "Single row"
        case .adaptive: return "Adaptive grid"
        case .stacked: return "Stacked buttons"
        case .compactList: return "Compact list"
        }
    }
}

struct DashboardCourseConfiguration: Hashable, Codable {
    var allowsInlineCreation: Bool
    var showsProgressIndicators: Bool
    var showsMeetings: Bool
    var showsUnits: Bool
    var highlightLimit: Int

    init(
        allowsInlineCreation: Bool = true,
        showsProgressIndicators: Bool = true,
        showsMeetings: Bool = true,
        showsUnits: Bool = false,
        highlightLimit: Int = 4
    ) {
        self.allowsInlineCreation = allowsInlineCreation
        self.showsProgressIndicators = showsProgressIndicators
        self.showsMeetings = showsMeetings
        self.showsUnits = showsUnits
        self.highlightLimit = highlightLimit
    }
}

struct DashboardAssignmentConfiguration: Hashable, Codable {
    var showCompleted: Bool
    var grouping: DashboardAssignmentGrouping
    var highlightPriority: AssignmentPriorityLevel
    var limit: Int

    init(
        showCompleted: Bool = false,
        grouping: DashboardAssignmentGrouping = .byDueDate,
        highlightPriority: AssignmentPriorityLevel = .high,
        limit: Int = 5
    ) {
        self.showCompleted = showCompleted
        self.grouping = grouping
        self.highlightPriority = highlightPriority
        self.limit = limit
    }
}

enum DashboardAssignmentGrouping: String, CaseIterable, Identifiable, Codable {
    case byCourse
    case byDueDate
    case byPriority

    var id: String { rawValue }

    var label: String {
        switch self {
        case .byCourse: return "Group by course"
        case .byDueDate: return "Group by due date"
        case .byPriority: return "Group by priority"
        }
    }
}

enum AssignmentPriorityLevel: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high
    case critical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    init(from priorityString: String) {
        switch priorityString.lowercased() {
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        case "critical": self = .critical
        default: self = .medium
        }
    }

    var sortWeight: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

struct DashboardScheduleConfiguration: Hashable, Codable {
    var includePastLectures: Bool
    var daysToDisplay: Int
    var showCourseBadges: Bool
    var showLocation: Bool

    init(
        includePastLectures: Bool = false,
        daysToDisplay: Int = 5,
        showCourseBadges: Bool = true,
        showLocation: Bool = true
    ) {
        self.includePastLectures = includePastLectures
        self.daysToDisplay = daysToDisplay
        self.showCourseBadges = showCourseBadges
        self.showLocation = showLocation
    }
}

struct DashboardFocusConfiguration: Hashable, Codable {
    struct FocusItem: Identifiable, Hashable, Codable {
        var id: UUID
        var title: String
        var detail: String
        var isCompleted: Bool
        var associatedCourse: String?
        var dueDate: Date?
        var priority: AssignmentPriorityLevel

        init(
            id: UUID = UUID(),
            title: String,
            detail: String,
            isCompleted: Bool = false,
            associatedCourse: String? = nil,
            dueDate: Date? = nil,
            priority: AssignmentPriorityLevel = .medium
        ) {
            self.id = id
            self.title = title
            self.detail = detail
            self.isCompleted = isCompleted
            self.associatedCourse = associatedCourse
            self.dueDate = dueDate
            self.priority = priority
        }
    }

    var focusItems: [FocusItem]
    var showsCompleted: Bool
    var allowsInlineCreation: Bool
    var highlightThreshold: Int

    init(
        focusItems: [FocusItem],
        showsCompleted: Bool,
        allowsInlineCreation: Bool,
        highlightThreshold: Int
    ) {
        self.focusItems = focusItems
        self.showsCompleted = showsCompleted
        self.allowsInlineCreation = allowsInlineCreation
        self.highlightThreshold = highlightThreshold
    }

    static func empty() -> DashboardFocusConfiguration {
        DashboardFocusConfiguration(
            focusItems: [],
            showsCompleted: true,
            allowsInlineCreation: true,
            highlightThreshold: 3
        )
    }

    static func samples() -> DashboardFocusConfiguration {
        DashboardFocusConfiguration(
            focusItems: [
                FocusItem(
                    title: "Review lecture notes",
                    detail: "Summarize the main arguments from today's seminar and flag open questions.",
                    associatedCourse: "Sociology 204",
                    priority: .high
                ),
                FocusItem(
                    title: "Draft research outline",
                    detail: "Map out the first three sections and list sources to revisit.",
                    associatedCourse: "Capstone Studio",
                    dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
                    priority: .critical
                ),
                FocusItem(
                    title: "Email study group",
                    detail: "Share meeting agenda and confirm availability.",
                    isCompleted: false,
                    associatedCourse: "CS Theory",
                    priority: .medium
                ),
                FocusItem(
                    title: "Take a break",
                    detail: "Schedule a 15-minute walk after finishing the reading summary.",
                    isCompleted: false,
                    associatedCourse: nil,
                    priority: .low
                )
            ],
            showsCompleted: true,
            allowsInlineCreation: true,
            highlightThreshold: 2
        )
    }
}

struct DashboardPinnedNoteConfiguration: Hashable, Codable {
    struct PinnedNote: Identifiable, Hashable, Codable {
        var id: UUID
        var title: String
        var body: String
        var courseName: String?
        var lastEdited: Date
        var color: ColorData

        init(
            id: UUID = UUID(),
            title: String,
            body: String,
            courseName: String? = nil,
            lastEdited: Date = Date(),
            color: ColorData = ColorData(color: .accentColor)
        ) {
            self.id = id
            self.title = title
            self.body = body
            self.courseName = courseName
            self.lastEdited = lastEdited
            self.color = color
        }
    }

    var notes: [PinnedNote]
    var allowsMarkdown: Bool
    var allowsReordering: Bool

    init(notes: [PinnedNote], allowsMarkdown: Bool, allowsReordering: Bool) {
        self.notes = notes
        self.allowsMarkdown = allowsMarkdown
        self.allowsReordering = allowsReordering
    }

    static func empty() -> DashboardPinnedNoteConfiguration {
        DashboardPinnedNoteConfiguration(notes: [], allowsMarkdown: true, allowsReordering: true)
    }

    static func samples() -> DashboardPinnedNoteConfiguration {
        DashboardPinnedNoteConfiguration(
            notes: [
                PinnedNote(
                    title: "Thesis feedback",
                    body: "• Refine problem statement\n• Add context on related work\n• Include timeline slide",
                    courseName: "Capstone Studio",
                    lastEdited: Date(),
                    color: ColorData(color: Color(hex: "#EADDD0") ?? .init(white: 0.9))
                ),
                PinnedNote(
                    title: "Lab reminders",
                    body: "Bring protective eyewear, confirm reagent order, backup data to shared drive.",
                    courseName: "BioChem Lab",
                    lastEdited: Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date(),
                    color: ColorData(color: Color(hex: "#D8E2DC") ?? .init(white: 0.85))
                ),
                PinnedNote(
                    title: "Personal mantra",
                    body: "Small steps every day compound. Remember to pause, reflect, and celebrate progress.",
                    courseName: nil,
                    lastEdited: Date(),
                    color: ColorData(color: Color(hex: "#F1E3E4") ?? .init(white: 0.92))
                )
            ],
            allowsMarkdown: true,
            allowsReordering: true
        )
    }
}

struct DashboardExamConfiguration: Hashable, Codable {
    struct Exam: Identifiable, Hashable, Codable {
        var id: UUID
        var courseName: String
        var title: String
        var location: String
        var date: Date
        var notes: String
        var preparationTasks: [String]

        init(
            id: UUID = UUID(),
            courseName: String,
            title: String,
            location: String,
            date: Date,
            notes: String,
            preparationTasks: [String]
        ) {
            self.id = id
            self.courseName = courseName
            self.title = title
            self.location = location
            self.date = date
            self.notes = notes
            self.preparationTasks = preparationTasks
        }
    }

    var exams: [Exam]
    var highlightSoonest: Bool
    var includeCompleted: Bool

    init(exams: [Exam], highlightSoonest: Bool, includeCompleted: Bool) {
        self.exams = exams
        self.highlightSoonest = highlightSoonest
        self.includeCompleted = includeCompleted
    }

    static func empty() -> DashboardExamConfiguration {
        DashboardExamConfiguration(exams: [], highlightSoonest: true, includeCompleted: false)
    }

    static func samples() -> DashboardExamConfiguration {
        DashboardExamConfiguration(
            exams: [
                Exam(
                    courseName: "Cognitive Science",
                    title: "Midterm Presentation",
                    location: "Room 312",
                    date: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date(),
                    notes: "Bring printed slides and demonstration kit.",
                    preparationTasks: [
                        "Refine slide deck",
                        "Schedule dry run",
                        "Print speaker notes"
                    ]
                ),
                Exam(
                    courseName: "Data Systems",
                    title: "Final Assessment",
                    location: "Online",
                    date: Calendar.current.date(byAdding: .day, value: 18, to: Date()) ?? Date(),
                    notes: "Closed notes, emphasis on storage engines.",
                    preparationTasks: [
                        "Revisit B-Tree notes",
                        "Solve practice problems",
                        "Meet with study partner"
                    ]
                ),
                Exam(
                    courseName: "Studio Art",
                    title: "Portfolio Review",
                    location: "Art Building",
                    date: Calendar.current.date(byAdding: .day, value: 25, to: Date()) ?? Date(),
                    notes: "Install pieces the evening before.",
                    preparationTasks: [
                        "Select four pieces",
                        "Prepare artist statement",
                        "Arrange transport"
                    ]
                )
            ],
            highlightSoonest: true,
            includeCompleted: false
        )
    }
}

struct DashboardResourceConfiguration: Hashable, Codable {
    struct Resource: Identifiable, Hashable, Codable {
        var id: UUID
        var title: String
        var subtitle: String
        var symbol: String
        var url: URL?
        var accentColor: ColorData
        var category: String

        init(
            id: UUID = UUID(),
            title: String,
            subtitle: String,
            symbol: String,
            url: URL? = nil,
            accentColor: ColorData,
            category: String
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.symbol = symbol
            self.url = url
            self.accentColor = accentColor
            self.category = category
        }
    }

    var resources: [Resource]
    var showsCategoryHeaders: Bool
    var allowsEditingLinks: Bool

    init(resources: [Resource], showsCategoryHeaders: Bool, allowsEditingLinks: Bool) {
        self.resources = resources
        self.showsCategoryHeaders = showsCategoryHeaders
        self.allowsEditingLinks = allowsEditingLinks
    }

    static func empty() -> DashboardResourceConfiguration {
        DashboardResourceConfiguration(resources: [], showsCategoryHeaders: true, allowsEditingLinks: true)
    }

    static func samples() -> DashboardResourceConfiguration {
        DashboardResourceConfiguration(
            resources: [
                Resource(
                    title: "Advisor Office",
                    subtitle: "Schedule a check-in before registration week.",
                    symbol: "person.crop.circle.badge.checkmark",
                    url: URL(string: "https://calendar.university.edu/advising"),
                    accentColor: ColorData(color: Color(hex: "#D9E4DD") ?? .init(white: 0.86)),
                    category: "People"
                ),
                Resource(
                    title: "Library Guide",
                    subtitle: "Research databases curated for your program.",
                    symbol: "books.vertical",
                    url: URL(string: "https://library.university.edu/guides"),
                    accentColor: ColorData(color: Color(hex: "#E0E7F1") ?? .init(white: 0.88)),
                    category: "Research"
                ),
                Resource(
                    title: "Wellness Center",
                    subtitle: "Schedule a mindfulness workshop.",
                    symbol: "heart.text.square",
                    url: URL(string: "https://wellness.university.edu"),
                    accentColor: ColorData(color: Color(hex: "#F4E6E0") ?? .init(white: 0.93)),
                    category: "Wellness"
                ),
                Resource(
                    title: "Career Hub",
                    subtitle: "Review resume resources and upcoming events.",
                    symbol: "briefcase",
                    url: URL(string: "https://careers.university.edu"),
                    accentColor: ColorData(color: Color(hex: "#EFE1D6") ?? .init(white: 0.92)),
                    category: "Career"
                ),
                Resource(
                    title: "Writing Center",
                    subtitle: "Book a feedback session for your draft.",
                    symbol: "pencil.and.outline",
                    url: URL(string: "https://writing.university.edu"),
                    accentColor: ColorData(color: Color(hex: "#F4E2EB") ?? .init(white: 0.94)),
                    category: "Writing"
                )
            ],
            showsCategoryHeaders: true,
            allowsEditingLinks: true
        )
    }
}

// MARK: - ColorData helper

struct ColorData: Hashable, Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: Color) {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
        #else
        self.red = 0.5
        self.green = 0.5
        self.blue = 0.5
        self.alpha = 1.0
        #endif
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue).opacity(alpha)
    }
}


// MARK: - Dashboard Quick Action Grid

struct DashboardQuickActionGrid: View {
    let actions: [QuickActionItem]
    let layoutStyle: DashboardQuickActionLayout
    let onTriggerAction: (QuickActionItem) -> Void

    var body: some View {
        switch layoutStyle {
        case .singleRow:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(actions) { item in
                        QuickAddButton(icon: item.icon, title: item.title) {
                            onTriggerAction(item)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        case .adaptive:
            ViewThatFits(in: .horizontal) {
                adaptiveGrid(columns: adaptiveColumns(minWidth: 180))
                adaptiveGrid(columns: adaptiveColumns(minWidth: 140))
                adaptiveGrid(columns: adaptiveColumns(minWidth: 120))
            }
        case .stacked:
            VStack(spacing: 10) {
                ForEach(actions) { item in
                    DashboardStackedActionRow(item: item) {
                        onTriggerAction(item)
                    }
                }
            }
        case .compactList:
            VStack(spacing: 4) {
                ForEach(actions) { item in
                    Button {
                        onTriggerAction(item)
                    } label: {
                        HStack {
                            Image(systemName: item.icon)
                                .font(.subheadline)
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func adaptiveColumns(minWidth: CGFloat) -> [GridItem] {
        [GridItem(.adaptive(minimum: minWidth), spacing: 14)]
    }

    @ViewBuilder
    private func adaptiveGrid(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(actions) { item in
                QuickAddButton(icon: item.icon, title: item.title) {
                    onTriggerAction(item)
                }
            }
        }
    }
}

private struct DashboardStackedActionRow: View {
    let item: QuickActionItem
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: item.icon)
                            .font(.headline)
                            .foregroundStyle(.primary.opacity(0.8))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Tap to begin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    private var iconBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08),
                Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Dashboard Course Grid

struct DashboardCourseGrid: View {
    let courses: [Course]
    let configuration: DashboardCourseConfiguration
    let onAddCourse: () -> Void
    let onSelectCourse: (Course) -> Void

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 220), spacing: 18)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if courses.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: gridColumns, spacing: 18) {
                    ForEach(courses.prefix(configuration.highlightLimit)) { course in
                        CourseChipView(course: course)
                            .onTapGesture {
                                onSelectCourse(course)
                            }
                    }
                    if configuration.allowsInlineCreation {
                        AddCourseChipView(action: onAddCourse)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No courses yet")
                .font(.headline)
            Text("Add your first course to start tracking lectures, notes, and assignments all in one place.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onAddCourse) {
                Label("Create a course", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

// MARK: - Dashboard Assignment Timeline

struct DashboardAssignmentTimeline: View {
    let assignments: [Assignment]
    let configuration: DashboardAssignmentConfiguration
    let accent: DashboardAccent

    private var filteredAssignments: [Assignment] {
        let sortedAssignments: [Assignment]
        switch configuration.grouping {
        case .byDueDate:
            sortedAssignments = assignments.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .byCourse:
            sortedAssignments = assignments.sorted { ($0.course?.name ?? "") < ($1.course?.name ?? "") }
        case .byPriority:
            sortedAssignments = assignments.sorted {
                AssignmentPriorityLevel(from: $0.priority).sortWeight > AssignmentPriorityLevel(from: $1.priority).sortWeight
            }
        }
        let limited = Array(sortedAssignments.prefix(configuration.limit))
        if configuration.showCompleted {
            return limited
        }
        return limited.filter { !$0.isCompleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if filteredAssignments.isEmpty {
                Text("No assignments to show")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredAssignments) { assignment in
                    AssignmentRow(assignment: assignment, accent: accent, highlightPriority: configuration.highlightPriority)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                }
            }
        }
    }

    struct AssignmentRow: View {
        let assignment: Assignment
        let accent: DashboardAccent
        let highlightPriority: AssignmentPriorityLevel

        var body: some View {
            HStack(alignment: .top, spacing: 14) {
                priorityIndicator
                VStack(alignment: .leading, spacing: 6) {
                    Text(assignment.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let dueDate = assignment.dueDate {
                        Text(dueDateFormatted(dueDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let description = assignment.assignmentDescription, !description.isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if let course = assignment.course {
                    Text(course.name)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.gradient.linearGradient.opacity(0.35))
                        )
                }
            }
        }

        private var priorityIndicator: some View {
            VStack {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(priorityColor.opacity(0.4))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }

        private var priorityColor: Color {
            switch AssignmentPriorityLevel(from: assignment.priority) {
            case .low: return Color(hex: "#C0CFB2") ?? .green.opacity(0.6)
            case .medium: return Color(hex: "#EAD7A1") ?? .yellow.opacity(0.7)
            case .high: return Color(hex: "#EBA6A9") ?? .orange.opacity(0.7)
            case .critical: return Color(hex: "#E26B6B") ?? .red.opacity(0.8)
            }
        }

        private func dueDateFormatted(_ date: Date) -> String {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "Due today"
            } else if calendar.isDateInTomorrow(date) {
                return "Due tomorrow"
            } else {
                return date.formatted(date: .abbreviated, time: .shortened)
            }
        }
    }
}

// MARK: - Dashboard Weekly Schedule

struct DashboardWeeklySchedule: View {
    let lectures: [Lecture]
    let configuration: DashboardScheduleConfiguration

    var body: some View {
        VStack(spacing: 16) {
            ForEach(upcomingDays, id: \.self) { day in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(day, format: .dateTime.weekday(.wide))
                            .font(.headline)
                        Spacer()
                    }
                    if let lectures = lecturesByDay[day], !lectures.isEmpty {
                        ForEach(lectures) { lecture in
                            LectureRow(lecture: lecture, configuration: configuration)
                        }
                    } else {
                        Text("No sessions")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)
                if day != upcomingDays.last {
                    Divider().opacity(0.1)
                }
            }
        }
    }

    private var upcomingDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0..<configuration.daysToDisplay).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    private var lecturesByDay: [Date: [Lecture]] {
        let calendar = Calendar.current
        let filtered = configuration.includePastLectures ? lectures : lectures.filter { $0.date >= Date() }
        return Dictionary(grouping: filtered) { lecture in
            calendar.startOfDay(for: lecture.date)
        }
    }

    struct LectureRow: View {
        let lecture: Lecture
        let configuration: DashboardScheduleConfiguration

        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lectureTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(lectureTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if configuration.showCourseBadges, let courseName = lecture.course?.name {
                    Text(courseName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
            }
            .padding(.vertical, 8)
        }

        private var lectureTitle: String {
            if let title = lecture.title, !title.isEmpty {
                return title
            }
            return "Session"
        }

        private var lectureTime: String {
            return lecture.date.formatted(date: .omitted, time: .shortened)
        }
    }
}

// MARK: - Dashboard Focus List

struct DashboardFocusList: View {
    @State private var items: [DashboardFocusConfiguration.FocusItem]
    @State private var newFocusTitle: String = ""
    @State private var newFocusDetail: String = ""
    let configuration: DashboardFocusConfiguration

    init(configuration: DashboardFocusConfiguration) {
        self.configuration = configuration
        _items = State(initialValue: configuration.focusItems)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if items.isEmpty {
                Text("Add a focus to keep momentum.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    FocusItemRow(item: item, toggle: toggle)
                }
            }

            if configuration.allowsInlineCreation {
                addNewFocus
            }
        }
    }

    private func toggle(_ item: DashboardFocusConfiguration.FocusItem) {
        if let index = items.firstIndex(of: item) {
            items[index].isCompleted.toggle()
        }
    }

    private var addNewFocus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add focus")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("Title", text: $newFocusTitle)
                .textFieldStyle(.roundedBorder)
            TextField("Detail", text: $newFocusDetail, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Button {
                guard !newFocusTitle.isEmpty else { return }
                let newItem = DashboardFocusConfiguration.FocusItem(
                    title: newFocusTitle,
                    detail: newFocusDetail,
                    priority: .medium
                )
                items.append(newItem)
                newFocusTitle = ""
                newFocusDetail = ""
            } label: {
                Label("Save", systemImage: "plus")
            }
        }
    }

    private struct FocusItemRow: View {
        var item: DashboardFocusConfiguration.FocusItem
        var toggle: (DashboardFocusConfiguration.FocusItem) -> Void

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggle(item)
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .strikethrough(item.isCompleted)
                    Text(item.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let course = item.associatedCourse {
                        Text(course)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
        }
    }
}

// MARK: - Dashboard Pinned Notes

struct DashboardPinnedNotes: View {
    @State private var notes: [DashboardPinnedNoteConfiguration.PinnedNote]
    let configuration: DashboardPinnedNoteConfiguration

    init(configuration: DashboardPinnedNoteConfiguration) {
        self.configuration = configuration
        _notes = State(initialValue: configuration.notes)
    }

    var body: some View {
        VStack(spacing: 16) {
            if notes.isEmpty {
                Text("Pin important reminders or ideas here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes) { note in
                    PinnedNoteCard(note: note)
                }
            }
        }
    }

    private struct PinnedNoteCard: View {
        let note: DashboardPinnedNoteConfiguration.PinnedNote

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(note.title)
                        .font(.headline)
                    Spacer()
                    Text(note.lastEdited, format: .relative(presentation: .numeric))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let course = note.courseName {
                    Text(course)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                Text(note.body)
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.85))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(note.color.swiftUIColor)
            )
        }
    }
}

// MARK: - Dashboard Exam Timeline

struct DashboardExamTimeline: View {
    @State private var exams: [DashboardExamConfiguration.Exam]
    let configuration: DashboardExamConfiguration

    init(configuration: DashboardExamConfiguration) {
        self.configuration = configuration
        _exams = State(initialValue: configuration.exams)
    }

    var body: some View {
        VStack(spacing: 18) {
            if exams.isEmpty {
                Text("Add upcoming assessments to stay prepared.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(exams) { exam in
                    ExamRow(exam: exam)
                }
            }
        }
    }

    private struct ExamRow: View {
        let exam: DashboardExamConfiguration.Exam

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exam.title)
                            .font(.headline)
                        Text(exam.courseName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(exam.date, format: .dateTime.month().day().hour().minute())
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                Text(exam.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !exam.preparationTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preparation")
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                        ForEach(exam.preparationTasks, id: \.self) { task in
                            HStack(alignment: .center, spacing: 8) {
                                Circle()
                                    .fill(Color.primary.opacity(0.15))
                                    .frame(width: 6, height: 6)
                                Text(task)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
        }
    }
}

// MARK: - Dashboard Resource Grid

struct DashboardResourceGrid: View {
    @State private var resources: [DashboardResourceConfiguration.Resource]
    let configuration: DashboardResourceConfiguration

    init(configuration: DashboardResourceConfiguration) {
        self.configuration = configuration
        _resources = State(initialValue: configuration.resources)
    }

    private var groupedResources: [String: [DashboardResourceConfiguration.Resource]] {
        Dictionary(grouping: resources) { $0.category }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groupedResources.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 12) {
                    if configuration.showsCategoryHeaders {
                        Text(key)
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                        ForEach(groupedResources[key] ?? []) { resource in
                            ResourceCard(resource: resource, allowsEditing: configuration.allowsEditingLinks)
                        }
                    }
                }
            }
        }
    }

    private struct ResourceCard: View {
        let resource: DashboardResourceConfiguration.Resource
        let allowsEditing: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(resource.accentColor.swiftUIColor)
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: resource.symbol)
                                .font(.title3)
                                .foregroundStyle(.primary.opacity(0.75))
                        )
                    Spacer()
                    if allowsEditing, let url = resource.url {
                        Menu {
                            Button("Open link") {
                                open(url: url)
                            }
                            Button("Copy link") {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = url.absoluteString
                                #endif
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
                Text(resource.title)
                    .font(.headline)
                Text(resource.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
        }

        private func open(url: URL) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
}

// MARK: - Dashboard Module Editor

struct DashboardModuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workingCopy: DashboardModule
    let onSave: (DashboardModule) -> Void

    init(module: DashboardModule, onSave: @escaping (DashboardModule) -> Void) {
        self._workingCopy = State(initialValue: module)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                accentSection
                layoutSection
                contentSection
            }
            .navigationTitle("Edit Module")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(workingCopy)
                        dismiss()
                    }
                }
            }
        }
    }

    private var generalSection: some View {
        Section("General") {
            TextField("Title", text: $workingCopy.title)
            TextField("Subtitle", text: $workingCopy.subtitle)
            TextField("Icon", text: $workingCopy.metadata.iconName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Toggle("Pin module", isOn: $workingCopy.metadata.isPinned)
            if workingCopy.kind == .customText {
                TextField("Headline", text: Binding(
                    get: { workingCopy.metadata.customTitle ?? "" },
                    set: { workingCopy.metadata.customTitle = $0 }
                ))
                TextField("Message", text: Binding(
                    get: { workingCopy.metadata.customMessage ?? "" },
                    set: { workingCopy.metadata.customMessage = $0 }
                ), axis: .vertical)
            }
        }
    }

    private var accentSection: some View {
        Section("Accent") {
            Picker("Palette", selection: Binding(
                get: { workingCopy.metadata.accentOverride?.id ?? workingCopy.accent.id },
                set: { id in
                    if let accent = DashboardAccent.palette.first(where: { $0.id == id }) {
                        workingCopy.accent = accent
                        workingCopy.metadata.accentOverride = accent
                    }
                }
            )) {
                ForEach(DashboardAccent.palette) { accent in
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(accent.gradient.linearGradient)
                            .frame(width: 38, height: 20)
                        Text(accent.name)
                    }
                    .tag(accent.id)
                }
            }
            .pickerStyle(.navigationLink)

            Toggle("Use neutral overlay", isOn: Binding(
                get: { workingCopy.metadata.accentOverride != nil },
                set: { isEnabled in
                    workingCopy.metadata.accentOverride = isEnabled ? workingCopy.accent : nil
                }
            ))
        }
    }

    private var layoutSection: some View {
        Section("Layout") {
            Stepper(value: $workingCopy.layout.horizontalPadding, in: 0...40, step: 2) {
                HStack {
                    Text("Horizontal padding")
                    Spacer()
                    Text("\(Int(workingCopy.layout.horizontalPadding))")
                        .foregroundStyle(.secondary)
                }
            }
            Stepper(value: $workingCopy.layout.verticalPadding, in: 0...40, step: 2) {
                HStack {
                    Text("Vertical padding")
                    Spacer()
                    Text("\(Int(workingCopy.layout.verticalPadding))")
                        .foregroundStyle(.secondary)
                }
            }
            Stepper(value: Binding(
                get: { Double(workingCopy.layout.verticalSpacing) },
                set: { workingCopy.layout.verticalSpacing = CGFloat($0) }
            ), in: 8...36, step: 2) {
                HStack {
                    Text("Vertical spacing")
                    Spacer()
                    Text("\(Int(workingCopy.layout.verticalSpacing))")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch workingCopy.kind {
        case .quickActions:
            Section("Quick actions") {
                Picker("Layout", selection: $workingCopy.metadata.quickActionLayout) {
                    ForEach(DashboardQuickActionLayout.allCases) { layout in
                        Text(layout.label).tag(layout)
                    }
                }
            }
        case .coursesGrid:
            Section("Courses") {
                Toggle("Allow inline creation", isOn: $workingCopy.metadata.courseConfiguration.allowsInlineCreation)
                Toggle("Show progress", isOn: $workingCopy.metadata.courseConfiguration.showsProgressIndicators)
                Toggle("Show meetings", isOn: $workingCopy.metadata.courseConfiguration.showsMeetings)
                Stepper(value: $workingCopy.metadata.courseConfiguration.highlightLimit, in: 1...12) {
                    HStack {
                        Text("Highlight count")
                        Spacer()
                        Text("\(workingCopy.metadata.courseConfiguration.highlightLimit)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .assignmentsTimeline:
            Section("Assignments") {
                Toggle("Show completed", isOn: $workingCopy.metadata.assignmentConfiguration.showCompleted)
                Picker("Grouping", selection: $workingCopy.metadata.assignmentConfiguration.grouping) {
                    ForEach(DashboardAssignmentGrouping.allCases) { grouping in
                        Text(grouping.label).tag(grouping)
                    }
                }
                Picker("Highlight priority", selection: $workingCopy.metadata.assignmentConfiguration.highlightPriority) {
                    ForEach(AssignmentPriorityLevel.allCases) { priority in
                        Text(priority.label).tag(priority)
                    }
                }
                Stepper(value: $workingCopy.metadata.assignmentConfiguration.limit, in: 1...20) {
                    HStack {
                        Text("Visible assignments")
                        Spacer()
                        Text("\(workingCopy.metadata.assignmentConfiguration.limit)")
                    }
                }
            }
        case .weeklySchedule:
            Section("Schedule") {
                Toggle("Include past lectures", isOn: $workingCopy.metadata.scheduleConfiguration.includePastLectures)
                Stepper(value: $workingCopy.metadata.scheduleConfiguration.daysToDisplay, in: 1...10) {
                    HStack {
                        Text("Days to display")
                        Spacer()
                        Text("\(workingCopy.metadata.scheduleConfiguration.daysToDisplay)")
                    }
                }
                Toggle("Show course badges", isOn: $workingCopy.metadata.scheduleConfiguration.showCourseBadges)
                Toggle("Show location", isOn: $workingCopy.metadata.scheduleConfiguration.showLocation)
            }
        case .focusTasks:
            Section("Focus") {
                Toggle("Show completed", isOn: $workingCopy.metadata.focusConfiguration.showsCompleted)
                Toggle("Allow inline creation", isOn: $workingCopy.metadata.focusConfiguration.allowsInlineCreation)
                Stepper(value: $workingCopy.metadata.focusConfiguration.highlightThreshold, in: 1...10) {
                    HStack {
                        Text("Highlight threshold")
                        Spacer()
                        Text("\(workingCopy.metadata.focusConfiguration.highlightThreshold)")
                    }
                }
            }
        case .pinnedNotes:
            Section("Notes") {
                Toggle("Allow markdown", isOn: $workingCopy.metadata.noteConfiguration.allowsMarkdown)
                Toggle("Allow reordering", isOn: $workingCopy.metadata.noteConfiguration.allowsReordering)
            }
        case .upcomingTests:
            Section("Exams") {
                Toggle("Highlight soonest", isOn: $workingCopy.metadata.examConfiguration.highlightSoonest)
                Toggle("Include completed", isOn: $workingCopy.metadata.examConfiguration.includeCompleted)
            }
        case .resourceShortcuts:
            Section("Resources") {
                Toggle("Show categories", isOn: $workingCopy.metadata.resourceConfiguration.showsCategoryHeaders)
                Toggle("Allow link editing", isOn: $workingCopy.metadata.resourceConfiguration.allowsEditingLinks)
            }
        case .welcome, .customText:
            EmptyView()
        }
    }
}

