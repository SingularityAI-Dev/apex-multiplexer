import SwiftUI

// MARK: - File Icon Descriptor

struct FileIcon {
    let symbol: String
    let color: Color
}

// MARK: - File Icon Lookup (VSCode-style colours)

func fileIcon(for url: URL, isDir: Bool) -> FileIcon {
    if isDir {
        return FileIcon(symbol: "folder.fill",
                        color: Color(hue: 0.585, saturation: 0.50, brightness: 0.82))
    }

    switch url.pathExtension.lowercased() {

    // ── Apple / Swift ────────────────────────────────────────────────
    case "swift":            return .init(symbol: "swift",                               color: .orange)
    case "xcodeproj",
         "xcworkspace":      return .init(symbol: "hammer.fill",                         color: Color(red:0.18,green:0.45,blue:0.80))

    // ── Web / JS ─────────────────────────────────────────────────────
    case "js":               return .init(symbol: "j.square.fill",                       color: Color(red:0.95,green:0.78,blue:0.00))
    case "jsx":              return .init(symbol: "j.square.fill",                       color: Color(red:0.54,green:0.76,blue:0.95))
    case "ts":               return .init(symbol: "t.square.fill",                       color: Color(red:0.18,green:0.49,blue:0.77))
    case "tsx":              return .init(symbol: "t.square.fill",                       color: Color(red:0.18,green:0.49,blue:0.77))
    case "html":             return .init(symbol: "chevron.left.forwardslash.chevron.right",
                                                                                          color: Color(red:0.90,green:0.35,blue:0.15))
    case "css":              return .init(symbol: "paintbrush.pointed.fill",             color: Color(red:0.28,green:0.55,blue:0.90))
    case "scss","sass":      return .init(symbol: "paintbrush.fill",                     color: Color(red:0.81,green:0.47,blue:0.65))
    case "vue":              return .init(symbol: "v.circle.fill",                       color: Color(red:0.25,green:0.72,blue:0.56))

    // ── Data ─────────────────────────────────────────────────────────
    case "json":             return .init(symbol: "curlybraces",                              color: Color(red:0.95,green:0.78,blue:0.00))
    case "yaml","yml":       return .init(symbol: "list.dash.header.rectangle",          color: Color(red:0.72,green:0.35,blue:0.22))
    case "toml":             return .init(symbol: "slider.horizontal.3",                 color: Color(red:0.55,green:0.39,blue:0.31))
    case "xml":              return .init(symbol: "chevron.left.forwardslash.chevron.right",
                                                                                          color: Color(red:0.55,green:0.78,blue:0.42))
    case "csv":              return .init(symbol: "tablecells.fill",                     color: Color(red:0.23,green:0.65,blue:0.35))
    case "sql":              return .init(symbol: "cylinder.fill",                       color: Color(red:0.35,green:0.60,blue:0.90))

    // ── Systems / Native ─────────────────────────────────────────────
    case "c":                return .init(symbol: "c.circle.fill",                       color: Color(red:0.00,green:0.39,blue:0.67))
    case "h":                return .init(symbol: "h.circle.fill",                       color: Color(red:0.51,green:0.17,blue:0.66))
    case "cpp","cxx","cc":   return .init(symbol: "c.square.fill",                       color: Color(red:0.00,green:0.39,blue:0.67))
    case "hpp":              return .init(symbol: "h.square.fill",                       color: Color(red:0.51,green:0.17,blue:0.66))
    case "rs":               return .init(symbol: "gearshape.fill",                      color: Color(red:0.88,green:0.45,blue:0.20))
    case "go":               return .init(symbol: "g.circle.fill",                       color: Color(red:0.41,green:0.75,blue:0.82))
    case "zig":              return .init(symbol: "z.circle.fill",                       color: Color(red:0.95,green:0.65,blue:0.15))

    // ── JVM ──────────────────────────────────────────────────────────
    case "java":             return .init(symbol: "cup.and.saucer.fill",                 color: Color(red:0.80,green:0.34,blue:0.22))
    case "kt","kts":         return .init(symbol: "k.circle.fill",                       color: Color(red:0.44,green:0.35,blue:0.82))
    case "scala":            return .init(symbol: "s.circle.fill",                       color: Color(red:0.85,green:0.18,blue:0.18))
    case "groovy":           return .init(symbol: "g.circle.fill",                       color: Color(red:0.22,green:0.65,blue:0.82))

    // ── .NET ─────────────────────────────────────────────────────────
    case "cs":               return .init(symbol: "c.square.fill",                       color: Color(red:0.37,green:0.18,blue:0.73))
    case "fs":               return .init(symbol: "f.square.fill",                       color: Color(red:0.37,green:0.65,blue:0.85))

    // ── Scripting ────────────────────────────────────────────────────
    case "py","pyw":         return .init(symbol: "p.circle.fill",                       color: Color(red:0.24,green:0.52,blue:0.78))
    case "rb":               return .init(symbol: "r.circle.fill",                       color: Color(red:0.72,green:0.12,blue:0.12))
    case "php":              return .init(symbol: "p.square.fill",                       color: Color(red:0.46,green:0.47,blue:0.76))
    case "lua":              return .init(symbol: "l.circle.fill",                       color: Color(red:0.10,green:0.25,blue:0.55))
    case "sh","zsh","bash",
         "fish","nu":        return .init(symbol: "terminal.fill",                       color: Color(red:0.23,green:0.78,blue:0.43))

    // ── Markup / Docs ────────────────────────────────────────────────
    case "md","mdx":         return .init(symbol: "text.justify.left",                   color: Color(red:0.45,green:0.65,blue:0.95))
    case "txt":              return .init(symbol: "doc.text",                             color: Color(white:0.60))
    case "pdf":              return .init(symbol: "doc.richtext",                         color: Color(red:0.85,green:0.15,blue:0.15))
    case "tex":              return .init(symbol: "textformat",                           color: Color(red:0.30,green:0.55,blue:0.80))

    // ── Config / Build ───────────────────────────────────────────────
    case "gitignore",
         "gitattributes":    return .init(symbol: "arrow.triangle.branch",               color: Color(red:0.88,green:0.35,blue:0.20))
    case "env",".env":       return .init(symbol: "key.fill",                            color: Color(red:0.95,green:0.75,blue:0.18))
    case "lock","resolved":  return .init(symbol: "lock.fill",                           color: Color(white:0.50))
    case "dockerfile":       return .init(symbol: "shippingbox.fill",                    color: Color(red:0.10,green:0.55,blue:0.82))
    case "makefile":         return .init(symbol: "wrench.and.screwdriver.fill",         color: Color(red:0.70,green:0.35,blue:0.10))

    // ── Media ────────────────────────────────────────────────────────
    case "png","jpg","jpeg",
         "webp","ico","bmp": return .init(symbol: "photo.fill",                          color: Color(red:0.53,green:0.35,blue:0.80))
    case "svg":              return .init(symbol: "photo.on.rectangle",                  color: Color(red:0.95,green:0.58,blue:0.18))
    case "gif":              return .init(symbol: "photo.stack",                         color: Color(red:0.85,green:0.35,blue:0.65))
    case "mp4","mov","avi",
         "mkv":              return .init(symbol: "play.rectangle.fill",                 color: Color(red:0.18,green:0.55,blue:0.95))
    case "mp3","wav","aiff",
         "flac","ogg":       return .init(symbol: "waveform",                            color: Color(red:0.95,green:0.45,blue:0.18))

    // ── Archives ─────────────────────────────────────────────────────
    case "zip","tar","gz",
         "rar","7z":         return .init(symbol: "archivebox.fill",                     color: Color(red:0.78,green:0.65,blue:0.35))

    default:                 return .init(symbol: "doc.fill",                             color: Color(white:0.50))
    }
}
