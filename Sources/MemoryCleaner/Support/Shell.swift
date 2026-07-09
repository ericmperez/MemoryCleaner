import Foundation

enum ShellError: Error, LocalizedError {
    case nonZeroExit(Int32, String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let code, let output):
            return "Comando terminó con código \(code): \(output)"
        case .cancelled:
            return "Operación cancelada"
        }
    }
}

enum Shell {
    /// Runs a command and returns combined stdout.
    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            process.terminationHandler = { proc in
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let out = String(data: outData, encoding: .utf8) ?? ""
                let err = String(data: errData, encoding: .utf8) ?? ""
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: out)
                } else {
                    continuation.resume(
                        throwing: ShellError.nonZeroExit(proc.terminationStatus, err.isEmpty ? out : err)
                    )
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Runs `/usr/sbin/purge` with an admin password prompt (via AppleScript).
    /// This flushes inactive file-backed memory pages system-wide.
    static func runPurgeWithAdmin() async throws {
        // osascript prompts for the Mac password in a system dialog.
        let script = "do shell script \"/usr/sbin/purge\" with administrator privileges"
        do {
            _ = try await run("/usr/bin/osascript", ["-e", script])
        } catch let ShellError.nonZeroExit(code, output) {
            // User cancelled the password dialog → typically -128 / "User canceled."
            let lower = output.lowercased()
            if code == -128 || lower.contains("cancel") || lower.contains("user canceled") {
                throw ShellError.cancelled
            }
            throw ShellError.nonZeroExit(code, output)
        }
    }
}
