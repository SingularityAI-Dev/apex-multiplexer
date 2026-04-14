import SwiftUI
import Foundation

// MARK: - Open File Model

struct OpenFile: Identifiable, Equatable {
    let id   = UUID()
    let url: URL
    var content: String
    var isModified: Bool = false
    var name: String { url.lastPathComponent }
    var ext:  String { url.pathExtension.lowercased() }

    // Human-readable size of the file on disk
    var formattedSize: String {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

// MARK: - File Open Error

enum FileOpenError: LocalizedError {
    case binaryFile(URL)
    case fileTooLarge(URL, Int)
    case readFailed(URL)

    var errorDescription: String? {
        switch self {
        case .binaryFile(let u):           return "\"\(u.lastPathComponent)\" appears to be a binary file."
        case .fileTooLarge(let u, let mb): return "\"\(u.lastPathComponent)\" is \(mb) MB — too large to edit."
        case .readFailed(let u):           return "Could not read \"\(u.lastPathComponent)\"."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .binaryFile:   return "Open it in a dedicated app instead."
        case .fileTooLarge: return "Files over 10 MB are not supported in the built-in editor."
        case .readFailed:   return "Check that the file exists and is readable."
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var openFiles:   [OpenFile] = []
    @Published var activeFileID: UUID?
    @Published var lastError:    FileOpenError?

    private let maxFileSizeMB = 10

    var activeFile: OpenFile? { openFiles.first { $0.id == activeFileID } }

    // MARK: Open

    func openFile(url: URL) {
        // Already open → just activate it
        if let existing = openFiles.first(where: { $0.url == url }) {
            activeFileID = existing.id
            return
        }

        // Size guard
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            let mb = size / (1024 * 1024)
            if mb >= maxFileSizeMB {
                lastError = .fileTooLarge(url, mb)
                return
            }
        }

        // Read as UTF-8; reject binary files
        guard let data = try? Data(contentsOf: url) else {
            lastError = .readFailed(url)
            return
        }
        guard let content = String(data: data, encoding: .utf8) else {
            lastError = .binaryFile(url)
            return
        }

        let file = OpenFile(url: url, content: content)
        openFiles.append(file)
        activeFileID = file.id
    }

    // MARK: Close

    /// Returns true if the file was closed (or had no unsaved changes).
    /// Returns false if the caller should prompt the user first.
    @discardableResult
    func closeFile(_ id: UUID) -> Bool {
        guard let i = openFiles.firstIndex(where: { $0.id == id }) else { return true }
        openFiles.remove(at: i)
        if activeFileID == id {
            activeFileID = openFiles.isEmpty ? nil : (openFiles[safe: i] ?? openFiles.last)?.id
        }
        return true
    }

    // MARK: Save

    func saveFile(_ id: UUID) {
        guard let i = openFiles.firstIndex(where: { $0.id == id }) else { return }
        do {
            try openFiles[i].content.write(to: openFiles[i].url, atomically: true, encoding: .utf8)
            openFiles[i].isModified = false
        } catch {
            lastError = .readFailed(openFiles[i].url)
        }
    }

    func saveActiveFile() {
        if let id = activeFileID { saveFile(id) }
    }

    // MARK: Edit

    func updateContent(id: UUID, content: String) {
        guard let i = openFiles.firstIndex(where: { $0.id == id }) else { return }
        if openFiles[i].content == content { return }   // no-op if unchanged
        openFiles[i].content    = content
        openFiles[i].isModified = true
    }
}

// MARK: - Safe Collection Extension

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
