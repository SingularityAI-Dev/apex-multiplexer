import SwiftUI
import SwiftTerm

// MARK: - Notification for terminal focus

extension Notification.Name {
    static let terminalShouldBecomeFirstResponder =
        Notification.Name("terminalShouldBecomeFirstResponder")
}

// MARK: - Shared ZDOTDIR (once per app launch)

private let sharedZdotdir: String = {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("multi-term-zsh", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir,
                                              withIntermediateDirectories: true)
    func write(_ text: String, name: String) {
        try? text.write(to: dir.appendingPathComponent(name),
                        atomically: true, encoding: .utf8)
    }
    write("[[ -f \"$HOME/.zshenv\" ]] && builtin source \"$HOME/.zshenv\"",
          name: ".zshenv")
    write("[[ -f \"$HOME/.zprofile\" ]] && builtin source \"$HOME/.zprofile\"",
          name: ".zprofile")
    write("""
        if [[ -z "$_MULTITERM_LOADED" ]]; then
            export _MULTITERM_LOADED=1
            unset ZDOTDIR
            [[ -f "$HOME/.zshrc" ]] && builtin source "$HOME/.zshrc"
        fi
        __mt_report_cwd() { printf '\\e]7;file://%s\\a' "$PWD"; }
        autoload -Uz add-zsh-hook 2>/dev/null
        add-zsh-hook chpwd __mt_report_cwd
        __mt_report_cwd
        """, name: ".zshrc")
    write("[[ -f \"$HOME/.zlogin\" ]] && builtin source \"$HOME/.zlogin\"",
          name: ".zlogin")
    return dir.path
}()

// MARK: - Constants

private let kTitleH:  CGFloat = 30
private let kStripH:  CGFloat = 16

// ============================================================================
// MARK: - AppKit Terminal Canvas
// ============================================================================
//
// Architecture: ONE NSViewRepresentable wraps ONE AppKit NSView ("canvas").
// Inside the canvas, each terminal pane is a plain NSView (TerminalPaneView)
// containing a title bar, a LocalProcessTerminalView, and a resize strip.
//
// Why: SwiftUI's NSHostingView intercepts ALL events via hitTest and never
// forwards them to embedded NSViewRepresentable children.  Using .offset()
// applies a CALayer transform, so AppKit's hitTest (which checks frames,
// not transforms) never finds the terminal.  By hosting everything in a
// single AppKit view tree, hitTest → mouseDown → makeFirstResponder → keyDown
// works naturally.
// ============================================================================

// MARK: - Terminal Pane View (AppKit)

/// Pure AppKit view that contains a title bar, terminal, and resize strip.
/// Positioned by setting its `frame` directly — no SwiftUI transforms.
class TerminalPaneView: NSView, LocalProcessTerminalViewDelegate {
    let paneID: UUID
    let terminal: LocalProcessTerminalView
    private let titleBar: NSView
    private let titleLabel: NSTextField
    private var paneColor: NSColor
    weak var store: TabStore?

    // Dragging state
    private var isDragging = false
    private var dragOrigin = CGPoint.zero

    // Resizing state
    private var isResizing = false
    private var resizeOrigin = CGSize.zero
    private var resizeMouseOrigin = CGPoint.zero

    init(paneID: UUID, color: NSColor, name: String, origin: CGPoint, size: CGSize, store: TabStore) {
        self.paneID = paneID
        self.paneColor = color
        self.store = store

        // Terminal
        let termFrame = NSRect(x: 0, y: kStripH,
                               width: size.width,
                               height: size.height - kTitleH - kStripH)
        terminal = LocalProcessTerminalView(frame: termFrame)
        terminal.autoresizingMask = [.width, .height]
        terminal.wantsLayer = true
        terminal.layer?.contentsFormat = .RGBA8Uint
        terminal.configureNativeColors()
        terminal.optionAsMetaKey = true

        // Title bar
        titleBar = NSView(frame: NSRect(x: 0, y: size.height - kTitleH,
                                        width: size.width, height: kTitleH))
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = color.withAlphaComponent(0.70).cgColor
        titleBar.autoresizingMask = [.width, .minYMargin]

        // Title label
        titleLabel = NSTextField(labelWithString: name)
        titleLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 10, y: 6, width: size.width - 20, height: 18)
        titleLabel.autoresizingMask = [.width]

