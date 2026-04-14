# Building a multi-terminal macOS app with SwiftTerm and SwiftUI

**SwiftTerm provides a production-grade VT100/xterm terminal engine as an AppKit `NSView`, which you wrap in `NSViewRepresentable` to embed real zsh sessions inside SwiftUI.** The library powers commercial apps like Secure Shellfish and La Terminal, supports local PTY processes and SSH (via external libraries), and runs on macOS 13+. The single biggest gotcha: you **must disable the App Sandbox** or `LocalProcessTerminalView` silently fails. Below is a complete implementation guide with working code for every layer of the app.

---

## Adding SwiftTerm via Swift Package Manager

The package lives at `https://github.com/migueldeicaza/SwiftTerm`. The current release line is **v1.12.x**, targeting Swift 5.9+ with minimum **macOS 13**.

**In Xcode:** File → Add Package Dependencies → paste the URL → select "Up to Next Major Version" from 1.12.0.

**In a `Package.swift` file:**

```swift
// swift-tools-version:5.9
let package = Package(
    name: "MultiTerminal",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.12.0")
    ],
    targets: [
        .executableTarget(
            name: "MultiTerminal",
            dependencies: ["SwiftTerm"]
        )
    ]
)
```

The package exposes a single library product called `SwiftTerm`. On macOS it compiles the `Mac/` and `Apple/` source directories, giving you `TerminalView` (an `NSView` subclass) and `LocalProcessTerminalView` (a subclass that manages a child process over a pseudo-terminal). There is **no built-in SwiftUI view** — you must bridge it yourself, which the next section covers.

---

## Embedding a zsh terminal in SwiftUI with NSViewRepresentable

`LocalProcessTerminalView` inherits from `NSView`, so the standard SwiftUI bridge is `NSViewRepresentable`. A critical detail: **`LocalProcessTerminalView` sets `TerminalView.terminalDelegate` internally to itself** — never override that property. Instead, use the separate `processDelegate` property (of type `LocalProcessTerminalViewDelegate`) to receive events in your code.

Here is a robust wrapper using the `Coordinator` pattern:

```swift
import SwiftUI
import SwiftTerm

struct TerminalPane: NSViewRepresentable {
    /// Optional: pass in the shell and working directory
    var shell: String = "/bin/zsh"
    var initialDirectory: String? = nil

    // MARK: - Coordinator (receives terminal events)

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        func processTerminated(_ source: TerminalView, exitCode: Int32?) {
            print("Shell exited with code: \(exitCode ?? -1)")
        }
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // React to resize if needed
        }
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            // Update a @Binding or @Published title here
        }
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            // Track cwd changes
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let tv = LocalProcessTerminalView(frame: .zero)
        tv.processDelegate = context.coordinator

        // Configure appearance
        tv.configureNativeColors()           // match system light/dark
        tv.optionAsMetaKey = true            // Option sends ESC prefix

        // Launch zsh
        tv.startProcess(
            executable: shell,
            args: ["--login"],
            environment: Terminal.getEnvironmentVariables(termName: "xterm-256color"),
            execName: nil,
            currentDirectory: initialDirectory
        )
        return tv
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Respond to SwiftUI state changes if needed
    }
}
```

**Usage is now one line in any SwiftUI view:**

```swift
struct ContentView: View {
    var body: some View {
        TerminalPane(shell: "/bin/zsh", initialDirectory: "~")
            .frame(minWidth: 400, minHeight: 300)
    }
}
```

Two important API notes. First, **`startProcess` defaults to `/bin/bash`** — always pass `/bin/zsh` explicitly. Second, `Terminal.getEnvironmentVariables(termName:)` is a convenience that generates a standard environment array including `TERM`; if it's unavailable in your version, build the array manually with `["TERM=xterm-256color", "LANG=en_US.UTF-8"]` plus whatever you need.

To **send commands programmatically** to the terminal, call `send(txt:)` on the `LocalProcessTerminalView` instance:

```swift
terminalView.send(txt: "ls -la\n")
```

