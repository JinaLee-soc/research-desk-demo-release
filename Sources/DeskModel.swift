import Foundation
import CryptoKit

let deskStages = ["Planning", "Data collection", "Analysis", "Abstract", "Figures", "Draft", "Polish", "Submission", "Revision", "Resubmission", "Published"]
let deskCategories = ["R&R", "Grants & fellowships", "Special issue", "Conference", "Peer review", "Other"]

struct DeskProject: Codable, Identifiable {
    var id: String
    var title: String
    var journal: String
    var alternate: String
    var role: String
    var originalStatus: String
    var originalDue: String
    var sourceRow: Int
    var steps: [Bool?]
    var included: Bool
    var priority: Bool
    var focusStep: Int?
    var nextAction: String
    var wiki: String
    var state: String
    var note: String
    var score: Int? { included && steps.allSatisfy { $0 != nil } ? steps.filter { $0 == false }.count : nil }
}
struct DeskPlan: Codable, Identifiable {
    var lane: String? = nil
    var id: String
    var kind: String
    var period: String
    var text: String
    var original: String
    var source: String
    var state: String
}
struct DeskHistory: Codable, Identifiable {
    var id: String
    var date: String
    var priorityTotal: Int
    var priorityMean: Double
    var total: Int
    var mean: Double
    var source: String
}
struct DeadlineSettings: Codable {
    var category: Int
    var priority: Int?
    var participation: String
    var completed: Bool
    var projectID: String
    var nextAction: String
    var critical: Bool
    var criticalReason: String
    var timeZone: String
    var snoozedUntil: String?
    var hiddenUntil: String?
    static func initial(_ d: Deadline) -> DeadlineSettings {
        let category = DeadlineModel.rank(d, priorities: [:], sort: "category")
        return .init(category: category, priority: nil, participation: [1,5].contains(category) ? "committed" : "considering", completed: false,
                     projectID: "", nextAction: "", critical: false, criticalReason: "", timeZone: "")
    }
}
struct DeskEvent: Codable, Identifiable {
    var id: String
    var at: String
    var actor: String
    var kind: String
    var target: String
    var summary: String
    var step: Int?
    var before: Bool?
    var after: Bool?
    var undone: Bool = false
}
struct DeskFocus: Codable {
    var projectID: String
    var declaredAt: String
    var until: String
}
struct DeskSettings: Codable {
    var reminders: Bool
    var urgentDays: Int
    var quietStart: Int
    var quietEnd: Int
    var alwaysOnTop: Bool
    var sort: String
    var lastMorning: String
    var lastNotificationKey: String
}
struct DeskResearchNote: Codable, Identifiable {
    var id: String
    var projectID: String
    var kind: String
    var text: String
    var source: String
    var locator: String
    var createdAt: String
    var shared: Bool
}

enum DeskNotes {
    static func append(_ body: [String:Any], id: String, projectID: String, shared: Bool, to state: inout DeskData) throws {
        guard UUID(uuidString:id) != nil,
              Set(body.keys).isSubset(of:["text","kind","source","locator"]),
              let text=body["text"] as? String, !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
              text.utf8.count <= 20000,
              let kind=body["kind"] as? String, ["thought","excerpt","ai"].contains(kind),
              let source=body["source"] as? String, source.utf8.count <= 2000,
              let locator=body["locator"] as? String, locator.utf8.count <= 500,
              projectID.isEmpty || state.projects.contains(where:{$0.id==projectID}),
              kind == "thought" || !source.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
              kind != "excerpt" || !locator.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
        else { throw ModelError.message("Check the note, type and project. Excerpts need a source and location; AI suggestions need a source.") }
        if let previous=(state.researchNotes ?? []).first(where:{$0.id==id}) {
            guard previous.text==text,previous.projectID==projectID,previous.kind==kind,previous.source==source,previous.locator==locator,previous.shared==shared else { throw ModelError.message("This note ID has different content.") }
            return
        }
        state.researchNotes=(state.researchNotes ?? []) + [.init(id:id,projectID:projectID,kind:kind,text:text,source:source,locator:locator,createdAt:DeskCodec.iso(),shared:shared)]
    }
}

// Rewards share the same atomic save as their source records.
struct DeskReward: Codable {
    var id: String
    var projectID: String
    var eventID: String
    var step: Int?
    var points: Int
}
struct DeskRewards: Codable {
    var baselineStages: [String]
    var entries: [DeskReward]
    var bonusBaselineActivities: [String]? = nil
    var shownDecorations: [String]? = nil
    var rewardStartDay: String? = nil
    static func stageKey(_ project: String, _ step: Int) -> String { "stage:" + project + ":" + String(step) }
    static func recording(from old: DeskData, to next: DeskData) -> DeskRewards {
        if next.rewards?.rewardStartDay != nil && next.rewards?.rewardStartDay != old.rewards?.rewardStartDay { return next.rewards! }
        var result = old.rewards ?? .init(baselineStages: old.projects.flatMap { p in
            p.steps.indices.filter { p.steps[$0] == true }.map { stageKey(p.id, $0) }
        }, entries: [])
        if result.bonusBaselineActivities == nil { result.bonusBaselineActivities = old.events.map(\.id) }
        result.shownDecorations = next.rewards?.shownDecorations ?? result.shownDecorations
        let previous = Set(old.events.map(\.id))
        for e in next.events where !previous.contains(e.id) && e.actor == "user" && !e.undone {
            if e.kind == "activity", !e.summary.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
               next.projects.contains(where: { $0.id == e.target }) {
                // Preserve already-earned rewards; cap new activity awards by Chicago date.
                guard let date=DeskCodec.instant(e.at) else { continue }
                let day=DeskCodec.day(date,calendar:rewardCalendar)
                let rewarded=result.entries.filter { reward in
                    guard reward.step == nil, reward.projectID == e.target,
                          let source=next.events.first(where:{$0.id==reward.eventID}),
                          let at=DeskCodec.instant(source.at) else { return false }
                    return DeskCodec.day(at,calendar:rewardCalendar)==day
                }.count
                if rewarded < 3 && !result.entries.contains(where:{$0.eventID==e.id}) { result.entries.append(.init(id:"activity:" + e.id, projectID:e.target, eventID:e.id, step:nil, points:10)) }
            } else if e.kind == "step-value", let step = e.step, (0..<11).contains(step), e.after == true {
                let key = stageKey(e.target, step)
                if !result.baselineStages.contains(key) && !result.entries.contains(where: { $0.id == key }) {
                    result.entries.append(.init(id:key, projectID:e.target, eventID:e.id, step:step, points:30))
                }
            }
        }
        return result
    }
    static func backfilled(_ state: DeskData, start: String, now: Date = Date()) -> DeskRewards {
        let eligible=state.events.enumerated().filter { _,e in
            guard let at=DeskCodec.instant(e.at) else { return false }
            return DeskCodec.day(at,calendar:rewardCalendar)>=start && at<=now
        }.sorted { $0.element.at == $1.element.at ? $0.offset < $1.offset : $0.element.at < $1.element.at }.map(\.element)
        var initial=state.projects
        for e in eligible.reversed() where e.kind == "step-value" && !e.undone {
            if let step=e.step,(0..<11).contains(step),let i=initial.firstIndex(where:{$0.id==e.target}) { initial[i].steps[step]=e.before }
        }
        var rewards=state.rewards ?? .init(baselineStages:[],entries:[])
        rewards.baselineStages=initial.flatMap { p in p.steps.indices.filter{p.steps[$0]==true}.map{stageKey(p.id,$0)} }
        let ids=Set(eligible.map(\.id))
        rewards.bonusBaselineActivities=state.events.filter{!ids.contains($0.id)}.map(\.id)
        rewards.rewardStartDay=start
        var cursor=state;cursor.events=state.events.filter{!ids.contains($0.id)};cursor.rewards=rewards
        for e in eligible { let old=cursor;cursor.events.append(e);cursor.rewards=recording(from:old,to:cursor) }
        return cursor.rewards!
    }
    func summary(in state: DeskData) -> [String:Any] { expandedSummary(in:state) }

}

