import SwiftUI

// MARK: - File Tree Model

struct FileItem: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let isDirectory: Bool
    var name: String { url.lastPathComponent }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Explorer Root

struct FileExplorerView: View {
    @EnvironmentObject var store: TabStore
    @EnvironmentObject var appState: AppState

    @State private var rootItems: [FileItem] = []
    @State private var expandedPaths = Set<String>()
    @State private var hoveredPath: String? = nil

    // ── Derived from the focused terminal's CWD ──────────────────────
    var currentPath: String {
        guard let tab     = store.selectedTab,
              let focused = tab.focusedPaneID,
              let pane    = tab.terminalPanes.first(where: { $0.id == focused })
        else { return FileManager.default.homeDirectoryForCurrentUser.path }

        let raw = pane.currentDirectory
        if raw.isEmpty { return FileManager.default.homeDirectoryForCurrentUser.path }
        // TerminalPane.Coordinator already stores plain paths, but handle
        // legacy file:// URLs just in case.
        if raw.hasPrefix("file://"), let url = URL(string: raw) { return url.path }
        return raw
    }

    /// A stable string that changes whenever the focused pane or its directory changes.
    /// Used to gate explorer refresh so we don't reload unnecessarily.
    var explorerStateKey: String {
        guard let tab = store.selectedTab else { return "" }
        return "\(tab.id)-\(tab.focusedPaneID?.uuidString ?? "")-\(currentPath)"
    }

    var rootURL: URL { URL(fileURLWithPath: currentPath) }

    // ── Layout ───────────────────────────────────────────────────────
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            explorerHeader
            Divider().opacity(0.2)
            rootFolderRow
            fileTree
        }
        .background(Color(red: 0.114, green: 0.114, blue: 0.118))
        .onAppear { refresh() }
        // Refresh whenever the CWD, active pane, or tab changes
        .onChange(of: explorerStateKey) { _ in refresh() }
    }

    // MARK: Sub-views

    private var explorerHeader: some View {
        HStack(spacing: 6) {
            Text("EXPLORER")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.42))
                .kerning(1.4)
            Spacer()
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color(white: 0.42))
            }
            .buttonStyle(.plain)
            .help("Refresh Explorer")

            Button(action: { NSWorkspace.shared.open(rootURL) }) {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color(white: 0.42))
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 9)
    }

    private var rootFolderRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(white: 0.55))
            Text(rootURL.lastPathComponent.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(white: 0.70))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var fileTree: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rootItems) { item in
                    FileRowView(
                        item: item,
                        depth: 0,
                        expandedPaths: $expandedPaths,
                        hoveredPath: $hoveredPath
                    )
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: Data

    func refresh() {
        rootItems = loadChildren(of: rootURL)
    }

    func loadChildren(of url: URL) -> [FileItem] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { u -> FileItem? in
            let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return FileItem(url: u, isDirectory: isDir)
        }
        .sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.lowercased() < b.name.lowercased()
        }
    }
}

// MARK: - Single File / Folder Row

struct FileRowView: View {
    let item: FileItem
    let depth: Int
    @Binding var expandedPaths: Set<String>
    @Binding var hoveredPath: String?

    @EnvironmentObject var appState: AppState

    @State private var children: [FileItem] = []
    @State private var didLoad = false

    var isExpanded: Bool { expandedPaths.contains(item.id) }
    var isHovered:  Bool { hoveredPath == item.id }
    var icon: FileIcon { fileIcon(for: item.url, isDir: item.isDirectory) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowContent
            if isExpanded {
                ForEach(children) { child in
                    FileRowView(
                        item: child,
                        depth: depth + 1,
                        expandedPaths: $expandedPaths,
                        hoveredPath: $hoveredPath
                    )
                }
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            // Indentation
            Color.clear.frame(width: CGFloat(depth) * 12 + 6)

            // Disclosure chevron
            Group {
                if item.isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Color(white: 0.48))
                } else {
                    Color.clear
                }
            }
            .frame(width: 13)

            Spacer().frame(width: 5)

            // Icon
            Image(systemName: icon.symbol)
                .font(.system(size: 12))
                .foregroundColor(icon.color)
                .frame(width: 17)

            Spacer().frame(width: 5)

            // Name
            Text(item.name)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundColor(Color(white: 0.86))
                .lineLimit(1)

            Spacer(minLength: 4)
        }
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(isHovered ? Color(white: 0.20) : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
        .onHover { h in
            hoveredPath = h ? item.id : (hoveredPath == item.id ? nil : hoveredPath)
        }
        .onTapGesture {
            if item.isDirectory {
                withAnimation(.easeInOut(duration: 0.12)) {
                    if isExpanded {
                        expandedPaths.remove(item.id)
                    } else {
                        expandedPaths.insert(item.id)
                        if !didLoad { loadChildren() }
                    }
                }
            } else {
                appState.openFile(url: item.url)
            }
        }
    }

    private func loadChildren() {
        didLoad = true
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: item.url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        children = urls.compactMap { u -> FileItem? in
            let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return FileItem(url: u, isDirectory: isDir)
        }
        .sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.lowercased() < b.name.lowercased()
        }
    }
}