To **capture output**, subclass `LocalProcessTerminalView` and override `dataReceived`:

```swift
class CapturingTerminalView: LocalProcessTerminalView {
    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        let text = String(bytes: slice, encoding: .utf8) ?? ""
        print("Output: \(text)")
    }
}
```

---

## A resizable grid of up to 9 terminal panes

SwiftUI on macOS provides `HSplitView` and `VSplitView` with built-in draggable dividers. Nesting them creates a grid where each row is an `HSplitView` inside an outer `VSplitView`. This approach gives native resize cursors and feel with zero dependencies.

### Dynamic grid driven by an observable model

```swift
import SwiftUI
import SwiftTerm

/// Tracks how many rows and columns the grid has
class GridModel: ObservableObject {
    @Published var rows: Int = 1      // 1–3
    @Published var columns: Int = 1   // 1–3
}

struct TerminalGridView: View {
    @StateObject private var grid = GridModel()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar to control grid size
            HStack {
                Text("Layout")
                Picker("Rows", selection: $grid.rows) {
                    ForEach(1...3, id: \.self) { Text("\($0)R") }
                }
                Picker("Cols", selection: $grid.columns) {
                    ForEach(1...3, id: \.self) { Text("\($0)C") }
                }
            }
            .padding(6)

            // The resizable grid
            ResizableTerminalGrid(rows: grid.rows, columns: grid.columns)
        }
    }
}

struct ResizableTerminalGrid: View {
    let rows: Int
    let columns: Int

    var body: some View {
        VSplitView {
            ForEach(0..<rows, id: \.self) { row in
                HSplitView {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        TerminalPane(shell: "/bin/zsh")
                            .frame(
                                minWidth: 200,  maxWidth: .infinity,
                                minHeight: 120, maxHeight: .infinity
                            )
                            .id("pane-\(index)")
                    }
                }
                .frame(minHeight: 120, maxHeight: .infinity)
            }
        }
    }
}
```

This gives you a **1×1 up to 3×3 grid** (9 panes), where every divider is natively draggable. Each pane's `minWidth`/`minHeight` prevents collapsing below a usable terminal size.

### Alternative: custom drag-gesture dividers for finer control

If you need pixel-precise control or animated resize, replace `HSplitView`/`VSplitView` with a `GeometryReader` plus `DragGesture` dividers:

```swift
struct TwoColumnTerminal: View {
    @State private var splitFraction: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                TerminalPane()
                    .frame(width: geo.size.width * splitFraction)

                // Draggable divider
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 4)
                    .onHover { hovering in
                        if hovering { NSCursor.resizeLeftRight.push() }
                        else { NSCursor.pop() }
                    }
                    .gesture(DragGesture().onChanged { value in
                        let new = splitFraction
                            + value.translation.width / geo.size.width
                        splitFraction = max(0.15, min(0.85, new))
                    })

                TerminalPane()
            }
        }
    }
}
```

A third option is the **stevengharris/SplitView** library (`https://github.com/stevengharris/SplitView`), which provides `HSplit`/`VSplit` views with constrained drag, hide-on-drag, and state persistence — useful if you want polish without building it yourself.

---

## Colour-coded project tabs with a custom tab bar

SwiftUI's built-in `TabView` doesn't support per-tab colours, so build a thin custom tab bar. Each tab stores a name, accent colour, and unique ID:

```swift
import SwiftUI

struct ProjectTab: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var color: Color
}

class TabStore: ObservableObject {
    @Published var tabs: [ProjectTab] = [
        ProjectTab(name: "API Server",  color: .green),
        ProjectTab(name: "Frontend",    color: .blue),
        ProjectTab(name: "Database",    color: .orange),
    ]
    @Published var selectedID: UUID?

    init() { selectedID = tabs.first?.id }

    func addTab(name: String, color: Color) {
        let tab = ProjectTab(name: name, color: color)
        tabs.append(tab)
        selectedID = tab.id
    }

    func closeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if selectedID == id { selectedID = tabs.first?.id }
    }
}

struct ProjectTabBar: View {
    @ObservedObject var store: TabStore

    var body: some View {
        HStack(spacing: 2) {
            ForEach(store.tabs) { tab in
                TabButton(tab: tab, isSelected: tab.id == store.selectedID) {
                    store.selectedID = tab.id
                } onClose: {
                    store.closeTab(tab.id)
                }
            }

            // "+" button to add tabs
            Button(action: {
                store.addTab(
                    name: "New Tab",
                    color: [.red, .purple, .cyan, .mint, .yellow].randomElement()!
                )
            }) {
                Image(systemName: "plus")
                    .font(.caption)
                    .padding(6)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }
}

struct TabButton: View {
    let tab: ProjectTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tab.color)
                .frame(width: 8, height: 8)

            Text(tab.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isSelected ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected
                      ? tab.color.opacity(0.15)
                      : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? tab.color.opacity(0.4) : .clear,
                              lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
```

### Wiring tabs to terminal grids

Each tab owns its own terminal grid. Use a `ZStack` or `switch` to show only the selected tab's content, which keeps every terminal session alive in the background:

```swift
struct MainContentView: View {
    @StateObject private var tabStore = TabStore()

    var body: some View {
        VStack(spacing: 0) {
            ProjectTabBar(store: tabStore)

            ZStack {
                ForEach(tabStore.tabs) { tab in
                    ResizableTerminalGrid(rows: 1, columns: 1)
                        .opacity(tab.id == tabStore.selectedID ? 1 : 0)
                        .allowsHitTesting(tab.id == tabStore.selectedID)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

@main
struct MultiTerminalApp: App {
    var body: some Scene {
        WindowGroup {
            MainContentView()
        }
    }
}
```

Using `opacity(0)` instead of an `if` conditional keeps background terminal processes running and preserves scroll history. The **`allowsHitTesting(false)`** on hidden panes prevents accidental input.

---

## SSH session support with TerminalView

SwiftTerm deliberately excludes SSH from the core package to avoid dependency bloat. The recommended approach is **apple/swift-nio-ssh** (pure Swift, actively maintained by Apple) or **Citadel** (`https://github.com/orlandos-nl/Citadel`) which wraps swift-nio-ssh with a cleaner async/await API. SwiftTerm's own iOS sample app demonstrates the swift-nio-ssh pattern.

The architecture for SSH differs from local terminals: you use the base `TerminalView` (not `LocalProcessTerminalView`) and implement `TerminalViewDelegate` yourself to bridge keystrokes and data between the terminal UI and the SSH channel.

```swift
import SwiftUI
import SwiftTerm
import Citadel      // .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.11.1")

struct SSHTerminalPane: NSViewRepresentable {
    let host: String
    let port: Int
    let username: String
    let password: String

    class Coordinator: NSObject, TerminalViewDelegate {
        var sshClient: SSHClient?
        var writeHandler: ((Data) async throws -> Void)?
        weak var termView: TerminalView?

        // User typed something → send to SSH channel
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            let payload = Data(data)
            Task { try? await writeHandler?(payload) }
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            // Citadel handles resize if you use withPTY's channel
        }

        // Required delegate stubs
        func scrolled(source: TerminalView, position: Double) {}
        func setTerminalTitle(source: TerminalView, title: String) {}
        func clipboardCopy(source: TerminalView, content: Data) {
            if let s = String(data: content, encoding: .utf8) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(s, forType: .string)
            }
        }
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String:String]) {
            if let url = URL(string: link) { NSWorkspace.shared.open(url) }
        }

        // Launch SSH connection
        func connect(host: String, port: Int, user: String, pass: String) {
            Task {
                do {
                    let client = try await SSHClient.connect(
                        host: host, port: port,
                        authenticationMethod: .passwordBased(
                            username: user, password: pass),
                        hostKeyValidator: .acceptAnything()
                    )
                    self.sshClient = client
                    // Open an interactive PTY shell
                    try await client.withPTY(
                        .init(wantReply: true, term: "xterm-256color",
                              terminalCharacterWidth: 80,
                              terminalRowHeight: 24,
                              terminalPixelWidth: 0,
                              terminalPixelHeight: 0,
                              terminalModes: .init([]))
                    ) { output, writer in
                        self.writeHandler = { data in
                            try await writer.write(.init(data: data))
                        }
                        for try await buffer in output {
                            let bytes = Array(buffer.readableBytesView)
                            DispatchQueue.main.async {
                                self.termView?.feed(byteArray: bytes[...])
                            }
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.termView?.feed(text: "\r\n[SSH Error] \(error)\r\n")
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> TerminalView {
        let tv = TerminalView(frame: .zero)
        tv.terminalDelegate = context.coordinator
        tv.configureNativeColors()
        context.coordinator.termView = tv
        context.coordinator.connect(
            host: host, port: port, user: username, pass: password)
        return tv
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {}
}
```