struct DeskData: Codable {
    var schema: Int
    var revision: String
    var updatedAt: String
    var sourceSHA256: String
    var importedAt: String
    var projects: [DeskProject]
    var plans: [DeskPlan]
    var history: [DeskHistory]
    var deadlineSettings: [String: DeadlineSettings]
    var events: [DeskEvent]
    var focus: DeskFocus?
    var pinnedProjectID: String
    var settings: DeskSettings
    var migrationNotes: [String]
    // Atomically persisted with phone edits; never part of the cloud projection.
    var cloudReceipts: [String: String]? = nil
    var researchNotes: [DeskResearchNote]? = nil
    var rewards: DeskRewards? = nil
    var timeRewards: DeskTimeRewards? = nil
    var collectibles: DeskCollectibles? = nil
    func validate() throws {
        guard schema == 1 else { throw ModelError.message("Unsupported Desk record version.") }
        for ids in [projects.map(\.id), plans.map(\.id), history.map(\.id), events.map(\.id)] {
            guard Set(ids).count == ids.count, ids.allSatisfy({ !$0.isEmpty }) else { throw ModelError.message("Desk Record IDs are duplicated or empty.") }
        }
        if let timeRewards { try timeRewards.validate() }
        if let collectibles { try collectibles.validate() }
        if let rewards {
            guard Set(rewards.shownDecorations ?? []).isSubset(of:Set(DeskDecoration.all.map(\.id))),
                  Set(rewards.entries.map(\.id)).count == rewards.entries.count,
                  rewards.entries.allSatisfy({ r in
                      if let step = r.step { return (0..<11).contains(step) && r.points == 30 && r.id == DeskRewards.stageKey(r.projectID, step) }
                      return r.points == 10 && r.id == "activity:" + r.eventID
                  }) else { throw ModelError.message("Check the experience record format.") }
        }
        let notes=researchNotes ?? []
        guard Set(notes.map(\.id)).count==notes.count else { throw ModelError.message("Duplicate note ID.") }
        for n in notes {
            guard UUID(uuidString:n.id) != nil,["thought","excerpt","ai"].contains(n.kind),!n.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,n.text.utf8.count<=20000,n.source.utf8.count<=2000,n.locator.utf8.count<=500,
                  n.projectID.isEmpty || projects.contains(where:{$0.id==n.projectID}),
                  n.kind=="thought" || !n.source.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
                  n.kind != "excerpt" || !n.locator.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
            else { throw ModelError.message("Check the saved research-note format.") }
        }
        for p in projects {
            guard !p.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, p.steps.count == 11,
                  !p.priority || p.included, !p.included || p.steps.allSatisfy({ $0 != nil }),
                  p.focusStep == nil || (0..<11).contains(p.focusStep!) else { throw ModelError.message("Check paper stages and score settings: \(p.title)") }
        }
        for d in deadlineSettings.values {
            guard (1...6).contains(d.category), d.priority == nil || (1...6).contains(d.priority!),
                  ["considering","committed","declined","waiting"].contains(d.participation),
                  !d.critical || !d.criticalReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  d.timeZone.isEmpty || TimeZone(identifier: d.timeZone) != nil else { throw ModelError.message("Check deadline category, participation, priority reason and time zone.") }
        }
        guard (1...30).contains(settings.urgentDays), (0...23).contains(settings.quietStart), (0...23).contains(settings.quietEnd) else { throw ModelError.message("Check the assistant settings range.") }
    }
    var totals: [String: Double] {
        let included = projects.filter { $0.included }, priority = included.filter { $0.priority }
        let total = included.compactMap(\.score).reduce(0,+), pt = priority.compactMap(\.score).reduce(0,+)
        return ["total": Double(total), "priorityTotal": Double(pt), "mean": included.isEmpty ? 0 : Double(total)/Double(included.count),
                "priorityMean": priority.isEmpty ? 0 : Double(pt)/Double(priority.count), "count": Double(included.count), "priorityCount": Double(priority.count)]
    }
}

enum DeskCodec {
    static let marker = "<!-- desk-data:start -->"
    static let end = "<!-- desk-data:end -->"
    static func iso(_ date: Date = Date()) -> String { ISO8601DateFormatter().string(from: date) }
    static func instant(_ text: String?) -> Date? { text.flatMap { ISO8601DateFormatter().date(from: $0) } }
    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year,.month,.day], from: date)
        return String(format:"%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func encode<T: Encodable>(_ object: T) throws -> Data { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]; return try e.encode(object) }
    static func read(_ bytes: Data) throws -> DeskData {
        guard let text = String(data: bytes, encoding: .utf8), let start = text.range(of: marker + "\n```json\n"), let finish = text.range(of: "\n```\n" + end, range: start.upperBound..<text.endIndex),
              let json = String(text[start.upperBound..<finish.lowerBound]).data(using: .utf8) else { throw ModelError.message("Desk.mddesk-data JSON could not be read. Keeping the last valid record.") }
        let result = try JSONDecoder().decode(DeskData.self, from: json); try result.validate(); return result
    }
    static func markdown(_ data: DeskData) throws -> Data {
        let json = String(data: try encode(data), encoding: .utf8)!
        let text = """
        ---
        type: research-desk-manual
        schema: 1
        ---
        # Research Desk Demo

        [[Root/Home|Wiki home]] · [[Root/Deadlines|Deadline source]] · [[Planning/Activity|Work record]] · [[Root/Portfolio|Current progress]]

        Editable source shared by the demo app and wiki. Preserve stable IDs when editing JSON.
        Refresh the app after editing JSON. Current score summary: [[Root/Portfolio]]available here.
        - One remaining stage = 1points. Separate from verification, adoption and manuscript changes.

        \(marker)
        ```json
        \(json)
        ```
        \(end)
        """
        return Data((text + "\n").utf8)
    }
    static func replacing(_ data: DeskData, in original: Data) throws -> Data {
        guard var text = String(data:original,encoding:.utf8), let a = text.range(of:marker+"\n```json\n"), let b = text.range(of:"\n```\n"+end,range:a.upperBound..<text.endIndex) else { throw ModelError.message("Planning JSON block not found.") }
        text.replaceSubrange(a.upperBound..<b.lowerBound,with:String(data:try encode(data),encoding:.utf8)!)
        return Data(text.utf8)
    }
    static func addStableIDs(_ text: String) throws -> String {
        let items = try DeadlineModel.parse(text)
        var result = text
        for item in items where item.stableID == nil {
            let id = "deadline-" + hash(Data(item.title.utf8)).prefix(16)
            let needle = "| \(item.title) |"
            guard result.components(separatedBy: needle).count == 2 else { throw ModelError.message("Could not safely assign an event ID: \(item.title)") }
            result = result.replacingOccurrences(of: needle, with: "| \(item.title) <!-- desk-id: \(id) --> |")
        }
        _ = try DeadlineModel.parse(result); return result
    }
    static func deadlineTable(_ records: [Deadline], in text: String) throws -> String {
        var lines = text.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.hasPrefix("| Due date |") }) else { throw ModelError.message("Deadline table not found.") }
        var end = start + 1
        while end < lines.count && lines[end].hasPrefix("|") { end += 1 }
        func cell(_ s: String) -> String { s.replacingOccurrences(of:"\r",with:"").replacingOccurrences(of:"\n",with:"<br>") }
        let rows = records.sorted { $0.isoDate == $1.isoDate ? $0.id < $1.id : $0.isoDate < $1.isoDate }.map {
            "| \($0.isoDate) | \(cell($0.time)) | \(cell($0.title)) <!-- desk-id: \($0.id) --> | \(cell($0.detail)) |"
        }
        lines.replaceSubrange((start+2)..<end, with: rows)
        let result = lines.joined(separator:"\n"); _ = try DeadlineModel.parse(result); return result
    }
}

