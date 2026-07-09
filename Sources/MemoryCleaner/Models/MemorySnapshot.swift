import Foundation

/// Snapshot of Mac memory at a point in time.
struct MemorySnapshot: Equatable, Sendable {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let freeBytes: UInt64
    let wiredBytes: UInt64
    let inactiveBytes: UInt64
    let activeBytes: UInt64
    let compressedBytes: UInt64
    let purgeableBytes: UInt64
    let appResidentBytes: UInt64
    let timestamp: Date

    var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    var freePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeBytes) / Double(totalBytes) * 100
    }

    var pressure: MemoryPressure {
        switch usedPercent {
        case ..<60: return .normal
        case 60..<80: return .elevated
        case 80..<90: return .high
        default: return .critical
        }
    }
}

enum MemoryPressure: String, Sendable {
    case normal, elevated, high, critical

    var titleES: String {
        switch self {
        case .normal: return "Normal"
        case .elevated: return "Elevada"
        case .high: return "Alta"
        case .critical: return "Crítica"
        }
    }

    var subtitleES: String {
        switch self {
        case .normal: return "Tu Mac tiene memoria suficiente."
        case .elevated: return "El uso de memoria es moderado."
        case .high: return "Poca memoria libre. Conviene liberar."
        case .critical: return "Memoria muy llena. Libera ahora."
        }
    }
}

enum CleanupMode: String, Sendable {
    /// Cachés de usuario + presión de RAM (sin admin).
    case quick
    /// Todo lo de quick + `/usr/sbin/purge` (admin).
    case deep
}

struct CleanupStep: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let bytesFreed: Int64
    let ok: Bool

    init(title: String, detail: String, bytesFreed: Int64 = 0, ok: Bool = true) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.bytesFreed = bytesFreed
        self.ok = ok
    }
}

struct CleanupResult: Equatable, Sendable {
    let before: MemorySnapshot
    let after: MemorySnapshot
    /// RAM reclaim estimate (free/inactive/used deltas).
    let memoryFreedBytes: Int64
    /// Disk/cache files deleted (bytes).
    let cacheFreedBytes: Int64
    let filesDeleted: Int
    let duration: TimeInterval
    let mode: CleanupMode
    let usedAdminPurge: Bool
    let steps: [CleanupStep]
    let summary: String

    var totalFreedBytes: Int64 { max(memoryFreedBytes, 0) + max(cacheFreedBytes, 0) }
    var didImprove: Bool { totalFreedBytes > 0 || filesDeleted > 0 }
}
