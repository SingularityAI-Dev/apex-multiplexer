import SwiftUI

struct MainContentView: View {
    @StateObject private var store    = TabStore()
    @StateObject private var appState = AppState()

    @State private var sidebarWidth: CGFloat = 240
    @State private var editorWidth:  CGFloat = 520
    @State private var showEditor    = false

    var body: some View {
        HStack(spacing: 0) {

            // ── 1. File Explorer ─────────────────────────────────────
            FileExplorerView()
                .frame(width: sidebarWidth)

            PaneDivider { delta in
                sidebarWidth = max(160, min(480, sidebarWidth + delta))
            }

            // ── 2. Code Editor (auto-shown when files are open) ──────
            if showEditor {
                CodeEditorPanel()
                    .frame(width: editorWidth)

                PaneDivider { delta in
                    editorWidth = max(280, min(1000, editorWidth + delta))
                }
            }

            // ── 3. Terminal Canvas ───────────────────────────────────
            VStack(spacing: 0) {
                topBar
                canvasArea
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .environmentObject(store)
        .environmentObject(appState)
        // Show/hide editor panel when files open / all closed
        .onChange(of: appState.openFiles.isEmpty) { isEmpty in
            withAnimation(.easeInOut(duration: 0.18)) { showEditor = !isEmpty }
        }
        // Binary / large file alert
        .alert(
            "Cannot Open File",
            isPresented: Binding(
                get:  { appState.lastError != nil },
                set:  { if !$0 { appState.lastError = nil } }
            ),
            presenting: appState.lastError
        ) { _ in
            Button("OK", role: .cancel) { appState.lastError = nil }
        } message: { err in
            Text((err.errorDescription ?? "") + "\n" + (err.recoverySuggestion ?? ""))
        }
        // Auto-save all modified files on quit
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
            for file in appState.openFiles where file.isModified {
                appState.saveFile(file.id)
            }
        }
    }

    // MARK: – Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            // Project tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(store.tabs) { tab in
                        TabItemView(tab: tab)
                    }
                }
            }

            // New tab
            Button(action: { store.addTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(white: 0.50))
                    .frame(width: 36, height: 38)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            // Add terminal pane to current tab
            if let tab = store.selectedTab {
                Button(action: { store.addTerminalPane(to: tab.id) }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Terminal")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color(white: 0.60))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.18)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            }
        }
        .frame(height: 38)
        .background(Color(red: 0.114, green: 0.114, blue: 0.118))
        .overlay(Rectangle().fill(Color(white: 0.08)).frame(height: 1), alignment: .bottom)
    }

    // MARK: – Canvas

    private var canvasArea: some View {
        Group {
            if let tab = store.selectedTab {
                TerminalCanvasView(tab: tab)
                    .coordinateSpace(name: "canvas")
            } else {
                Color(red: 0.068, green: 0.068, blue: 0.072)
                    .overlay(Text("No project tab selected")
                                .foregroundColor(Color(white: 0.25)))
            }
        }
    }
}

// MARK: - Resizable Panel Divider

struct PaneDivider: View {
    let onDrag: (CGFloat) -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isHovered
                      ? Color(white: 0.30)
                      : Color(white: 0.10))
                .frame(width: 1)
                .animation(.easeInOut(duration: 0.12), value: isHovered)

            // Wider invisible hit area for easier grabbing
            Rectangle()
                .fill(Color.clear)
                .frame(width: 10)
                .contentShape(Rectangle())
                .onHover { h in
                    isHovered = h
                    if h { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture()
                        .onChanged { v in onDrag(v.translation.width) }
                )
        }
    }
}



// MARK: - Project Tab Item

struct TabItemView: View {
    let tab: ProjectTab
    @EnvironmentObject var store: TabStore
    @State private var isEditing  = false
    @State private var tempName   = ""
    @State private var isHovered  = false
    @State private var showColorPicker = false

    var isSelected: Bool { store.selectedTabID == tab.id }

    var body: some View {
        HStack(spacing: 7) {
            // Color dot
            Circle()
                .fill(tab.color)
                .frame(width: 8, height: 8)
                .onTapGesture { showColorPicker.toggle() }
                .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                    TabColorPicker(tabID: tab.id, current: tab.color).environmentObject(store)
                }

            // Name
            if isEditing {
                TextField("", text: $tempName)
                    .onSubmit { commitRename() }
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(white: 0.90))
                    .frame(width: 90)
                    .onExitCommand { isEditing = false }
            } else {
                Text(tab.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(white: 0.92) : Color(white: 0.50))
                    .onTapGesture(count: 2) { tempName = tab.name; isEditing = true }
            }

            // Close / spacer
            if isHovered || isSelected {
                Button(action: { store.closeTab(tab.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(white: 0.48))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(
            ZStack(alignment: .bottom) {
                isSelected ? Color(white: 0.06) : Color.clear
                if isSelected {
                    Rectangle().fill(tab.color).frame(height: 2)
                }
            }
        )
        .onHover { isHovered = $0 }
        .onTapGesture { store.selectedTabID = tab.id }
        .contextMenu {
            Button("Rename") { tempName = tab.name; isEditing = true }
            Menu("Change Color") {
                ForEach(TabStore.presetColors, id: \.self) { c in
                    Button(colorLabel(c)) { store.updateTabColor(tabID: tab.id, to: c) }
                }
            }
            Divider()
            Button("Close Tab", role: .destructive) { store.closeTab(tab.id) }
        }
    }

    private func commitRename() {
        let t = tempName.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { store.renameTab(tabID: tab.id, to: t) }
        isEditing = false
    }

    private func colorLabel(_ c: Color) -> String {
        switch c {
        case .blue:   return "Blue"
        case .green:  return "Green"
        case .orange: return "Orange"
        case .purple: return "Purple"
        case .pink:   return "Pink"
        case .cyan:   return "Cyan"
        case .mint:   return "Mint"
        case .red:    return "Red"
        case .yellow: return "Yellow"
        default:      return "Custom"
        }
    }
}

// MARK: - Tab Color Picker Popover

struct TabColorPicker: View {
    let tabID:   UUID
    let current: Color
    @EnvironmentObject var store: TabStore
    @Environment(\.dismiss) private var dismiss

    let cols = Array(repeating: GridItem(.fixed(26), spacing: 8), count: 6)

    var body: some View {
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(TabStore.presetColors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.white, lineWidth: current == color ? 2 : 0))
                    .onTapGesture { store.updateTabColor(tabID: tabID, to: color); dismiss() }
            }
        }
        .padding(12)
    }
}
