import Foundation

enum ByteFormatter {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .memory
        f.allowsNonnumericFormatting = false
        return f
    }()

    static func string(from bytes: UInt64) -> String {
        formatter.string(fromByteCount: Int64(clamping: bytes))
    }

    static func string(from bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }

    /// Signed delta, e.g. "+120 MB" / "−45 MB".
    static func delta(from bytes: Int64) -> String {
        let abs = string(from: abs(bytes))
        if bytes > 0 { return "+\(abs)" }
        if bytes < 0 { return "−\(abs)" }
        return abs
    }
}
