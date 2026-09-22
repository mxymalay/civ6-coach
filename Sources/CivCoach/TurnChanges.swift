import Foundation

struct TurnChanges {
    private var latest: Snapshot?
    private var baseline: Snapshot?
    private(set) var fromTurn: Int?
    private(set) var toTurn: Int?
    private(set) var tips: [Tip] = []

    mutating func update(_ current: Snapshot) {
        guard let previous = latest, previous.identity == current.identity, current.turn >= previous.turn else {
            latest = current; baseline = nil; fromTurn = nil; toTurn = nil; tips = []; return
        }
        if current.turn > previous.turn { baseline = previous }
        latest = current
        guard let baseline else { return }
        fromTurn = baseline.turn; toTurn = current.turn
        tips = Self.compare(baseline, current)
    }
    static func compare(_ old: Snapshot, _ new: Snapshot) -> [Tip] {
        var result: [Tip] = []
        if old.records.contains(where: { $0.text("kind") == "technology_coverage" }), new.records.contains(where: { $0.text("kind") == "technology_coverage" }) {
            let known = Set(old.records.filter { $0.text("kind") == "technology_completed" }.map { $0.text("type") })
            for tech in new.records where tech.text("kind") == "technology_completed" && !known.contains(tech.text("type")) {
                result.append(Tip(icon: "flask", title: "科技已解锁：\(tech.text("name"))", detail: "相比上次观察，已掌握科技列表新增此项。检查新解锁的生产与研究选择。"))
            }
        }
        let cities = old.cities.reduce(into: [Int: Record]()) { if let id = $1.int("id") { $0[id] = $1 } }
        for city in new.cities {
            guard let id = city.int("id") else { continue }
            let name = city.text("name")
            guard let before = cities[id] else {
                result.append(Tip(icon: "building.2", title: "新增城市：\(name)", detail: "当前城市列表新增此城；可能是建城或获得城市，请检查生产与住房。")); continue
            }
            if let a = before.int("population"), let b = city.int("population"), a != b {
                result.append(Tip(icon: "person.2", title: "\(name)人口变化", detail: "\(a) → \(b)，检查市民分配、粮食和住房。"))
            }
            if let a = before["production"]?.text, let b = city["production"]?.text, a != b {
                result.append(Tip(icon: "hammer", title: "\(name)生产变化", detail: "\(a) → \(b)。可能已完成或手动换项，不能仅凭队列变化确认完成。", urgent: b == "空闲"))
            }
            if let a = before.number("housing"), let ap = before.number("population"),
               let b = city.number("housing"), let bp = city.number("population"), a - ap > 1, b - bp <= 1 {
                result.append(Tip(icon: "house", title: "\(name)住房趋紧", detail: "人口 \(Int(bp)) / 住房 \(city.display("housing"))，增长空间已不足两点。"))
            }
        }
        if let a = old.economy.number("gold_net_per_turn"), let b = new.economy.number("gold_net_per_turn"), a >= 0, b < 0 {
            result.append(Tip(icon: "creditcard", title: "金币净收入转负", detail: "每回合 \(a) → \(b)，检查维护费与贸易。", urgent: true))
        }
        // Only compare enemy sightings when both snapshots actually collected maps.
        if old.hasMapCoverage && new.hasMapCoverage {
            let known = Set(old.map.filter { $0.text("kind") == "visible_unit" && $0["at_war"]?.flag == true }.map { $0.display("owner") + ":" + $0.display("id") })
            for unit in new.map where unit.text("kind") == "visible_unit" && unit["at_war"]?.flag == true {
                let id = unit.display("owner") + ":" + unit.display("id")
                if !known.contains(id) {
                    result.append(Tip(icon: "exclamationmark.shield", title: "新观察到敌军：\(unit.text("name"))（\(id)）", detail: "坐标 \(unit.display("x")), \(unit.display("y"))。此前未记录不代表刚生成或刚入侵。", urgent: true))
                }
            }
        }
        return Array(result.sorted { ($0.urgent ? 0 : 1) < ($1.urgent ? 0 : 1) }.prefix(12))
    }
}
