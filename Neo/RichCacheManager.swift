import Foundation
import AppKit

final class RichCacheManager {
    static let shared = RichCacheManager()
    private init() {}

    private func cacheRoot() throws -> URL {
        let base = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("NeoRichCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func pathForDocument(id: UUID) -> URL? {
        do {
            let root = try cacheRoot()
            return root.appendingPathComponent("\(id.uuidString).rtfddata", isDirectory: false)
        } catch { return nil }
    }

    func loadAttributed(id: UUID, path: String?) -> NSAttributedString? {
        // Prefer explicit path if provided
        if let p = path, let data = try? Data(contentsOf: URL(fileURLWithPath: p)) {
            if let att = NSAttributedString(rtfd: data, documentAttributes: nil) ?? NSAttributedString(rtf: data, documentAttributes: nil) {
                return att
            }
        }
        // Else fallback to derived path by id
        if let url = pathForDocument(id: id), let data = try? Data(contentsOf: url) {
            return NSAttributedString(rtfd: data, documentAttributes: nil) ?? NSAttributedString(rtf: data, documentAttributes: nil)
        }
        return nil
    }

    @discardableResult
    func saveAttributed(id: UUID, textStorage: NSTextStorage) -> String? {
        let full = NSRange(location: 0, length: textStorage.length)
        guard let data = textStorage.rtfd(from: full, documentAttributes: [:]) ?? textStorage.rtf(from: full, documentAttributes: [:]) else {
            return nil
        }
        guard let url = pathForDocument(id: id) else { return nil }
        do {
            let tmp = url.appendingPathExtension("tmp")
            try data.write(to: tmp, options: .atomic)
            // Move to final atomically
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: tmp, to: url)
            return url.path
        } catch {
            return nil
        }
    }
}