/// Optimistic concurrency + coordinated atomic replace. Backups never overwrite previous revisions.
final class DeskFile {
    let url: URL
    let backupRoot: URL
    var observed: Data?
    init(_ url: URL, backupRoot: URL) { self.url = url; self.backupRoot = backupRoot }
    func load() throws -> Data {
        guard !((try? url.resourceValues(forKeys:[.isSymbolicLinkKey]).isSymbolicLink) ?? false) else { throw ModelError.message("Planning-source symbolic links are not supported.") }
        let bytes = try Data(contentsOf:url); observed = bytes; return bytes
    }
    func save(_ bytes: Data, creating: Bool = false) throws {
        var coordinationError: NSError?, failure: Error?
        let expected = observed
        let coordinator = NSFileCoordinator(filePresenter:nil)
        coordinator.coordinate(writingItemAt:url, options:[], error:&coordinationError) { target in
            do {
                let exists = FileManager.default.fileExists(atPath: target.path)
                let current = exists ? try Data(contentsOf:target) : nil
                guard (creating && !exists && expected == nil) || (!creating && current == expected && expected != nil) else {
                    throw ModelError.message("Externally, \(url.lastPathComponent)was modified elsewhere. Nothing was overwritten. Refresh and try again.")
                }
                if let current {
                    try FileManager.default.createDirectory(at:backupRoot,withIntermediateDirectories:true)
                    let backup = backupRoot.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
                    try current.write(to:backup,options:.withoutOverwriting)
                }
                try bytes.write(to:target,options:.atomic)
            } catch { failure = error }
        }
        if let error = coordinationError { throw error }; if let error = failure { throw error }; observed = bytes
    }
}

struct DeskAdvice: Codable {
    var id: String
    var title: String
    var message: String
    var nextAction: String
    var evidence: [String]
    var mood: String
    var deadlineID: String
    var urgent: Bool
}
enum DeskAssistant {
    static func quiet(_ settings: DeskSettings, now: Date, calendar: Calendar = .current) -> Bool {
        let h = calendar.component(.hour,from:now)
        if settings.quietStart == settings.quietEnd { return false }
        return settings.quietStart < settings.quietEnd ? h >= settings.quietStart && h < settings.quietEnd : h >= settings.quietStart || h < settings.quietEnd
    }
    static func advice(_ data: DeskData, deadlines: [Deadline], now: Date, calendar: Calendar = .current) -> DeskAdvice {
        let today = calendar.startOfDay(for:now), month = calendar.date(byAdding:.month,value:1,to:today)!
        let possible = deadlines.filter { d in
            let meta = data.deadlineSettings[d.id] ?? .initial(d)
            return !meta.completed && meta.participation != "declined" && d.date <= month &&
                (DeskCodec.instant(meta.snoozedUntil) ?? .distantPast) <= now && (DeskCodec.instant(meta.hiddenUntil) ?? .distantPast) <= now
        }.sorted { a,b in
            let x = data.deadlineSettings[a.id] ?? .initial(a), y = data.deadlineSettings[b.id] ?? .initial(b)
            // Imminent/overdue obligations receive a separate reminder, never a reordered base list.
            let da = calendar.dateComponents([.day],from:today,to:a.date).day!, db = calendar.dateComponents([.day],from:today,to:b.date).day!
            let ua = da <= data.settings.urgentDays && x.participation == "committed", ub = db <= data.settings.urgentDays && y.participation == "committed"
            if ua != ub { return ua }
            if ua && x.critical != y.critical { return x.critical }
            if (x.priority ?? x.category) != (y.priority ?? y.category) { return (x.priority ?? x.category) < (y.priority ?? y.category) }
            return a.date == b.date ? a.id < b.id : a.date < b.date
        }
        guard let d = possible.first else {
            return .init(id:"quiet",title:"Here when you need me",message:"No deadline needs another reminder. Choose today’s focus and next action.",nextAction:"Choose focus task",evidence:["Current deadlines, accounting for completion, declined items, snoozing and hiding"],mood:"idle",deadlineID:"",urgent:false)
        }
        let m = data.deadlineSettings[d.id] ?? .initial(d), days = calendar.dateComponents([.day],from:today,to:d.date).day!
        let label = days < 0 ? "\(-days)days overdue" : days == 0 ? "Due today" : "D−\(days)"
        let name = DeadlineModel.shortTitle(d)
        var message = "\(name), \(label)."
        var next = m.nextAction
        var evidence = ["Demo deadline \(d.isoDate) · \(d.time) · Time zone \(m.timeZone.isEmpty ? "Unconfirmed" : m.timeZone)","Source: Research Wiki/Root/Deadlines.md", "Category: \(deskCategories[m.category-1]) · Participation: \(m.participation)"]
        if m.participation == "considering" {
            message += " First decide whether to apply. Listing an opportunity is not a commitment."
            if next.isEmpty { next = d.title.contains("CAS Fellows") ? "Check application and nomination options" : "Decide whether to apply or submit" }
        } else if m.participation == "waiting" {
            message += " If you are waiting on someone, check what follow-up you can do now."
            if next.isEmpty { next = "Check pending prerequisites" }
        } else {
            if m.critical {
                message += " You marked this deadline as career-critical. Let’s check it first."
                evidence.append("User’s priority reason: " + m.criticalReason)
            } else if days <= data.settings.urgentDays {
                message += m.category == 5 ? " Reviews have lower priority, but a committed deadline still matters." : "It’s time to prepare this submission."
            } else { message += " Choose a next action for this deadline." }
            if let f = data.focus, let until = DeskCodec.instant(f.until), until > now, !m.projectID.isEmpty, f.projectID != m.projectID, days <= data.settings.urgentDays {
                message += " Check this deadline before the selected task."
                evidence.append("Declared current focus: \(f.projectID) · \(f.declaredAt)from \(f.until)until")
            }
            if next.isEmpty { next = m.category == 5 ? "Check review submission" : "Check remaining deliverables" }
        }
        if days < 0 { message += " Update the record if already submitted or extended." }
        return .init(id:d.id+":"+label+":"+m.participation,title:name+" · "+label,message:message,nextAction:next,evidence:evidence,
                     mood:m.critical ? "critical" : (days <= data.settings.urgentDays ? "wave" : "idle"),deadlineID:d.id,urgent:days <= data.settings.urgentDays)
    }
}

