import Foundation

/// Deletes safe user-level cache / temp files that pressure RAM and disk.
/// Does NOT touch system-protected paths or user documents.
enum CacheCleaner {

    struct Report: Sendable {
        var bytesDeleted: Int64 = 0
        var filesDeleted: Int = 0
        var foldersTouched: [String] = []
        var notes: [String] = []
    }

    /// Folders under the user home that are safe-ish to empty.
    private static var targets: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let tmp = FileManager.default.temporaryDirectory
        return [
            home.appendingPathComponent("Library/Caches", isDirectory: true),
            home.appendingPathComponent("Library/Logs", isDirectory: true),
            tmp
        ]
    }

    /// Names we never delete (login / system stability).
    private static let protectedNames: Set<String> = [
        "CloudKit",
        "com.apple.HomeKit",
        "com.apple.accountsd",
        "com.apple.akd",
        "FamilyCircle",
        "GameKit",
        "PassKit",
        "com.apple.Safari", // Safari can get upset; skip whole tree name match
    ]

    static func cleanUserCaches(progress: (@Sendable (String) -> Void)? = nil) -> Report {
        var report = Report()
        let fm = FileManager.default

        for root in targets {
            guard fm.fileExists(atPath: root.path) else { continue }
            progress?("Limpiando \(root.lastPathComponent)…")

            let children: [URL]
            do {
                children = try fm.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )
            } catch {
                report.notes.append("No se pudo leer \(root.lastPathComponent): \(error.localizedDescription)")
                continue
            }

            for child in children {
                let name = child.lastPathComponent
                if isProtected(name) {
                    report.notes.append("Omitido (protegido): \(name)")
                    continue
                }
                // Temp dir: only delete items older than 12h (avoid killing live app temp files).
                if root == FileManager.default.temporaryDirectory {
                    if !shouldDeleteTempItem(child) { continue }
                }

                let size = directorySize(child)
                do {
                    try fm.removeItem(at: child)
                    report.bytesDeleted += size
                    report.filesDeleted += 1
                    report.foldersTouched.append(name)
                } catch {
                    // Partial: try emptying directory
                    if deleteContents(of: child, report: &report) {
                        report.foldersTouched.append(name + " (parcial)")
                    } else {
                        report.notes.append("No se pudo borrar \(name): \(error.localizedDescription)")
                    }
                }
            }
        }

        // Also clear URLCache on disk for this process (already done in service, but size-0).
        progress?("Cachés de usuario listos")
        return report
    }

    // MARK: - Helpers

    private static func isProtected(_ name: String) -> Bool {
        if protectedNames.contains(name) { return true }
        let lower = name.lowercased()
        // Keep Keychain / Apple ID related
        if lower.contains("keychain") { return true }
        if lower.hasPrefix("com.apple.authkit") { return true }
        if lower.hasPrefix("com.apple.security") { return true }
        return false
    }

    private static func shouldDeleteTempItem(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        // Keep Xcode / our own app temp if currently running heavily — still OK to delete orphan caches
        let keepPrefixes = ["com.apple.dt", "TemporaryItems"]
        if keepPrefixes.contains(where: { name.hasPrefix($0) }) { return false }

        // Delete items older than 12 hours
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let date = values?.contentModificationDate ?? values?.creationDate ?? .distantPast
        return Date().timeIntervalSince(date) > 12 * 3600
    }

    private static func deleteContents(of directory: URL, report: inout Report) -> Bool {
        let fm = FileManager.default
        guard let kids = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return false
        }
        var any = false
        for kid in kids {
            let size = directorySize(kid)
            do {
                try fm.removeItem(at: kid)
                report.bytesDeleted += size
                report.filesDeleted += 1
                any = true
            } catch {
                continue
            }
        }
        return any
    }

    private static func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            return Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
        }

        // Fast path: du -sk
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8) ?? ""
            let kb = Int64(out.split(whereSeparator: { $0.isWhitespace }).first.flatMap { Int64($0) } ?? 0)
            return kb * 1024
        } catch {
            return 0
        }
    }
}
