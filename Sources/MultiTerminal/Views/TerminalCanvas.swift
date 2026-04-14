import SwiftUI

// MARK: - Dot Grid Background

struct DotGridView: View {
    let gridSize: CGFloat
    var body: some View {
        Canvas { ctx, size in
            ctx.opacity = 0.16
            for x in stride(from: 0, to: size.width,  by: gridSize) {
                for y in stride(from: 0, to: size.height, by: gridSize) {
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 0.75, y: y - 0.75,
                                               width: 1.5, height: 1.5)),
                        with: .color(.white)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Canvas Root
//
// Uses AppKitTerminalCanvas (one NSViewRepresentable → one AppKit NSView)
// instead of per-pane SwiftUI NSViewRepresentables.
// This ensures standard AppKit hitTest → mouseDown → makeFirstResponder → keyDown
// works for terminal keyboard input.

struct TerminalCanvasView: View {
    var tab: ProjectTab
    @EnvironmentObject var store: TabStore

    var body: some View {
        ZStack {
            // Dot grid drawn by SwiftUI (does not intercept events)
            DotGridView(gridSize: store.gridSize)
                .allowsHitTesting(false)

            // ALL terminals are inside this single AppKit NSView
            AppKitTerminalCanvas(tab: tab)
                .environmentObject(store)
        }
        .background(Color(red: 0.068, green: 0.068, blue: 0.072))
    }
}

// MARK: - Pane Color Picker Popover

struct PaneColorPicker: View {
    let paneID:  UUID
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
                    .onTapGesture {
                        store.updatePaneColor(paneID: paneID, to: color)
                        dismiss()
                    }
            }
        }
        .padding(12)
    }
}