struct DeskDecoration {
    let id: String
    let name: String
    let level: Int
    static let all: [DeskDecoration] = [
        .init(id:"plant",name:"Flower vase",level:2), .init(id:"flowers",name:"Books",level:4),
        .init(id:"poster",name:"Noticeboard",level:6), .init(id:"coffee",name:"Floor lamp",level:8),
        .init(id:"sofa",name:"Armchair",level:10)
    ]
}
private struct RewardTransaction {
    var id: String
    var project: String
    var at: Date
    var points: Int
    var kind: String
    var streak: Int = 0
}
extension DeskRewards {
    static var rewardCalendar: Calendar {
        var c = Calendar(identifier:.gregorian); c.timeZone = TimeZone(identifier:"America/Chicago")!; return c
    }
    func expandedSummary(in state: DeskData, now: Date = Date()) -> [String:Any] {
        let c = Self.rewardCalendar
        func day(_ date: Date) -> String { DeskCodec.day(date,calendar:c) }
        func month(_ date: Date) -> String { String(day(date).prefix(7)) }
        let projects = Dictionary(uniqueKeysWithValues:state.projects.map { ($0.id,$0) })
        let events = Dictionary(uniqueKeysWithValues:state.events.map { ($0.id,$0) })
        var transactions: [RewardTransaction] = []
        for r in entries {
            guard let p=projects[r.projectID],let source=events[r.eventID],let date=DeskCodec.instant(source.at), date<=now else { continue }
            let active: Bool
            if let step=r.step { active=p.steps[step] == true }
            else { active=source.kind=="activity" && !source.undone && !source.summary.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty }
            if active { transactions.append(.init(id:r.id,project:r.projectID,at:date,points:r.points,kind:"base")) }
        }
        let excluded = Set(bonusBaselineActivities ?? state.events.map(\.id))
        let work = state.events.filter { $0.actor=="user" && $0.kind=="activity" && !$0.undone && projects[$0.target] != nil && !$0.summary.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && (DeskCodec.instant($0.at) ?? .distantFuture) <= now }.enumerated().sorted { $0.element.at == $1.element.at ? $0.offset < $1.offset : $0.element.at < $1.element.at }.map(\.element)
        var streaks: [String:[String:Any]] = [:]
        var monthlyLongest: [String:Int] = [:]
        for p in state.projects {
            var previous: Date?, lastStreakDay: Date?, run=0, best=0, start=""
            for e in work where e.target==p.id {
                guard let date=DeskCodec.instant(e.at) else { continue }
                let dateDay=c.startOfDay(for:date)
                if !excluded.contains(e.id) {
                    if let previous, (c.dateComponents([.day],from:previous,to:dateDay).day ?? 0) >= 15 {
                        transactions.append(.init(id:"comeback:"+e.id,project:p.id,at:date,points:20,kind:"comeback"))
                    }
                    if dateDay != lastStreakDay {
                        let consecutive = lastStreakDay.map { c.dateComponents([.day],from:$0,to:dateDay).day == 1 } ?? false
                        run=consecutive ? run+1 : 1
                        if !consecutive { start=day(date) }
                        lastStreakDay=dateDay; best=max(best,run)
                        monthlyLongest[month(date)] = max(monthlyLongest[month(date)] ?? 0,run)
                        let bonus=run==3 ? 15 : run==5 ? 25 : (run>=7 && run%7==0 ? 40 : 0)
                        if bonus>0 { transactions.append(.init(id:"streak:"+p.id+":"+start+":"+String(run),project:p.id,at:date,points:bonus,kind:"streak",streak:run)) }
                    }
                }
                previous=dateDay
            }
            let age=lastStreakDay.map { c.dateComponents([.day],from:$0,to:c.startOfDay(for:now)).day ?? 0 } ?? 999
            streaks[p.id] = ["current":age<=1 ? run : 0,"best":best]
        }
        if let time=state.timeRewards {
            for (date,minutes) in time.minutesByDay where date>=time.startDay && minutes>=DeskTimeRewards.thresholdMinutes {
                if let at=DeskTimeRewards.date(date),at<=now { transactions.append(.init(id:"research-time:"+date,project:"",at:at,points:20,kind:"time")) }
            }
        }
        transactions.sort { $0.at == $1.at ? $0.id < $1.id : $0.at < $1.at }
        var byProject: [String:Int]=[:], total=0, unlockDates: [String:String]=[:]
        for t in transactions {
            total+=t.points;if !t.project.isEmpty { byProject[t.project,default:0]+=t.points }
            for item in DeskDecoration.all where total >= (item.level-1)*100 && unlockDates[item.id]==nil { unlockDates[item.id]=month(t.at) }
        }
        let level=1+total/100
        let decorations: [[String:Any]]=DeskDecoration.all.map { item in
            ["id":item.id,"name":item.name,"level":item.level,"unlocked":level>=item.level,"shown":level>=item.level && (shownDecorations ?? []).contains(item.id)]
        }
        var monthKeys=Set([month(now)] + (state.timeRewards?.coveredMonths ?? []))
        for e in work { if let date=DeskCodec.instant(e.at) { monthKeys.insert(month(date)) } }
        for t in transactions { monthKeys.insert(month(t.at)) }
        let stepEvents=state.events.filter { $0.kind=="step-value" && !$0.undone && $0.step != nil && (0..<11).contains($0.step!) && projects[$0.target] != nil && DeskCodec.instant($0.at) != nil }.enumerated().sorted { $0.element.at == $1.element.at ? $0.offset < $1.offset : $0.element.at < $1.element.at }.map(\.element)
        for e in stepEvents { monthKeys.insert(month(DeskCodec.instant(e.at)!)) }
        // Reconstruct stage transitions without changing the saved checklist.
        var seals: [String:String]=[:]
        for p in state.projects where p.included && p.steps.allSatisfy({$0==true}) {
            let changes=stepEvents.filter{$0.target==p.id}
            var steps=p.steps
            for e in changes.reversed() { steps[e.step!]=e.before }
            for e in changes {
                let wasComplete=steps.allSatisfy{$0==true};steps[e.step!]=e.after
                if !wasComplete && steps.allSatisfy({$0==true}) { seals[p.id]=month(DeskCodec.instant(e.at)!) }
                if !steps.allSatisfy({$0==true}) { seals.removeValue(forKey:p.id) }
            }
        }
        let months: [[String:Any]]=monthKeys.sorted(by:>).map { key in
            let tx=transactions.filter{month($0.at)==key}
            var net: [String:Int]=[:]
            for e in stepEvents where month(DeskCodec.instant(e.at)!)==key {
                net[e.target,default:0]+=(e.after==true ? 1 : 0)-(e.before==true ? 1 : 0)
            }
            let best=net.values.max() ?? 0
            let leaders=best>0 ? state.projects.filter{net[$0.id]==best}.map(\.title) : []
            let researchDays=(state.timeRewards?.minutesByDay ?? [:]).filter{String($0.key.prefix(7))==key}
            return ["researchMinutes":researchDays.values.reduce(0,+),"threeHourDays":researchDays.values.filter{$0>=DeskTimeRewards.thresholdMinutes}.count,
                    "timeXP":tx.filter{$0.kind=="time"}.reduce(0){$0+$1.points},"timeVerified":state.timeRewards?.coveredMonths.contains(key) ?? false,
                    "month":key,"tasks":work.filter{month(DeskCodec.instant($0.at)!)==key}.count,
                    "netStages":net.values.reduce(0,+),"baseXP":tx.filter{$0.kind=="base"}.reduce(0){$0+$1.points},
                    "bonusXP":tx.filter{$0.kind != "base"}.reduce(0){$0+$1.points},
                    "comebacks":tx.filter{$0.kind=="comeback"}.count,"longestStreak":monthlyLongest[key] ?? 0,
                    "leaders":leaders,"seals":state.projects.filter{seals[$0.id]==key}.map(\.title),
                    "unlocks":DeskDecoration.all.filter{unlockDates[$0.id]==key}.map(\.name)]
        }
        return ["activityDailyLimit":3,"researchDayThresholdMinutes":DeskTimeRewards.thresholdMinutes,"total":total,"level":level,"progress":total%100,"byProject":byProject,"streaks":streaks,"decorations":decorations,"months":months,"timeZone":"America/Chicago","timeVerifiedAt":state.timeRewards?.fetchedAt ?? "","timeStartDay":state.timeRewards?.startDay ?? "",
                "bonuses":transactions.filter{$0.kind != "base"}.map{["id":$0.id,"projectID":$0.project,"kind":$0.kind,"points":$0.points,"streak":$0.streak,"at":DeskCodec.iso($0.at)] as [String:Any]}]
    }
}

