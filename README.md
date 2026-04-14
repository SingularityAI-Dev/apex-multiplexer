# Multi-Term

A native macOS terminal multiplexer built with Swift, SwiftUI, and
[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm). Run multiple terminal
sessions in a single window with draggable, resizable, color-coded panes.

## Features

- **Multiple terminal panes** — Spawn as many terminals as you need, each
  running its own shell session
- **Drag & drop layout** — Freely position and resize panes on a dot-grid canvas
- **Color-coded panes** — Assign colors to terminals for quick visual
  identification
- **Rename terminals** — Double-click or right-click the title bar to rename any
  pane
- **Project tabs** — Organize terminal groups into separate project workspaces
- **File explorer** — Sidebar that auto-syncs to the focused terminal's current
  working directory via OSC 7
- **Native performance** — Built entirely in Swift with AppKit terminal hosting
  for zero-overhead keyboard input
- **macOS native** — No Electron, no web views. Pure Swift + SwiftUI + AppKit

## Screenshots

<!-- Add screenshots here -->

## Installation

### Download

Grab the latest release from the [Releases](../../releases) page:

- **`Multi-Term-x.x.x.pkg`** — Double-click to install to `/Applications`
- **`Multi-Term-x.x.x.zip`** — Unzip and drag `Multi-Term.app` to
  `/Applications`

> **Note:** Multi-Term is ad-hoc signed. On first launch, right-click → **Open**
> to bypass Gatekeeper.

### Build from source

Requires **Xcode 15+** and **macOS 13+**.

```bash
git clone https://github.com/SingularityAI-Dev/multi-term.git
cd multi-term
swift build
swift run
```

To create distributable `.app`, `.pkg`, and `.zip`:

```bash
./build-dist.sh
```

Output goes to the `dist/` directory.

## Usage

| Action               | How                                                 |
| -------------------- | --------------------------------------------------- |
| **New terminal**     | Click **+** in the tab bar                          |
| **Move a pane**      | Drag the colored title bar                          |
| **Resize a pane**    | Drag the bottom edge                                |
| **Focus a terminal** | Click inside the terminal area                      |
| **Rename**           | Double-click the title bar, or right-click → Rename |
| **Change color**     | Right-click title bar → Color → pick a color        |
| **Close a pane**     | Right-click title bar → Close Terminal              |
| **New project tab**  | Click **+** next to the tab bar                     |

## Architecture

Multi-Term uses a hybrid SwiftUI + AppKit architecture:

- **SwiftUI** handles the outer chrome — tab bar, file explorer sidebar, and
  window management
- **AppKit** handles the terminal canvas — all terminal panes are native
  `NSView` subviews with frame-based positioning, ensuring standard AppKit
  hit-testing and first-responder keyboard input works flawlessly
- **[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)** provides the
  terminal emulator (`LocalProcessTerminalView`) with full xterm-256color
  support, mouse reporting, and Metal-accelerated rendering

### Why not pure SwiftUI?

SwiftUI's `NSViewRepresentable` embeds AppKit views inside an `NSHostingView`
that intercepts all events via `hitTest`. Combined with `.offset()` using
CALayer transforms (which don't affect AppKit's frame-based hit testing), the
terminal views never receive mouse or keyboard events. Multi-Term solves this by
hosting all terminals in a single AppKit `NSView` container where standard event
routing works naturally.

## Requirements

- macOS 13.0 (Ventura) or later
- App Sandbox must be **disabled** (SPM builds have no sandbox by default)

## License

MIT

## Acknowledgments

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza —
  the terminal emulator powering Multi-Term
# multi-term
