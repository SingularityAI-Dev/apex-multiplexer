<div align="center">

# ⚡ Multi-Term

**A native macOS terminal multiplexer for power users.**

Run multiple terminal sessions in a single window with draggable, resizable, color-coded panes.

Built with Swift · SwiftUI · AppKit · [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

</div>

---

## ✨ Features

- 🖥️ **Multiple terminal panes** — Spawn as many terminals as you need, each running its own independent shell session
- 🖱️ **Drag & drop layout** — Freely position and resize panes on a dot-grid canvas
- 🎨 **Color-coded panes** — Assign colors to terminals for instant visual identification
- ✏️ **Rename terminals** — Double-click or right-click the title bar to rename any pane
- 📂 **Project tabs** — Organize terminal groups into separate project workspaces
- 📁 **File explorer** — Sidebar that auto-syncs to the focused terminal's working directory via OSC 7 shell integration
- ⚡ **Native performance** — Zero-overhead keyboard input through direct AppKit event handling
- 🍎 **macOS native** — No Electron, no web views. Pure Swift + SwiftUI + AppKit

## 📸 Screenshots

<!-- Add screenshots here -->
<!-- ![Multi-Term Screenshot](docs/screenshot.png) -->

## 📦 Installation

### Download a release

Grab the latest release from the [Releases](../../releases) page:

| Format | Description |
|--------|-------------|
| `Multi-Term-x.x.x.pkg` | macOS installer — double-click to install to `/Applications` |
| `Multi-Term-x.x.x.zip` | Portable — unzip and drag `Multi-Term.app` to `/Applications` |

> [!NOTE]
> Multi-Term is ad-hoc signed (not notarized with Apple Developer ID).
> On first launch, right-click the app → **Open** to bypass Gatekeeper.

### Build from source

Requires **Xcode 15+** and **macOS 13 (Ventura)** or later.

```bash
git clone https://github.com/SingularityAI-Dev/multi-term.git
cd multi-term
swift build
swift run
```

### Create distributable packages

```bash
./build-dist.sh
```

This produces `Multi-Term.app`, `Multi-Term-x.x.x.pkg`, and `Multi-Term-x.x.x.zip` in the `dist/` directory.

## 🚀 Usage

| Action | How |
|---|---|
| **New terminal** | Click **+** in the tab bar |
| **Move a pane** | Drag the colored title bar |
| **Resize a pane** | Drag the bottom edge |
| **Focus a terminal** | Click inside the terminal area |
| **Rename** | Double-click the title bar, or right-click → *Rename…* |
| **Change color** | Right-click title bar → *Color* → pick a preset |
| **Close a pane** | Right-click title bar → *Close Terminal* |
| **New project tab** | Click **+** next to the tab bar |

## 🏗️ Architecture

Multi-Term uses a hybrid **SwiftUI + AppKit** architecture:

```
┌──────────────────────────────────────────────────────┐
│  SwiftUI Shell                                       │
│  ┌────────┬───────────────────────────────────────┐  │
│  │  File  │  AppKit Terminal Canvas (NSView)      │  │
│  │Explorer│  ┌─────────────┐  ┌─────────────┐    │  │
│  │  (OSC7 │  │ Terminal 1  │  │ Terminal 2  │    │  │
│  │  sync) │  │ (zsh)       │  │ (zsh)       │    │  │
│  │        │  └─────────────┘  └─────────────┘    │  │
│  └────────┴───────────────────────────────────────┘  │
│  Tab Bar: [ Development ] [ Staging ] [ + ]          │
└──────────────────────────────────────────────────────┘
```

- **SwiftUI** handles the outer chrome — tab bar, file explorer sidebar, and window management
- **AppKit** handles the terminal canvas — all panes are native `NSView` subviews with frame-based positioning, ensuring standard AppKit hit-testing and first-responder keyboard input
- **[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)** provides the terminal emulator with full xterm-256color support, mouse reporting, and Metal-accelerated rendering

### Why not pure SwiftUI?

SwiftUI's `NSViewRepresentable` embeds AppKit views inside an `NSHostingView` that intercepts all events via `hitTest`. Combined with `.offset()` using CALayer transforms (which don't affect AppKit's frame-based hit testing), the terminal views never receive mouse or keyboard events. Multi-Term solves this by hosting all terminals in a single AppKit `NSView` container where standard event routing works naturally.

## 🤝 Contributing

Contributions are welcome! Here's how to get started:

1. **Fork** the repository
2. **Create a feature branch:** `git checkout -b feat/my-feature`
3. **Make your changes** and test locally with `swift build && swift run`
4. **Commit** with a descriptive message: `git commit -m "feat: add split-pane support"`
5. **Push** to your fork: `git push origin feat/my-feature`
6. **Open a Pull Request** against `main`

### Development guidelines

- Follow existing code style and naming conventions
- Keep commits focused — one feature or fix per commit
- Test on macOS 13+ before submitting
- Update the README if adding user-facing features

### Ideas for contributions

- [ ] Split-pane tiling (horizontal/vertical splits)
- [ ] Layout persistence (save/restore pane positions across launches)
- [ ] Custom shell support (bash, fish, nushell via settings)
- [ ] Keyboard shortcuts (Cmd+T new tab, Cmd+N new pane, etc.)
- [ ] Themes and font customization
- [ ] Search within terminal scrollback
- [ ] Drag-and-drop file paths into terminals
- [ ] App icon

### Reporting issues

Found a bug? Please [open an issue](../../issues/new) with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Console output if available (run from Terminal.app to see logs)

## ⚙️ Requirements

- macOS 13.0 (Ventura) or later
- App Sandbox must be **disabled** (SPM builds have no sandbox by default)

## 📄 License

This project is licensed under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza — the terminal emulator powering Multi-Term