// Contains daily research totals only, never calendar titles or personal events.
struct DeskTimeRewards: Codable {
    static let thresholdMinutes: Double = 180
    var startDay: String
    var minutesByDay: [String:Double] = [:]
    var coveredMonths: [String] = []
    var fetchedAt: String = ""
    static func date(_ day: String) -> Date? {
        let parts=day.split(separator:"-").compactMap{Int($0)}
        guard parts.count==3,day.count==10 else { return nil }
        let c=DeskRewards.rewardCalendar
        guard let date=c.date(from:DateComponents(year:parts[0],month:parts[1],day:parts[2])),DeskCodec.day(date,calendar:c)==day else { return nil }
        return date
    }
    static func instant(_ value: String) -> Date? {
        if let date=DeskCodec.instant(value) { return date }
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds];return f.date(from:value)
    }
    func validate() throws {
        guard Self.date(startDay) != nil,minutesByDay.allSatisfy({ Self.date($0.key) != nil && $0.value.isFinite && $0.value>=0 && $0.value<=1500 }),coveredMonths.allSatisfy({ Self.date($0+"-01") != nil }) else { throw ModelError.message("Check research-time reward records.") }
    }
    mutating func reconcile(_ history: [String:Any], now: Date) throws -> Bool {
        guard history["status"] as? String=="complete",history["calculationVersion"] as? Int==3,
              history["timeZone"] as? String=="America/Chicago",history["basis"] as? String=="calendar_work_log",
              history["truncated"] as? Bool==false,history["failedCalendars"] as? Int==0,
              let stamp=history["fetchedAt"] as? String,let fetched=Self.instant(stamp),fetched<=now,now.timeIntervalSince(fetched)<86400,
              let start=history["rangeStart"] as? String,let a=Self.instant(start),let end=history["rangeEnd"] as? String,let b=Self.instant(end),a<=b,b<=fetched,
              let months=history["months"] as? [[String:Any]],!months.isEmpty else { return false }
        if let prior=Self.instant(fetchedAt),fetched<=prior { return false }
        let c=DeskRewards.rewardCalendar,lower=DeskCodec.day(a,calendar:c),upper=DeskCodec.day(b,calendar:c)
        guard c.startOfDay(for:a)==a else { return false }
        var incoming: [String:Double]=[:], seen=Set<String>()
        for m in months {
            guard let key=m["month"] as? String,Self.date(key+"-01") != nil,!seen.contains(key),let days=m["days"] as? [[String:Any]] else { return false }
            seen.insert(key)
            for d in days {
                guard let date=d["date"] as? String,Self.date(date) != nil,date>=lower,date<=upper,date.hasPrefix(key+"-"),
                      let value=d["researchUniqueMinutes"] as? Double,value.isFinite,value>=0,value<=1500,incoming[date]==nil else { return false }
                incoming[date]=value
            }
        }
        var cursor=c.date(from:c.dateComponents([.year,.month],from:a))!
        var expected=Set<String>()
        while cursor<=b { expected.insert(String(DeskCodec.day(cursor,calendar:c).prefix(7)));cursor=c.date(byAdding:.month,value:1,to:cursor)! }
        guard seen==expected else { return false }
        minutesByDay=minutesByDay.filter{$0.key<lower || $0.key>upper}
        minutesByDay.merge(incoming){_,v in v};coveredMonths=Set(coveredMonths).union(seen).sorted();fetchedAt=stamp
        try validate();return true
    }
}

