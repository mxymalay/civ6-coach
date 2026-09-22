import XCTest
@testable import CivCoach

final class TurnChangesTests: XCTestCase {
    func testTechUnlockRequiresCompleteInventories() {
        let tech: Record = ["kind": .string("technology_completed"), "type": .string("TECH_WRITING"), "name": .string("文字")]
        let coverage: Record = ["kind": .string("technology_coverage"), "complete": .bool(true)]
        var before = snapshot(1); var after = snapshot(2)
        after.records += [tech, coverage]
        XCTAssertFalse(TurnChanges.compare(before, after).contains { $0.title.contains("科技") })
        before.records.append(coverage)
        XCTAssertTrue(TurnChanges.compare(before, after).contains { $0.title == "科技已解锁：文字" })
        before.records.append(tech)
        XCTAssertFalse(TurnChanges.compare(before, after).contains { $0.title.contains("科技") })
    }
    func snapshot(_ turn: Int, population: Double = 2, housing: Double = 4, production: String = "纪念碑", map: [Record] = [], coverage: Bool = true) -> Snapshot {
        var records: [Record] = [
            ["kind": .string("meta"), "turn": .number(Double(turn)), "player": .number(0), "civilization": .string("测试")],
            ["kind": .string("city"), "id": .number(1), "name": .string("城市"), "population": .number(population), "housing": .number(housing), "production": .string(production)]]
        if coverage { records.append(["kind": .string("map_coverage")]) }
        return Snapshot(records: records, map: map)
    }
    func testFirstPollSameTurnAndRepeatedRefresh() {
        var changes = TurnChanges()
        changes.update(snapshot(3)); XCTAssertTrue(changes.tips.isEmpty)
        changes.update(snapshot(3, population: 3)); XCTAssertNil(changes.fromTurn)
        changes.update(snapshot(4, population: 4, production: "空闲"))
        XCTAssertEqual(changes.fromTurn, 3)
        XCTAssertTrue(changes.tips.contains { $0.title.contains("人口") && $0.detail.contains("3 → 4") })
        let count = changes.tips.count
        changes.update(snapshot(4, population: 4, production: "空闲"))
        XCTAssertEqual(changes.tips.count, count)
        changes.update(snapshot(2)); XCTAssertNil(changes.fromTurn); XCTAssertTrue(changes.tips.isEmpty)
    }
    func testHousingThresholdAndSkippedTurns() {
        var changes = TurnChanges()
        changes.update(snapshot(1)); changes.update(snapshot(4, population: 3))
        XCTAssertEqual(changes.toTurn, 4)
        XCTAssertTrue(changes.tips.contains { $0.title.contains("住房") })
    }
    func testEnemySightingsRequireBothMapsAndOwnerScopedIDs() {
        let enemy: Record = ["kind": .string("visible_unit"), "id": .number(1), "owner": .number(2), "name": .string("战士"), "at_war": .bool(true)]
        XCTAssertTrue(TurnChanges.compare(snapshot(1, coverage: false), snapshot(2, map: [enemy])).isEmpty)
        XCTAssertEqual(TurnChanges.compare(snapshot(1), snapshot(2, map: [enemy])).count, 1)
        XCTAssertTrue(TurnChanges.compare(snapshot(1, map: [enemy]), snapshot(2, map: [enemy])).isEmpty)
    }
    func testAIMapBudgetPreservesUnitsAndDisclosesSampling() throws {
        var map = (0..<800).map { ["kind": JSONValue.string("tile"), "x": .number(Double($0)), "y": .number(0)] }
        map.append(["kind": .string("visible_unit"), "id": .number(7), "at_war": .bool(true)])
        let value = snapshot(2, map: map)
        XCTAssertLessThanOrEqual(value.aiMap.filter { $0.text("kind") == "tile" }.count, 240)
        XCTAssertEqual(value.aiMap.first?.int("id"), 7)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(Snapshot.self, from: Data(value.context.utf8))
        XCTAssertTrue(payload.records.contains { $0.text("kind") == "ai_map_detail" && $0["sampled"]?.flag == true })
        XCTAssertEqual(value.map.count, 801, "AI sampling must not destroy local observations")
    }
}