        super.init(frame: NSRect(origin: origin, size: size))
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = color.withAlphaComponent(0.3).cgColor

        // Assemble
        titleBar.addSubview(titleLabel)
        addSubview(terminal)
        addSubview(titleBar)

        // Right-click context menu on the title bar
        titleBar.menu = buildContextMenu()

        // Set up terminal delegate
        terminal.processDelegate = self

        // Start shell
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("ZDOTDIR=\(sharedZdotdir)")
        terminal.startProcess(executable: "/bin/zsh", args: ["--login"],
                              environment: env, execName: nil, currentDirectory: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: AppKit Event Handling

    // Determine the zone of a mouse click: title bar, resize strip, or terminal body.
    private enum HitZone { case titleBar, resizeStrip, terminal }

    private func zone(for event: NSEvent) -> HitZone {
        let local = convert(event.locationInWindow, from: nil)
        if local.y >= bounds.height - kTitleH { return .titleBar }
        if local.y <= kStripH { return .resizeStrip }
        return .terminal
    }

    override func mouseDown(with event: NSEvent) {
        let z = zone(for: event)

        // ALL clicks on this pane update focus — so the file explorer,
        // title bar highlight, etc. always track the active terminal.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.store?.setFocus(paneID: self.paneID)
        }

        switch z {
        case .titleBar:
            if event.clickCount == 2 {
                // Double-click title bar → rename
                promptRename()
                return
            }
            isDragging = true
            dragOrigin = frame.origin
            // Bring to front
            superview?.addSubview(self)
            // Also give keyboard focus to the terminal
            window?.makeFirstResponder(terminal)
        case .resizeStrip:
            isResizing = true
            resizeOrigin = frame.size
            resizeMouseOrigin = convert(event.locationInWindow, from: nil)
        case .terminal:
            // CRITICAL: make the terminal first responder so it gets keyDown
            window?.makeFirstResponder(terminal)
            // Forward the click to the terminal for text selection etc.
            terminal.mouseDown(with: event)
            return
        }
    }

    // MARK: Context Menu

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu(title: "Pane")

