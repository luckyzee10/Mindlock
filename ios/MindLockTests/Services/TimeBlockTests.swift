import XCTest
@testable import MindLock

final class TimeBlockTests: XCTestCase {
    func test_TimeBlock_IsActiveOnlyInsideSelectedDayWindow() throws {
        let block = SharedSettings.TimeBlock(
            id: "work",
            name: "Work",
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            daysOfWeek: [3],
            enabled: true
        )

        XCTAssertFalse(block.isActive(on: try date(year: 2026, month: 7, day: 21, hour: 8, minute: 59)))
        XCTAssertTrue(block.isActive(on: try date(year: 2026, month: 7, day: 21, hour: 9, minute: 0)))
        XCTAssertTrue(block.isActive(on: try date(year: 2026, month: 7, day: 21, hour: 12, minute: 30)))
        XCTAssertFalse(block.isActive(on: try date(year: 2026, month: 7, day: 21, hour: 17, minute: 0)))
        XCTAssertFalse(block.isActive(on: try date(year: 2026, month: 7, day: 22, hour: 12, minute: 30)))
    }

    func test_ActiveShieldTokenKeys_ExcludeTemporaryUnlocksFromLimitsAndTimeBlocks() {
        let activeKeys = SharedSettings.activeShieldTokenKeys(
            limitTokenKeys: ["limit-app", "unlocked-limit-app"],
            blockTokenKeys: ["work": ["block-app", "unlocked-block-app"]],
            temporaryUnlockKeys: ["unlocked-limit-app", "unlocked-block-app"]
        )

        XCTAssertEqual(activeKeys, ["limit-app", "block-app"])
    }

    func test_ActiveShieldTokenKeys_KeepsIntendedBlocksAvailableAfterUnlockExpires() {
        let intendedDuringUnlock = SharedSettings.activeShieldTokenKeys(
            limitTokenKeys: [],
            blockTokenKeys: ["work": ["instagram", "tiktok", "youtube"]],
            temporaryUnlockKeys: ["instagram"]
        )

        let intendedAfterUnlock = SharedSettings.activeShieldTokenKeys(
            limitTokenKeys: [],
            blockTokenKeys: ["work": ["instagram", "tiktok", "youtube"]],
            temporaryUnlockKeys: []
        )

        XCTAssertEqual(intendedDuringUnlock, ["tiktok", "youtube"])
        XCTAssertEqual(intendedAfterUnlock, ["instagram", "tiktok", "youtube"])
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) throws -> Date {
        let calendar = Calendar.current
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return try XCTUnwrap(calendar.date(from: components))
    }
}