// Local earned currency and collectible ownership share DeskStore's atomic save.
// Calendar collections use Chicago dates, like the existing work-record rewards.
// Holiday collections run for the whole named month; the date is an earning window.
struct DeskCollectionSeason {
    var year: Int, key: String, name: String, start: String, end: String
    var theme: String { "season:\(year):\(key)" }
    var title: String { "\(year) · \(name)" }
    static let recordsPerDay = 2
    static let milestones = [3,7,14]
    static func containing(_ date: Date) -> DeskCollectionSeason {
        let c=DeskRewards.rewardCalendar,year=c.component(.year,from:date),month=c.component(.month,from:date)
        let key: String, name: String, first: Int, last: Int
        switch month {
        case 1...2: (key,name,first,last)=("winter","Winter & New Year",1,2)
        case 3...5: (key,name,first,last)=("spring","Spring garden",3,5)
        case 6...8: (key,name,first,last)=("summer","Summer seaside",6,8)
        case 9: (key,name,first,last)=("autumn","Autumn walk",9,9)
        case 10: (key,name,first,last)=("halloween","Halloween",10,10)
        case 11: (key,name,first,last)=("thanksgiving","Thanksgiving",11,11)
        default: (key,name,first,last)=("christmas","Christmas",12,12)
        }
        let lastMonth=c.date(from:DateComponents(year:year,month:last,day:1))!
        let lastDay=c.range(of:.day,in:.month,for:lastMonth)!.count
        return .init(year:year,key:key,name:name,start:String(format:"%04d-%02d-01",year,first),end:String(format:"%04d-%02d-%02d",year,last,lastDay))
    }
    var items: [DeskCollectible] {
        let names: [String]
        switch key {
        case "winter": names=["New Year star stamp","Cozy mittens","Winter cabin"]
        case "spring": names=["Sprout stamp","Tulip pot","Little birdhouse"]
        case "summer": names=["Wave stamp","Seashell","Beach parasol"]
        case "autumn": names=["Autumn leaf stamp","Acorn","Autumn lantern"]
        case "halloween": names=["Little ghost stamp","Jack-o’-lantern","Witch hat"]
        case "thanksgiving": names=["Gratitude leaf stamp","Pumpkin pie","Harvest basket"]
        default: names=["Snowflake stamp","Christmas stocking","Tree snow globe"]
        }
        return names.enumerated().map { i,name in
            .init(id:theme+":\(Self.milestones[i])",title:name,theme:theme,themeTitle:title,projectID:"",kind:i==0 ? "stamp" : "object",motif:"season-\(key)-\(i)",price:0)
        }
    }
    static func qualifyingDays(_ state: DeskData, now: Date) -> [String:[String]] {
        var counts: [String:Int]=[:],seen=Set<String>()
        for e in state.events where e.actor=="user" && e.kind=="activity" && !e.undone && !e.summary.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
            guard let date=DeskCodec.instant(e.at),date<=now else { continue }
            let day=DeskCodec.day(date,calendar:DeskRewards.rewardCalendar)
            guard day>="2026-10-01",seen.insert(e.id).inserted else { continue }
            // Project identity, current checklist, and time-tracking totals do not affect this count.
            counts[day,default:0]+=1
        }
        var days: [String:[String]]=[:]
        for day in counts.keys.sorted() where counts[day]!>=recordsPerDay {
            let season=containing(DeskTimeRewards.date(day)!)
            days[season.theme,default:[]].append(day)
        }
        return days
    }
}
struct DeskCollectible: Codable {
    var id: String, title: String, theme: String, themeTitle: String, projectID: String, kind: String, motif: String
    var price: Int
    var seasonal: Bool { theme.hasPrefix("season:") }
    var requiredSteps: Int { projectID.isEmpty ? 0 : kind=="object" ? 6 : 3 }
    var slots: [String] { kind == "object" ? ["desk","shelf"] : ["wall","pinboard"] }
    static func catalog(_ state: DeskData, now: Date = Date()) -> [DeskCollectible] {
        var items: [DeskCollectible] = []
        for p in state.projects {
            // Keep the old cover identity so purchases and reservations survive the conversion.
            for (key,kind,label,price) in [("stamp","stamp","Stamp",30),("cover","object","Object",60)] {
                items.append(.init(id:"project:\(p.id):\(key)",title:p.title+" · "+label,theme:"project:"+p.id,themeTitle:p.title,projectID:p.id,kind:kind,motif:"project",price:price))
            }
        }
        for (theme,title,motifs) in [("reading","Reading time",["book","lamp","pen","notebook"]),("coffee","Coffee break",["cup","pot","beans","window"]),("garden","Small garden",["plant","flower","leaf","watering"]),("journey","Researcher’s journey",["cat","case","moon","ticket"])] {
            let names=["book":"Bookmark","lamp":"Reading lamp","pen":"Fountain pen","notebook":"Research notes","cup":"Coffee cup","pot":"Coffee pot","beans":"Coffee beans","window":"Window","plant":"Small plant","flower":"A single flower","leaf":"Leaf","watering":"Watering can","cat":"Cat","case":"Suitcase","moon":"Night sky","ticket":"Train ticket"]
            for (index,motif) in motifs.enumerated() {
                items.append(.init(id:"life:"+motif,title:names[motif]!,theme:"life:"+theme,themeTitle:title,projectID:"",kind:index%2 == 0 ? "object" : "postcard",motif:motif,price:index%2 == 0 ? 60 : 30))
            }
        }
        return items + DeskCollectionSeason.containing(now).items
    }
}
struct DeskCoinEntry: Codable { var id: String, source: String, reason: String, at: String; var amount: Int }
struct DeskOwnedCollectible: Codable { var item: DeskCollectible; var acquiredAt: String; var via: String }
struct DeskEnvelope: Codable { var id: String; var item: DeskCollectible; var purchasedAt: String }
struct DeskCollectiblePosition: Codable {
    var x: Double, y: Double
    var valid: Bool { x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y) }
}
struct DeskCardSticker: Codable {
    var x: Double, y: Double, size: Double
    var valid: Bool { DeskCollectiblePosition(x:x,y:y).valid && size.isFinite && (0.06...0.30).contains(size) }
}
struct DeskCollectibles: Codable {
    var version = 1
    var projectSetVersion: Int? = nil
    var unlocks: [String:String]? = nil
    var startDay = "2026-10-01"
    var grants: [String:Int] = [:]
    var ledger: [DeskCoinEntry] = []
    var owned: [String:DeskOwnedCollectible] = [:]
    var envelopes: [DeskEnvelope] = []
    var display: [String:String] = [:]
    // Fractions of available room travel, independent of window size. Old wallets omit this field.
    var positions: [String:DeskCollectiblePosition]? = nil
    var cardStickers: [String:[String:DeskCardSticker]]? = nil
    var favorites: [String:String] = [:]
    var requests: [String:String] = [:]
    var balance: Int { ledger.reduce(0){$0+$1.amount} }
    static let slots=["wall","desk","shelf","pinboard"]
    mutating func grant(_ key: String, _ amount: Int, _ reason: String, at: String) {
        let difference=amount-(grants[key] ?? 0)
        guard difference != 0 else { return }
        grants[key]=amount
        ledger.append(.init(id:UUID().uuidString,source:key,reason:reason,at:at,amount:difference))
    }
    mutating func upgradeProjectSets(at: String) {
        func asObject(_ item: DeskCollectible) -> DeskCollectible {
            guard !item.projectID.isEmpty,item.kind=="cover",item.id=="project:"+item.projectID+":cover" else { return item }
            var updated=item;updated.kind="object";updated.title=item.themeTitle+" · Object";return updated
        }
        for id in owned.keys.sorted() { owned[id]!.item=asObject(owned[id]!.item) }
        for index in envelopes.indices { envelopes[index].item=asObject(envelopes[index].item) }
        // A reserved, unopened postcard leaves the new two-item pool. Refund its actual charge once.
        for envelope in envelopes where !envelope.item.projectID.isEmpty && envelope.item.id=="project:"+envelope.item.projectID+":postcard" {
            let source="purchase:project-set-refund:"+envelope.id
            if !ledger.contains(where:{$0.source==source}) {
                let paid = -ledger.filter{$0.source=="purchase:"+envelope.id}.reduce(0){$0+$1.amount}
                if paid>0 { ledger.append(.init(id:UUID().uuidString,source:source,reason:envelope.item.themeTitle+" · Postcard envelope refund",at:at,amount:paid)) }
            }
        }
        envelopes.removeAll{!$0.item.projectID.isEmpty && $0.item.id=="project:"+$0.item.projectID+":postcard"}
        // Preserve existing desk/shelf displays; relocate converted covers only into empty compatible slots.
        let displaced=Self.slots.compactMap { slot -> String? in
            guard let id=display[slot],let item=owned[id]?.item,!item.slots.contains(slot) else { return nil }
            display.removeValue(forKey:slot);return id
        }
        for id in displaced {
            if let slot=owned[id]?.item.slots.first(where:{display[$0]==nil}) { display[slot]=id }
        }
        projectSetVersion=2
    }
    mutating func reconcile(_ state: DeskData, now: Date = Date()) {
        let at=DeskCodec.iso(now),c=DeskRewards.rewardCalendar
        upgradeProjectSets(at:at)
        if unlocks==nil { unlocks=[:] }
        for item in DeskCollectible.catalog(state) where !item.projectID.isEmpty {
            let completed=state.projects.first(where:{$0.id==item.projectID})?.steps.filter{$0==true}.count ?? 0
            if completed>=item.requiredSteps || owned[item.id] != nil || envelopes.contains(where:{$0.item.id==item.id}) {
                if unlocks![item.id]==nil { unlocks![item.id]=at }
            }
        }
        // Completion coins are a one-time milestone, retained if the checklist later changes.
        for p in state.projects { for i in p.steps.indices where p.steps[i] == true {
            grant("stage:\(p.id):\(i)",10,p.title+" · "+deskStages[i],at:at)
        } }
        var desired: [String:Int]=[:],counts: [String:Int]=[:]
        let ids=Set(state.projects.map(\.id))
        let events=state.events.enumerated().sorted { $0.element.at == $1.element.at ? $0.offset < $1.offset : $0.element.at < $1.element.at }.map(\.element)
        for e in events where e.actor == "user" && e.kind == "activity" && !e.undone && ids.contains(e.target) && !e.summary.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
            guard let date=DeskCodec.instant(e.at),date<=now else { continue }
            let day=DeskCodec.day(date,calendar:c);guard day>=startDay else { continue }
            let key=e.target+":"+day;counts[key,default:0]+=1
            if counts[key]!<=3 { desired["activity:"+e.id]=2 }
        }
        for (day,minutes) in state.timeRewards?.minutesByDay ?? [:] where day>=startDay && minutes>=DeskTimeRewards.thresholdMinutes {
            if let date=DeskTimeRewards.date(day),date<=now { desired["time:"+day]=6 }
        }
        let keys=Set(desired.keys).union(grants.keys.filter{$0.hasPrefix("activity:") || $0.hasPrefix("time:")})
        for key in keys.sorted() { grant(key,desired[key] ?? 0,key.hasPrefix("time:") ? "3 research hours · "+String(key.dropFirst(5)) : "Research record",at:at) }
        // Backfill eligible past windows as well, even if the app was closed at rollover.
        // Earned possessions are permanent; correcting a record only changes future progress.
        for days in DeskCollectionSeason.qualifyingDays(state,now:now).values {
            let season=DeskCollectionSeason.containing(DeskTimeRewards.date(days[0])!)
            for (index,item) in season.items.enumerated() where days.count>=DeskCollectionSeason.milestones[index] && owned[item.id]==nil {
                owned[item.id] = .init(item:item,acquiredAt:at,via:"seasonal")
            }
        }
        completeSets(DeskCollectible.catalog(state,now:now),at:at)
    }
    mutating func completeSets(_ catalog: [DeskCollectible], at: String) {
        for (theme,items) in Dictionary(grouping:catalog.filter{!$0.seasonal},by:{$0.theme}) where items.allSatisfy({owned[$0.id] != nil}) {
            let id="set:"+theme;guard owned[id]==nil,let first=items.first else { continue }
            let item=DeskCollectible(id:id,title:first.themeTitle+" · Collection complete",theme:theme,themeTitle:first.themeTitle,projectID:first.projectID,kind:"stamp",motif:"laurel",price:0)
            owned[id] = .init(item:item,acquiredAt:at,via:"collection")
        }
    }
    func validate() throws {
        guard version==1,startDay=="2026-10-01",Set(ledger.map(\.id)).count==ledger.count,
              Set(envelopes.map(\.id)).count==envelopes.count,
              Set(envelopes.map{$0.item.id}).count==envelopes.count,
              envelopes.allSatisfy({owned[$0.item.id]==nil}),
              owned.allSatisfy({$0.key==$0.value.item.id}),
              display.allSatisfy({Self.slots.contains($0.key) && owned[$0.value]?.item.slots.contains($0.key)==true}),
              Set(display.values).count==display.count,
              (positions ?? [:]).allSatisfy({owned[$0.key] != nil && $0.value.valid}),
              (cardStickers ?? [:]).allSatisfy({ $0.key.count==7 && DeskTimeRewards.date($0.key+"-01") != nil && $0.value.allSatisfy({owned[$0.key] != nil && $0.value.valid}) }),
              favorites.values.allSatisfy({owned[$0] != nil}),grants.values.allSatisfy({$0>=0})
        else { throw ModelError.message("Check coin and collection records.") }
        let income=ledger.filter{!$0.source.hasPrefix("purchase:")}.reduce(0){$0+$1.amount}
        guard income==grants.values.reduce(0,+) else { throw ModelError.message("Coin history does not balance.") }
    }
    static func requestSignature(_ action: String, id: String, slot: String, position: DeskCollectiblePosition? = nil, sticker: DeskCardSticker? = nil) -> String {
        var parts=[action,id,slot]
        if action=="collectionMove" { parts += position.map{[String($0.x),String($0.y)]} ?? ["missing"] }
        if action=="collectionStickerSet" { parts += sticker.map{[String($0.x),String($0.y),String($0.size)]} ?? ["missing"] }
        return parts.joined(separator:"|")
    }
    func isUnlocked(_ item: DeskCollectible) -> Bool {
        if item.seasonal { return owned[item.id] != nil }
        return item.projectID.isEmpty || unlocks?[item.id] != nil || owned[item.id] != nil
    }
    func available(_ catalog: [DeskCollectible], theme: String) -> [DeskCollectible] {
        let reserved=Set(envelopes.map{$0.item.id})
        return catalog.filter{!$0.seasonal && $0.theme==theme && isUnlocked($0) && owned[$0.id]==nil && !reserved.contains($0.id)}
    }
    mutating func act(_ action: String, id: String, slot: String, requestID: String, catalog: [DeskCollectible], now: Date = Date(), position: DeskCollectiblePosition? = nil, sticker: DeskCardSticker? = nil) throws {
        guard !requestID.isEmpty else { throw ModelError.message("Purchase request ID is missing.") }
        let signature=Self.requestSignature(action,id:id,slot:slot,position:position,sticker:sticker)
        if let previous=requests[requestID] {
            guard previous==signature else { throw ModelError.message("Purchase request contents do not match.") };return
        }
        let at=DeskCodec.iso(now),reserved=Set(envelopes.map{$0.item.id})
        switch action {
        case "collectionBuy","collectionEnvelope":
            let item: DeskCollectible
            let cost: Int
            if action == "collectionBuy" {
                guard let found=catalog.first(where:{$0.id==id}),owned[id]==nil,!reserved.contains(id) else { throw ModelError.message("This collectible is owned or inside an envelope.") }
                guard !found.seasonal else { throw ModelError.message("Seasonal collectibles are earned through work records.") }
                guard isUnlocked(found) else { throw ModelError.message("In this project \(found.requiredSteps)stages completed to unlock.") }
                item=found;cost=item.price
            } else {
                let pool=available(catalog,theme:id)
                guard let found=pool.randomElement() else { throw ModelError.message("No new collectibles available. Check unlock requirements and unopened envelopes.") }
                item=found;cost=30
            }
            guard balance>=cost else { throw ModelError.message("Not enough coins.") }
            ledger.append(.init(id:UUID().uuidString,source:"purchase:"+requestID,reason:action=="collectionBuy" ? item.title : item.themeTitle+" · Mystery envelope",at:at,amount:-cost))
            if action=="collectionBuy" { owned[item.id] = .init(item:item,acquiredAt:at,via:"purchase") }
            else { envelopes.append(.init(id:requestID,item:item,purchasedAt:at)) }
        case "collectionOpen":
            guard let index=envelopes.firstIndex(where:{$0.id==id}) else { throw ModelError.message("Envelope already opened.") }
            let envelope=envelopes.remove(at:index)
            owned[envelope.item.id] = .init(item:envelope.item,acquiredAt:at,via:"envelope")
        case "collectionDisplay":
            guard Self.slots.contains(slot) else { throw ModelError.message("Choose a display position.") }
            if id.isEmpty { display.removeValue(forKey:slot) }
            else {
                guard let item=owned[id]?.item,item.slots.contains(slot) else { throw ModelError.message("This item cannot be displayed here.") }
                display=display.filter{$0.value != id};display[slot]=id
                positions?.removeValue(forKey:id)
            }
        case "collectionMove","collectionResetPosition":
            guard owned[id] != nil,display[slot]==id else { throw ModelError.message("Choose a displayed collectible.") }
            if action=="collectionMove" {
                guard let position=position,position.valid else { throw ModelError.message("Choose a position in the room.") }
                if positions==nil { positions=[:] };positions![id]=position
            } else { positions?.removeValue(forKey:id) }
        case "collectionStickerSet","collectionStickerRemove":
            guard owned[id] != nil,slot.count==7,DeskTimeRewards.date(slot+"-01") != nil else { throw ModelError.message("Check the owned item and card month.") }
            if action=="collectionStickerSet" {
                guard let sticker=sticker,sticker.valid else { throw ModelError.message("Check sticker position and size.") }
                if cardStickers==nil { cardStickers=[:] };cardStickers![slot,default:[:]][id]=sticker
            } else { cardStickers?[slot]?.removeValue(forKey:id) }
        case "collectionFavorite":
            let month=String(DeskCodec.day(now,calendar:DeskRewards.rewardCalendar).prefix(7))
            guard id.isEmpty || owned[id] != nil else { throw ModelError.message("Choose an owned item.") }
            if id.isEmpty { favorites.removeValue(forKey:month) } else { favorites[month]=id }
        default: throw ModelError.message("Unknown collection action.")
        }
        completeSets(catalog,at:at);requests[requestID]=signature
        try validate()
    }
    func payload(_ state: DeskData, now: Date = Date()) -> [String:Any] {
        let catalog=DeskCollectible.catalog(state,now:now),season=DeskCollectionSeason.containing(now)
        let days=DeskCollectionSeason.qualifyingDays(state,now:now)[season.theme] ?? []
        let today=DeskCodec.day(now,calendar:DeskRewards.rewardCalendar)
        let todayIDs=Set(state.events.filter { e in
            guard e.actor=="user",e.kind=="activity",!e.undone,!e.summary.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,let date=DeskCodec.instant(e.at),date<=now else { return false }
            return DeskCodec.day(date,calendar:DeskRewards.rewardCalendar)==today
        }.map(\.id))
        let seasonal: [String:Any] = ["theme":season.theme,"title":season.title,"start":season.start,"end":season.end,"days":days.count,"todayRecords":todayIDs.count,"recordsPerDay":DeskCollectionSeason.recordsPerDay,"milestones":DeskCollectionSeason.milestones,"timeZone":"America/Chicago"]
        func json<T:Encodable>(_ value:T)->Any { (try? JSONSerialization.jsonObject(with:DeskCodec.encode(value))) ?? NSNull() }
        let eligibility=Dictionary(uniqueKeysWithValues:catalog.map { item in
            (item.id,["unlocked":isUnlocked(item),"required":item.requiredSteps,"completed":state.projects.first(where:{$0.id==item.projectID})?.steps.filter{$0==true}.count ?? 0] as [String:Any])
        })
        let offers=Dictionary(uniqueKeysWithValues:Set(catalog.map(\.theme)).map { theme in
            let pool=available(catalog,theme:theme)
            return (theme,["count":pool.count,"singleID":pool.count==1 ? pool[0].id : "","locked":catalog.filter{$0.theme==theme && !isUnlocked($0)}.count] as [String:Any])
        })
        return ["version":version,"seasonal":seasonal,"projectSetVersion":projectSetVersion ?? 1,"stickerEditing":true,"cardStickers":json(cardStickers ?? [:]),"unlockRules":1,"unlocks":unlocks ?? [:],"eligibility":eligibility,"offers":offers,"freePlacement":true,"positions":json(positions ?? [:]),"balance":balance,"catalog":json(catalog),"owned":json(owned),"display":display,"favorites":favorites,
                "envelopes":envelopes.map{["id":$0.id,"theme":$0.item.theme,"themeTitle":$0.item.themeTitle,"purchasedAt":$0.purchasedAt]},
                "ledger":json(Array(ledger.suffix(100).reversed())),"earned":grants.values.reduce(0,+),"spent":-ledger.filter{$0.source.hasPrefix("purchase:")}.reduce(0){$0+$1.amount}]
    }
}
