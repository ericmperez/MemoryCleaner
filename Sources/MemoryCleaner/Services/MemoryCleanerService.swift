import Foundation
import Darwin.malloc

/// Limpia cachés del usuario + libera memoria inactiva en esta Mac.
@MainActor
final class MemoryCleanerService: ObservableObject {
    @Published private(set) var snapshot: MemorySnapshot
    @Published private(set) var isCleaning = false
    @Published private(set) var lastResult: CleanupResult?
    @Published private(set) var progress: Double = 0
    @Published private(set) var statusMessage: String = "Pulsa Liberar para empezar"
    @Published private(set) var liveLog: [String] = []
    @Published var lastError: String?

    private var refreshTimer: Timer?

    init() {
        snapshot = MemoryMonitor.snapshot()
        startAutoRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func refresh() {
        snapshot = MemoryMonitor.snapshot()
    }

    /// Ejecuta limpieza. `mode: .deep` pide contraseña de admin para `purge`.
    func clean(mode: CleanupMode) async -> CleanupResult? {
        guard !isCleaning else { return lastResult }

        isCleaning = true
        progress = 0
        lastError = nil
        lastResult = nil
        liveLog = []
        statusMessage = "Analizando memoria…"
        log("Inicio — modo \(mode == .deep ? "profundo" : "rápido")")

        let before = MemoryMonitor.snapshot()
        snapshot = before
        log("RAM antes: \(ByteFormatter.string(from: before.usedBytes)) en uso · \(ByteFormatter.string(from: before.freeBytes)) disponible")
        let start = Date()
        var usedAdmin = false
        var steps: [CleanupStep] = []
        var cacheBytes: Int64 = 0
        var filesDeleted = 0

        // 1) Borrar cachés / archivos de memoria en disco
        progress = 0.15
        statusMessage = "Borrando archivos de caché…"
        log("Borrando cachés de usuario (Library/Caches, logs, temp)…")

        let cacheReport = await Task.detached(priority: .userInitiated) {
            CacheCleaner.cleanUserCaches()
        }.value

        cacheBytes = cacheReport.bytesDeleted
        filesDeleted = cacheReport.filesDeleted
        let cacheDetail = cacheReport.foldersTouched.isEmpty
            ? "Nada que borrar o sin permiso"
            : "\(cacheReport.foldersTouched.prefix(8).joined(separator: ", "))\(cacheReport.foldersTouched.count > 8 ? "…" : "")"

        steps.append(CleanupStep(
            title: "Archivos de caché",
            detail: "\(filesDeleted) ítems · \(ByteFormatter.string(from: cacheBytes)) · \(cacheDetail)",
            bytesFreed: cacheBytes,
            ok: true
        ))
        log("Caché: \(filesDeleted) ítems, \(ByteFormatter.string(from: cacheBytes)) liberados en disco")
        for note in cacheReport.notes.prefix(5) {
            log("· \(note)")
        }

        // 2) Presión de RAM
        progress = 0.4
        statusMessage = "Liberando memoria inactiva (RAM)…"
        log("Aplicando presión de memoria…")
        await performPressureRelease()
        steps.append(CleanupStep(
            title: "Presión de RAM",
            detail: "Páginas inactivas/purgables reclamadas",
            bytesFreed: 0,
            ok: true
        ))

        progress = 0.55
        statusMessage = "Aliviando zonas malloc…"
        await Task.detached(priority: .userInitiated) {
            Self.mallocPressureRelief()
        }.value
        URLCache.shared.removeAllCachedResponses()
        steps.append(CleanupStep(
            title: "Caché de red de la app",
            detail: "URLCache vaciado",
            bytesFreed: 0,
            ok: true
        ))
        log("URLCache y malloc relief listos")

        // 3) purge del sistema (opcional)
        if mode == .deep {
            progress = 0.65
            statusMessage = "Purga del sistema (contraseña)…"
            log("Ejecutando /usr/sbin/purge (admin)…")
            do {
                try await Shell.runPurgeWithAdmin()
                usedAdmin = true
                steps.append(CleanupStep(
                    title: "Purga del sistema",
                    detail: "purge ejecutado con privilegios de administrador",
                    bytesFreed: 0,
                    ok: true
                ))
                log("purge OK")
            } catch ShellError.cancelled {
                lastError = "Cancelaste la contraseña. Se aplicó la limpieza de cachés y RAM sin purge."
                steps.append(CleanupStep(
                    title: "Purga del sistema",
                    detail: "Cancelada por el usuario",
                    bytesFreed: 0,
                    ok: false
                ))
                log("purge cancelado")
            } catch {
                lastError = error.localizedDescription
                steps.append(CleanupStep(
                    title: "Purga del sistema",
                    detail: error.localizedDescription,
                    bytesFreed: 0,
                    ok: false
                ))
                log("purge error: \(error.localizedDescription)")
            }
        }

        progress = 0.9
        statusMessage = "Midiendo resultado…"
        try? await Task.sleep(nanoseconds: 600_000_000)
        await Task.yield()
        try? await Task.sleep(nanoseconds: 400_000_000)

        let after = MemoryMonitor.snapshot()
        snapshot = after

        let freeDelta = Int64(after.freeBytes) - Int64(before.freeBytes)
        let usedDelta = Int64(before.usedBytes) - Int64(after.usedBytes)
        let inactiveDelta = Int64(before.inactiveBytes) - Int64(after.inactiveBytes)
        let memoryFreed = max(freeDelta, usedDelta, inactiveDelta, 0)

        log("RAM después: \(ByteFormatter.string(from: after.usedBytes)) en uso · \(ByteFormatter.string(from: after.freeBytes)) disponible")
        if memoryFreed > 0 {
            log("RAM liberada (estimada): \(ByteFormatter.string(from: memoryFreed))")
        } else {
            log("RAM: sin cambio grande (macOS retiene cachés útiles en RAM)")
        }

        let summary: String
        if cacheBytes > 0 || memoryFreed > 0 {
            var parts: [String] = []
            if cacheBytes > 0 {
                parts.append("\(ByteFormatter.string(from: cacheBytes)) en archivos")
            }
            if memoryFreed > 0 {
                parts.append("\(ByteFormatter.string(from: memoryFreed)) en RAM")
            }
            summary = "Liberado: " + parts.joined(separator: " + ")
        } else if filesDeleted > 0 {
            summary = "Se borraron \(filesDeleted) ítems (tamaño ya era pequeño)"
        } else {
            summary = "No había cachés grandes que borrar. Cierra apps pesadas si la RAM sigue llena."
        }

        let result = CleanupResult(
            before: before,
            after: after,
            memoryFreedBytes: memoryFreed,
            cacheFreedBytes: cacheBytes,
            filesDeleted: filesDeleted,
            duration: Date().timeIntervalSince(start),
            mode: mode,
            usedAdminPurge: usedAdmin,
            steps: steps,
            summary: summary
        )
        lastResult = result
        progress = 1
        statusMessage = summary
        log("Listo en \(String(format: "%.1f", result.duration))s")

        isCleaning = false
        return result
    }

    // MARK: - Internals

    private func log(_ line: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        liveLog.append("[\(stamp)] \(line)")
        // Keep last ~40 lines
        if liveLog.count > 40 {
            liveLog.removeFirst(liveLog.count - 40)
        }
    }

    private func performPressureRelease() async {
        await Task.detached(priority: .userInitiated) {
            Self.allocateAndRelease()
        }.value
    }

    nonisolated private static func mallocPressureRelief() {
        _ = malloc_zone_pressure_relief(nil, 0)
    }

    nonisolated private static func allocateAndRelease() {
        let physical = ProcessInfo.processInfo.physicalMemory
        let target = min(physical * 35 / 100, 1536 * 1024 * 1024)
        let chunkSize = 2 * 1024 * 1024
        let maxChunks = Int(target / UInt64(chunkSize))

        var blocks: [UnsafeMutableRawPointer] = []
        blocks.reserveCapacity(maxChunks)

        for i in 0..<maxChunks {
            guard let ptr = malloc(chunkSize) else { break }
            memset(ptr, Int32(i & 0xFF), 4096)
            ptr.advanced(by: chunkSize - 1).storeBytes(of: 0xCD, as: UInt8.self)
            blocks.append(ptr)
            if i % 16 == 0 {
                Thread.sleep(forTimeInterval: 0.001)
            }
        }

        for ptr in blocks.reversed() {
            free(ptr)
        }
        blocks.removeAll(keepingCapacity: false)
        _ = malloc_zone_pressure_relief(nil, 0)
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isCleaning else { return }
                self.refresh()
            }
        }
    }
}
