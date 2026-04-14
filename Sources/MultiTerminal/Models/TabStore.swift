import SwiftUI
import Foundation

// MARK: - Terminal Pane Instance

struct TerminalPaneInstance: Identifiable, Equatable {
    let id = UUID()
    var name: String = "Terminal"
    var color: Color = .blue
    var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    var position: CGPoint = CGPoint(x: 40, y: 40)
    var size: CGSize = CGSize(width: 520, height: 340)
}

// MARK: - Project Tab

struct ProjectTab: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var color: Color
    var terminalPanes: [TerminalPaneInstance]
    var focusedPaneID: UUID?

    init(name: String, color: Color) {
        self.name = name
        self.color = color
        let initial = TerminalPaneInstance(name: "Main", color: color)
        self.terminalPanes = [initial]
        self.focusedPaneID = initial.id
    }
}

// MARK: - Tab Store

class TabStore: ObservableObject {
    @Published var tabs: [ProjectTab] = [
        ProjectTab(name: "Development", color: .blue)
    ]
    @Published var selectedTabID: UUID?

    let gridSize: CGFloat = 20
    static let presetColors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .cyan, .mint, .red, .yellow,
        Color(red: 0.2,  green: 0.6,  blue: 0.9),
        Color(red: 0.9,  green: 0.4,  blue: 0.2),
        Color(red: 0.55, green: 0.85, blue: 0.45)
    ]

    init() { selectedTabID = tabs.first?.id }

    var selectedTab: ProjectTab? { tabs.first { $0.id == selectedTabID } }

    // MARK: Tab Management

    func addTab() {
        let color = Self.presetColors.randomElement() ?? .blue
        let tab = ProjectTab(name: "New Project", color: color)
        tabs.append(tab)
        selectedTabID = tab.id
    }

    func closeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if selectedTabID == id { selectedTabID = tabs.last?.id }
    }

    func renameTab(tabID: UUID, to name: String) {
        guard let i = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[i].name = name
    }

    func updateTabColor(tabID: UUID, to color: Color) {
        guard let i = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[i].color = color
    }

    // MARK: Pane Management

    func addTerminalPane(to tabID: UUID) {
        guard let i = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let count = tabs[i].terminalPanes.count
        var pane = TerminalPaneInstance(
            name: "Terminal \(count + 1)",
            color: tabs[i].color
        )
        pane.position = CGPoint(x: 40 + CGFloat(count) * 44, y: 40 + CGFloat(count) * 44)
        tabs[i].terminalPanes.append(pane)
        tabs[i].focusedPaneID = pane.id
    }

    func renamePane(paneID: UUID, to name: String) {
        mutatePane(paneID) { $0.name = name }
    }

    func updatePaneColor(paneID: UUID, to color: Color) {
        mutatePane(paneID) { $0.color = color }
    }

    func updateDirectory(for paneID: UUID, to path: String) {
        mutatePane(paneID) { $0.currentDirectory = path }
    }

    func updatePosition(for paneID: UUID, to position: CGPoint) {
        let snapped = CGPoint(
            x: round(position.x / gridSize) * gridSize,
            y: round(position.y / gridSize) * gridSize
        )
        mutatePane(paneID) { $0.position = snapped }
    }

    func updateSize(for paneID: UUID, to size: CGSize) {
        let snapped = CGSize(
            width:  max(300, round(size.width  / gridSize) * gridSize),
            height: max(200, round(size.height / gridSize) * gridSize)
        )
        mutatePane(paneID) { $0.size = snapped }
    }

    func setFocus(paneID: UUID) {
        for i in 0..<tabs.count {
            if tabs[i].terminalPanes.contains(where: { $0.id == paneID }) {
                tabs[i].focusedPaneID = paneID
                // Notify terminal panes so the matching one can call makeFirstResponder.
                // This is needed because SwiftUI's NSHostingView does NOT automatically
                // grant first-responder status to embedded NSViewRepresentable subviews.
                NotificationCenter.default.post(name: .terminalShouldBecomeFirstResponder,
                                                object: paneID)
                return
            }
        }
    }

    func closePane(paneID: UUID) {
        for i in 0..<tabs.count {
            if let j = tabs[i].terminalPanes.firstIndex(where: { $0.id == paneID }) {
                tabs[i].terminalPanes.remove(at: j)
                if tabs[i].focusedPaneID == paneID {
                    tabs[i].focusedPaneID = tabs[i].terminalPanes.first?.id
                }
                return
            }
        }
    }

    // MARK: Private Helper

    private func mutatePane(_ paneID: UUID, _ mutation: (inout TerminalPaneInstance) -> Void) {
        for i in 0..<tabs.count {
            if let j = tabs[i].terminalPanes.firstIndex(where: { $0.id == paneID }) {
                mutation(&tabs[i].terminalPanes[j])
                return
            }
        }
    }
}
