import SwiftUI

// MARK: - Code Editor Panel

struct CodeEditorPanel: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.openFiles.isEmpty {
                EditorEmptyState()
            } else {
                EditorTabBar()
                Divider().opacity(0.25)
                // ONE persistent editor body — fileID change triggers Monaco content swap
                if let file = appState.activeFile {
                    EditorBody(file: file)
                } else {
                    EditorEmptyState()
                }
            }
        }
        .background(Color(red: 0.094, green: 0.094, blue: 0.098))
    }
}

// MARK: - Tab Bar

struct EditorTabBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(appState.openFiles) { file in
                    EditorTab(file: file)
                }
            }
        }
        .frame(height: 36)
        .background(Color(red: 0.114, green: 0.114, blue: 0.118))
    }
}

// MARK: - Single Tab

struct EditorTab: View {
    let file: OpenFile
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var isActive: Bool { appState.activeFileID == file.id }
    var icon: FileIcon { fileIcon(for: file.url, isDir: false) }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon.symbol)
                .font(.system(size: 11))
                .foregroundColor(icon.color)

            Text(file.name)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .foregroundColor(isActive ? Color(white: 0.92) : Color(white: 0.52))
                .lineLimit(1)

            // Dot = unsaved, X = close (on hover / active)
            ZStack {
                if file.isModified {
                    Circle()
                        .fill(Color(white: 0.55))
                        .frame(width: 6, height: 6)
                } else {
                    Button(action: { appState.closeFile(file.id) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(white: 0.50))
                    }
                    .buttonStyle(.plain)
                    .opacity((isHovered || isActive) ? 1 : 0)
                }
            }
            .frame(width: 14)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(
            ZStack(alignment: .top) {
                (isActive ? Color(red: 0.094, green: 0.094, blue: 0.098) : Color.clear)
                if isActive {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 1)
                }
            }
        )
        .onHover { isHovered = $0 }
        .onTapGesture { appState.activeFileID = file.id }
    }
}

// MARK: - Editor Body

struct EditorBody: View {
    let file: OpenFile
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.20)

            MonacoEditorView(
                fileID:   file.id,
                content:  file.content,
                language: monacoLanguage(for: file.ext),
                onContentChange: { new in
                    appState.updateContent(id: file.id, content: new)
                }
            )
        }
        // Cmd+S to save
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in }
        .background(Color(red: 0.094, green: 0.094, blue: 0.098))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            // Breadcrumb
            let icon = fileIcon(for: file.url, isDir: false)
            Image(systemName: icon.symbol)
                .font(.system(size: 10))
                .foregroundColor(icon.color)

            Text(file.url.deletingLastPathComponent().lastPathComponent)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.40))

            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Color(white: 0.28))

            Text(file.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(white: 0.68))

            if file.isModified {
                Circle()
                    .fill(Color(white: 0.50))
                    .frame(width: 5, height: 5)
            }

            Spacer()

            if file.isModified {
                Button(action: { appState.saveFile(file.id) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Save")
                            .foregroundColor(Color(white: 0.72))
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color(red: 0.114, green: 0.114, blue: 0.118))
    }
}

// MARK: - Empty State

struct EditorEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundColor(Color(white: 0.20))
            Text("Open a file from the explorer")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(white: 0.28))
            Text("Click any file in the sidebar")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.20))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.094, green: 0.094, blue: 0.098))
    }
}