        // Rename
        let renameItem = NSMenuItem(title: "Rename…", action: #selector(menuRename), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

        // Color submenu
        let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        let colorSub = NSMenu(title: "Color")
        let presetColors: [(String, NSColor)] = [
            ("Blue",   .systemBlue),   ("Green",  .systemGreen),
            ("Orange", .systemOrange), ("Purple", .systemPurple),
            ("Pink",   .systemPink),   ("Cyan",   .systemTeal),
            ("Mint",   .systemMint),   ("Red",    .systemRed),
            ("Yellow", .systemYellow)
        ]
        for (name, color) in presetColors {
            let item = NSMenuItem(title: name, action: #selector(menuSetColor(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = color
            // Color swatch
            let swatch = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
                color.setFill()
                NSBezierPath(ovalIn: rect).fill()
                return true
            }
            item.image = swatch
            colorSub.addItem(item)
        }
        colorItem.submenu = colorSub
        menu.addItem(colorItem)

        menu.addItem(.separator())

        // Close
        let closeItem = NSMenuItem(title: "Close Terminal", action: #selector(menuClose), keyEquivalent: "")
        closeItem.target = self
        menu.addItem(closeItem)

        return menu
    }

    @objc private func menuRename() { promptRename() }

    @objc private func menuSetColor(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? NSColor else { return }
        store?.updatePaneColor(paneID: paneID, to: Color(color))
    }

    @objc private func menuClose() {
        store?.closePane(paneID: paneID)
    }

    private func promptRename() {
        let alert = NSAlert()
        alert.messageText = "Rename Terminal"
        alert.informativeText = "Enter a new name for this terminal pane:"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.stringValue = titleLabel.stringValue
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !newName.isEmpty {
                store?.renamePane(paneID: paneID, to: newName)
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isDragging {
            let delta = CGSize(width: event.deltaX, height: -event.deltaY)
            frame.origin.x += delta.width
            frame.origin.y -= delta.height
        } else if isResizing {
            let local = convert(event.locationInWindow, from: nil)
            let dx = local.x - resizeMouseOrigin.x
            let dy = local.y - resizeMouseOrigin.y
            let newW = max(300, resizeOrigin.width + dx)
            let newH = max(200, resizeOrigin.height - dy)
            let newY = frame.origin.y + frame.size.height - newH
            frame = NSRect(x: frame.origin.x, y: newY, width: newW, height: newH)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            // Commit to store
            store?.updatePosition(for: paneID, to: CGPoint(x: frame.origin.x, y: frame.origin.y))
        }
        if isResizing {
            isResizing = false
            store?.updateSize(for: paneID, to: frame.size)
        }
    }

    // MARK: Update from store

    func updateFromStore(_ pane: TerminalPaneInstance, isFocused: Bool) {
        // Update position/size only if not actively dragging/resizing
        if !isDragging && !isResizing {
            frame = NSRect(origin: pane.position, size: pane.size)
        }
        // Update title
        titleLabel.stringValue = pane.name
        // Update color
        let nsColor = NSColor(pane.color)
        paneColor = nsColor
        titleBar.layer?.backgroundColor = nsColor.withAlphaComponent(isFocused ? 0.80 : 0.45).cgColor
        layer?.borderColor = nsColor.withAlphaComponent(isFocused ? 0.85 : 0.22).cgColor
        layer?.borderWidth = isFocused ? 2 : 1
    }

    // MARK: LocalProcessTerminalViewDelegate

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        print("[MT] processTerminated pane=\(paneID) exit=\(String(describing: exitCode))")
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let raw = directory, !raw.isEmpty else { return }
        let path: String
        if let url = URL(string: raw), url.scheme == "file" {
            path = url.path
        } else {
            path = raw
        }
        guard !path.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.store?.updateDirectory(for: self.paneID, to: path)
        }
    }
}

// MARK: - Canvas NSView

/// The root AppKit view that hosts all TerminalPaneViews as subviews.
class CanvasNSView: NSView {
    var paneViews: [UUID: TerminalPaneView] = [:]
    weak var store: TabStore?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.068, green: 0.068, blue: 0.072, alpha: 1).cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }  // top-left origin like SwiftUI

    func sync(with tab: ProjectTab) {
        let existingIDs = Set(paneViews.keys)
        let desiredIDs = Set(tab.terminalPanes.map(\.id))

        // Remove stale panes
        for id in existingIDs.subtracting(desiredIDs) {
            paneViews[id]?.removeFromSuperview()
            paneViews.removeValue(forKey: id)
        }

        // Add new panes
        for pane in tab.terminalPanes where !existingIDs.contains(pane.id) {
            let pv = TerminalPaneView(
                paneID: pane.id,
                color: NSColor(pane.color),
                name: pane.name,
                origin: pane.position,
                size: pane.size,
                store: store!
            )
            addSubview(pv)
            paneViews[pane.id] = pv
        }

        // Update existing panes
        for pane in tab.terminalPanes {
            let isFocused = tab.focusedPaneID == pane.id
            paneViews[pane.id]?.updateFromStore(pane, isFocused: isFocused)
        }
    }
}

// MARK: - SwiftUI Bridge (NSViewRepresentable)

struct AppKitTerminalCanvas: NSViewRepresentable {
    var tab: ProjectTab
    @EnvironmentObject var store: TabStore

    func makeNSView(context: Context) -> CanvasNSView {
        let canvas = CanvasNSView(frame: .zero)
        canvas.store = store
        canvas.sync(with: tab)
        return canvas
    }

    func updateNSView(_ canvas: CanvasNSView, context: Context) {
        canvas.store = store
        canvas.sync(with: tab)
    }
}