The critical data-flow pattern is the same regardless of SSH library: **user keystrokes flow out** through `TerminalViewDelegate.send(source:data:)` to the SSH channel, and **remote output flows in** through `terminalView.feed(byteArray:)`. The `TerminalView` handles all VT100/xterm escape-sequence parsing internally.

---

## Entitlements, sandbox, and common gotchas

**Disabling the App Sandbox is mandatory for local shells.** `LocalProcessTerminalView` uses `forkpty()` to spawn a child process inside a pseudo-terminal — this requires unrestricted file-system and process access. In Xcode, go to your target's "Signing & Capabilities" tab and remove the App Sandbox entirely. Alternatively, set the entitlements plist to:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

For **SSH-only terminals** (no local shell), you can keep the sandbox enabled but must add the **outgoing network connections** entitlement (`com.apple.security.network.client` = `true`).

Beyond the sandbox, here are the most common pitfalls:

- **Never set `terminalDelegate` on `LocalProcessTerminalView`.** It consumes that delegate internally to pipe data between the PTY and the view. Use `processDelegate` (of type `LocalProcessTerminalViewDelegate`) for your own event handling. Setting `terminalDelegate` directly will break input/output silently.
- **`startProcess` defaults to `/bin/bash`, not zsh.** Always pass `executable: "/bin/zsh"` explicitly.
- **`NSViewRepresentable` lifecycle matters.** Create the `LocalProcessTerminalView` instance inside `makeNSView`, not in the struct's `init`. Storing it as a `@State` property leads to duplicate instances because SwiftUI can recreate the struct at any time.
- **Hardened Runtime for distribution.** If you notarise the app, enable Hardened Runtime but leave the sandbox off. No special Hardened Runtime entitlements are needed for PTY access beyond disabling the sandbox.
- **Metal rendering availability.** SwiftTerm supports GPU-accelerated rendering via Metal (call `try tv.setUseMetal(true)`), but this fails silently in VMs and CI environments. Guard it with a check or catch the error.
- **Option key as Meta.** `optionAsMetaKey` defaults to `true`, which is what most terminal users expect (Option+key sends ESC prefix). Set it to `false` only if you need macOS character input (e.g., Option+e for accented characters).
- **`TERM` environment variable.** Set it to `xterm-256color` for proper colour support. If colours appear wrong, this is almost always the cause.

## Conclusion

The full stack for a multi-pane, tabbed terminal app is surprisingly thin: **SwiftTerm** provides the terminal engine and AppKit view, a ~30-line `NSViewRepresentable` bridges it into SwiftUI, nested `VSplitView`/`HSplitView` gives you a natively resizable grid, and a lightweight `ObservableObject` tab store drives the colour-coded project tabs. SSH follows the same `TerminalView` + delegate pattern but swaps the local PTY for a swift-nio-ssh (or Citadel) channel. The single non-obvious requirement — disabling the App Sandbox — is the one thing that will block you if missed. Everything else is straightforward SwiftUI composition with a well-designed AppKit library underneath.