import XCTest
@testable import MemoryCleaner

final class MemoryCleanerTests: XCTestCase {

    func testSnapshotHasPositiveTotal() {
        let snap = MemoryMonitor.snapshot()
        XCTAssertGreaterThan(snap.totalBytes, 0)
        XCTAssertLessThanOrEqual(snap.usedBytes, snap.totalBytes)
    }

    func testPressureThresholds() {
        let total: UInt64 = 16_000_000_000
        func snap(used: UInt64) -> MemorySnapshot {
            MemorySnapshot(
                totalBytes: total,
                usedBytes: used,
                freeBytes: total - used,
                wiredBytes: 0,
                inactiveBytes: 0,
                activeBytes: used,
                compressedBytes: 0,
                purgeableBytes: 0,
                appResidentBytes: 50_000_000,
                timestamp: Date()
            )
        }
        XCTAssertEqual(snap(used: 4_000_000_000).pressure, .normal)
        XCTAssertEqual(snap(used: 11_000_000_000).pressure, .elevated)
        XCTAssertEqual(snap(used: 13_500_000_000).pressure, .high)
        XCTAssertEqual(snap(used: 15_000_000_000).pressure, .critical)
    }

    func testByteFormatterNonEmpty() {
        XCTAssertFalse(ByteFormatter.string(from: UInt64(1_073_741_824)).isEmpty)
    }

    func testCleanupResultTotals() {
        let snap = MemorySnapshot(
            totalBytes: 16_000_000_000,
            usedBytes: 12_000_000_000,
            freeBytes: 4_000_000_000,
            wiredBytes: 0,
            inactiveBytes: 0,
            activeBytes: 0,
            compressedBytes: 0,
            purgeableBytes: 0,
            appResidentBytes: 0,
            timestamp: Date()
        )
        let result = CleanupResult(
            before: snap,
            after: snap,
            memoryFreedBytes: 100,
            cacheFreedBytes: 200,
            filesDeleted: 3,
            duration: 1,
            mode: .quick,
            usedAdminPurge: false,
            steps: [],
            summary: "ok"
        )
        XCTAssertEqual(result.totalFreedBytes, 300)
        XCTAssertTrue(result.didImprove)
    }

    func testPressureTitlesInSpanish() {
        XCTAssertEqual(MemoryPressure.normal.titleES, "Normal")
        XCTAssertEqual(MemoryPressure.critical.titleES, "Crítica")
    }
}
