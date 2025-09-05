import Foundation
import AppKit

// Shared helpers for saving/loading rich text to app caches.
func editorCacheFileURL(for docId: UUID) -> URL? {
    do {
        let base = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("NeoRichCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("\(docId.uuidString).rtfddata")
    } catch { return nil }
}

func loadAttributedFromCache(docId: UUID?, cachePath: String?) -> NSAttributedString? {
    if let p = cachePath, let data = try? Data(contentsOf: URL(fileURLWithPath: p)) {
        return NSAttributedString(rtfd: data, documentAttributes: nil) ?? NSAttributedString(rtf: data, documentAttributes: nil)
    }
    if let id = docId, let url = editorCacheFileURL(for: id), let data = try? Data(contentsOf: url) {
        return NSAttributedString(rtfd: data, documentAttributes: nil) ?? NSAttributedString(rtf: data, documentAttributes: nil)
    }
    return nil
}

@discardableResult
func saveAttributedToCache(docId: UUID, textStorage: NSTextStorage) -> String? {
    let full = NSRange(location: 0, length: textStorage.length)
    guard let data = textStorage.rtfd(from: full, documentAttributes: [:]) ?? textStorage.rtf(from: full, documentAttributes: [:]) else { return nil }
    guard let url = editorCacheFileURL(for: docId) else { return nil }
    do {
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try FileManager.default.moveItem(at: tmp, to: url)
        return url.path
    } catch { return nil }
}
