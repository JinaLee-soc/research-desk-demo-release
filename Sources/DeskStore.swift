import Foundation
import AppKit
import UserNotifications

struct DeskNag: Codable {
    var id: String, projectID: String, text: String, status: String
    var startedAt: Date, resetAt: Date, hiddenUntil: Date?
    func level(at now: Date) -> Int {
        let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: resetAt), to: Calendar.current.startOfDay(for: now)).day ?? 0)
        return min(2, days / 3)
    }
    func message(at now: Date) -> String {
        let phrases = [
            ["Let’s start with one small step today.", "Can you make a little time for the first part?", "This is on today’s list. Move one part forward."],
            ["This reminder is still active. Let’s check it first today.", "You asked me to keep track of this. Choose a small portion for today.", "Set aside time for this before adding more tasks."],
            ["Make this today’s first task. If you are stuck, identify the obstacle.", "Let’s make a little progress today.", "Check progress on this first. Pause the reminder if plans changed."]
        ]
        let day = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970 / 86400)
        return text + " — " + phrases[level(at: now)][abs(day) % 3]
    }
}

final class DeskStore {
    let wiki: URL
    let resources: URL
    let deskFile: DeskFile
    let deadlineFile: DeskFile
    let prefs: UserDefaults
    var automaticAdvice: DeskAdvice?
    private var nagKey: String { "deskNags:" + wiki.standardizedFileURL.path }
    var nags: [DeskNag] { (prefs.data(forKey:nagKey).flatMap { try? JSONDecoder().decode([DeskNag].self,from:$0) }) ?? [] }
    func saveNags(_ rows: [DeskNag]) throws { prefs.set(try JSONEncoder().encode(rows),forKey:nagKey); onChange?() }
    func addNag(projectID: String, text: String, now: Date = Date()) throws {
        guard data?.projects.contains(where:{$0.id == projectID}) == true,
              !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, text.utf8.count <= 2000 else { throw ModelError.message("Check the reminder target and text.") }
        var rows = nags
        guard !rows.contains(where:{$0.projectID == projectID && $0.text == text && $0.status != "done"}) else { throw ModelError.message("This reminder already exists. Check the Assistant view.") }
        rows.append(.init(id:UUID().uuidString,projectID:projectID,text:text,status:"active",startedAt:now,resetAt:now,hiddenUntil:nil))
        try saveNags(rows)
    }
    func nagPayload(now: Date = Date()) -> [[String:Any]] {
        nags.filter {$0.status != "done"}.map { n in
            ["id":n.id,"projectID":n.projectID,"text":n.text,"status":n.status,"message":n.message(at:now),"level":n.level(at:now)+1,"hidden":(n.hiddenUntil ?? .distantPast)>now]
        }
    }
    func currentAdvice(now: Date = Date()) -> DeskAdvice {
        guard let state=data else { return .init(id:"empty",title:"",message:"",nextAction:"",evidence:[],mood:"idle",deadlineID:"",urgent:false) }
        let base=DeskAssistant.advice(state,deadlines:deadlines,now:now)
        let active=nags.filter {$0.status == "active" && ($0.hiddenUntil ?? .distantPast)<=now}
        guard !base.urgent else { return base }
        guard !active.isEmpty else { return automaticAdvice ?? base }
        let day=Int(Calendar.current.startOfDay(for:now).timeIntervalSince1970/86400)
        let nag=active[abs(day)%active.count]
        return .init(id:"nag:"+nag.id,title:"Custom reminder · Intensity \(nag.level(at:now)+1)/3",message:nag.message(at:now),nextAction:nag.text,evidence:["User-confirmed reminder", "Completion is unconfirmed. Missing records do not establish that no work occurred.","3days per intensity level, maximum 3. Progress lowers intensity; deadlines stay unchanged."],mood:"idle",deadlineID:"",urgent:false)
    }
    var deadlineListSort: String { prefs.string(forKey:"deadlineListSort") == "date" ? "date" : "priority" }
    var data: DeskData?
    var deadlines: [Deadline] = []
    var archive: [String:Any] = [:]
    var error: String?
    var notice = ""
    var replyID = ""
    var replyOK = true
    var readAt = ""
    var activity: [[String:String]] = []
    var onChange: (() -> Void)?
    var onCommand: ((String) -> Void)?
    var morning: Timer?, poll: Timer?
    var observers: [NSObjectProtocol] = []
    var lastDay = ""
    var focusExpired = false
    init(wiki: URL, resources: URL, prefs: UserDefaults = .standard) {
        self.wiki = wiki; self.resources = resources; self.prefs = prefs
        let backups = wiki.deletingLastPathComponent().appendingPathComponent("Demo Backups/.backups")
        deskFile = DeskFile(wiki.appendingPathComponent("Planning/Desk.md"),backupRoot:backups)
        deadlineFile = DeskFile(wiki.appendingPathComponent("Root/Deadlines.md"),backupRoot:backups)
    }
    func initialize() {
        do {
            let source = try Data(contentsOf: resources.appendingPathComponent("portfolio-source.json"))
            archive = try JSONSerialization.jsonObject(with:source) as? [String:Any] ?? [:]
            try FileManager.default.createDirectory(at:wiki.appendingPathComponent("Planning"),withIntermediateDirectories:true)
            let raw = try deadlineFile.load()
            let identified = try DeskCodec.addStableIDs(String(decoding:raw,as:UTF8.self))
            if Data(identified.utf8) != raw { try deadlineFile.save(Data(identified.utf8)) }
            deadlines = try DeadlineModel.parse(identified)
            if !FileManager.default.fileExists(atPath:deskFile.url.path) {
                var seed = try JSONDecoder().decode(DeskData.self,from:Data(contentsOf:resources.appendingPathComponent("seed.json")))
                let oldPriority = prefs.dictionary(forKey:"priorities") as? [String:Int] ?? [:]
                let oldCompleted = Set(prefs.stringArray(forKey:"completed") ?? [])
                for d in deadlines {
                    var meta = DeadlineSettings.initial(d)
                    meta.completed = oldCompleted.contains(d.title)
                    meta.priority = oldPriority[d.title]
                    if seed.deadlineSettings[d.id] == nil { seed.deadlineSettings[d.id] = meta }
                }
                let unmatched = Set(oldPriority.keys).union(oldCompleted).subtracting(Set(deadlines.map(\.title)))
                if !unmatched.isEmpty { seed.migrationNotes.append("Unmatched imported settings (originals retained): " + unmatched.sorted().joined(separator:", ")) }
                seed.updatedAt = DeskCodec.iso(); seed.revision = UUID().uuidString
                try seed.validate(); try deskFile.save(try DeskCodec.markdown(seed),creating:true)
            }
            let imported = wiki.appendingPathComponent("Planning/Imported-cells.json")
            if !FileManager.default.fileExists(atPath:imported.path) { try source.write(to:imported,options:.withoutOverwriting) }
            let activities = wiki.appendingPathComponent("Planning/Activity.md")
            if !FileManager.default.fileExists(atPath:activities.path) {
                let template = "# Recorded work\n\n[[Planning/Desk|Research Desk]]\n\nCurrent work follows the declared focus. Recent work uses explicit user records with time-zoned ISO 8601 timestamps and stable project IDs. Automatic page updates do not count as work.\n\n| at | actor | project_id | action |\n| --- | --- | --- | --- |\n"
                try Data(template.utf8).write(to:activities,options:.withoutOverwriting)
            }
            reload()
        } catch { self.error = error.localizedDescription; onChange?() }
    }
    func reload() {
        do {
            let next = try DeskCodec.read(deskFile.load())
            let rows = try DeadlineModel.parse(String(decoding:try deadlineFile.load(),as:UTF8.self))
            data = next; deadlines = rows; error = nil; readAt = DeskCodec.iso(); lastDay = DeskCodec.day(Date())
            activity = readActivities()
        } catch { self.error = error.localizedDescription }
        if data?.collectibles != nil && error == nil { syncCollectibles() }
        onChange?()
    }
    func readActivities() -> [[String:String]] {
        let known = Set(data?.projects.map(\.id) ?? [])
        let text = (try? String(contentsOf:wiki.appendingPathComponent("Planning/Activity.md"),encoding:.utf8)) ?? ""
        var rows: [[String:String]] = []
        for line in text.components(separatedBy:"\n") where line.hasPrefix("|") {
            let c = DeadlineModel.cells(line)
            guard c.count == 4, c[1] == "user", let at = DeskCodec.instant(c[0]), at <= Date(), Date().timeIntervalSince(at) <= 7*86400, known.contains(c[2]) else { continue }
            rows.append(["at":c[0],"projectID":c[2],"action":c[3],"source":"Planning/Activity.md"])
        }
        for e in (data?.events ?? []).reversed() where e.actor == "user" && ["step","project","activity","focus"].contains(e.kind) {
            if let at = DeskCodec.instant(e.at), at <= Date(), Date().timeIntervalSince(at) <= 7*86400, known.contains(e.target) {
                rows.append(["at":e.at,"projectID":e.target,"action":e.summary,"source":"Planning/Desk.md · "+e.id])
            }
        }
        return rows.enumerated().sorted { a,b in
            if a.element["at"] != b.element["at"] { return a.element["at"]! > b.element["at"]! }
            return a.offset < b.offset
        }.map { $0.element }
    }
    func start() {
        initialize(); scheduleMorning()
        poll = Timer.scheduledTimer(withTimeInterval:15,repeats:true) { [weak self] _ in
            guard let self else { return }
            let changed = (try? Data(contentsOf:self.deskFile.url)) != self.deskFile.observed || (try? Data(contentsOf:self.deadlineFile.url)) != self.deadlineFile.observed
            let dateChanged = self.lastDay != DeskCodec.day(Date())
            // Also reread explicit wiki activity and expired snoozes; never treat file mtime as human work.
            if changed || dateChanged { self.reload() }
            else { self.activity = self.readActivities(); self.readAt = DeskCodec.iso(); self.onChange?() }
            self.maybeNotify()
        }
        for name in [NSNotification.Name.NSSystemTimeZoneDidChange,.NSSystemClockDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in self?.reload(); self?.scheduleMorning() })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didWakeNotification,object:nil,queue:.main) { [weak self] _ in self?.reload();self?.scheduleMorning();self?.onCommand?("calendarRefresh") })
    }
    func scheduleMorning() {
        morning?.invalidate()
        morning = Timer(fire:DeadlineModel.nextMorning(after:Date()),interval:0,repeats:false) { [weak self] _ in self?.reload();self?.maybeNotify();self?.scheduleMorning() }
        RunLoop.main.add(morning!,forMode:.common)
    }
    func mutate(revision: String, kind: String, target: String, summary: String, nextRevision: String = UUID().uuidString, eventID: String = UUID().uuidString, actor: String = "user", _ change: (inout DeskData) throws -> Void) throws {
        guard var next = data, next.revision == revision, error == nil else { throw ModelError.message("The record is stale or unreadable. Refresh and try again.") }
        try change(&next)
        next.events.append(.init(id:eventID,at:DeskCodec.iso(),actor:actor,kind:kind,target:target,summary:summary,step:nil,before:nil,after:nil))
        next.rewards = DeskRewards.recording(from:data!, to:next)
        if var wallet=next.collectibles { wallet.reconcile(next);next.collectibles=wallet }
        next.updatedAt = DeskCodec.iso(); next.revision = nextRevision; try next.validate()
        guard let original = deskFile.observed else { throw ModelError.message("No base record for saving.") }
        try deskFile.save(try DeskCodec.replacing(next,in:original)); data = next; activity = readActivities(); notice = "Saved to demo wiki."; onChange?()
    }
    var timeRewardStatus = "Waiting for research-time check"
    func syncCollectibles() {
        guard let state=data,error==nil else { return }
        var wallet=state.collectibles ?? DeskCollectibles();wallet.reconcile(state)
        if let existing=state.collectibles, (try? DeskCodec.encode(existing)) == (try? DeskCodec.encode(wallet)) { return }
        do { try mutate(revision:state.revision,kind:"coin-sync",target:"desk",summary:"Research coin history refreshed",actor:"tool") { $0.collectibles=wallet } }
        catch { notice="Coin refresh failed: " + error.localizedDescription }
    }
    func applyOctoberRewards(now: Date = Date()) {
        let start="2026-10-01"
        guard let state=data,error==nil,state.rewards?.rewardStartDay != start || state.timeRewards?.startDay != start else { return }
        do { try mutate(revision:state.revision,kind:"reward-backfill",target:"desk",summary:"2026-10-01Research rewards backfilled from",actor:"tool") { next in
            next.rewards=DeskRewards.backfilled(state,start:start,now:now)
            if next.timeRewards == nil { next.timeRewards=DeskTimeRewards(startDay:start) }
            else { next.timeRewards?.startDay=start }
        } } catch { notice="Reward backfill failed: " + error.localizedDescription }
    }
    func enableTimeRewards(now: Date = Date()) {
        guard let state=data,state.timeRewards==nil,error==nil else { return }
        do { try mutate(revision:state.revision,kind:"time-rewards",target:"desk",summary:"Research-time rewards started",actor:"tool") { next in
            next.timeRewards=DeskTimeRewards(startDay:DeskCodec.day(now,calendar:DeskRewards.rewardCalendar))
        } } catch { timeRewardStatus="Could not start research-time rewards: " + error.localizedDescription }
    }
    func syncTimeRewards(_ calendar: [String:Any], now: Date = Date()) {
        guard calendar["historyRefreshing"] as? Bool != true else { timeRewardStatus="Checking research time · Further rewards paused";return }
        guard calendar["historyCached"] as? Bool != true,let history=calendar["timeTracking"] as? [String:Any],
              let state=data,var time=state.timeRewards else { timeRewardStatus="Latest research time unconfirmed · Further rewards paused";return }
        do {
            if try time.reconcile(history,now:now) {
                try mutate(revision:state.revision,kind:"time-rewards",target:"desk",summary:"Calendar research time refreshed",actor:"tool") { next in next.timeRewards=time }
                timeRewardStatus="Recorded research time · At least 3 hours per day +20 XP"
            } else {
                timeRewardStatus = history["status"] as? String == "complete" && history["fetchedAt"] as? String == state.timeRewards?.fetchedAt ? "Recorded research time · At least 3 hours per day +20 XP" : "Research-time data incomplete or stale · Further rewards paused"
            }
        } catch { timeRewardStatus="Research-time save deferred: " + error.localizedDescription }
    }
    func handle(_ input: [String:Any]) {
        replyID = input["requestID"] as? String ?? ""; replyOK = true
        let action = input["action"] as? String ?? "", revision = input["revision"] as? String ?? "", id = input["id"] as? String ?? ""
        func string(_ key:String) -> String { String((input[key] as? String ?? "").prefix(10000)) }
        do {
            switch action {
            case "ready": onChange?()
            case "nagPause","nagResume","nagProgress","nagToday","nagDone":
                var rows=nags
                guard let i=rows.firstIndex(where:{$0.id == id && $0.status != "done"}) else { throw ModelError.message("Check the reminder.") }
                if action == "nagPause" { rows[i].status="paused" }
                if action == "nagDone" { rows[i].status="done" }
                if action == "nagResume" { rows[i].status="active";rows[i].resetAt=Date();rows[i].hiddenUntil=nil }
                if action == "nagProgress" { rows[i].resetAt=Date() }
                if action == "nagToday" { rows[i].hiddenUntil=Calendar.current.date(byAdding:.day,value:1,to:Calendar.current.startOfDay(for:Date())) }
                try saveNags(rows);notice="Reminder updated. Paper completion, scores and deadlines are unchanged.";onChange?()
            case "deadlineListSort":
                let mode = string("mode")
                guard ["date","priority"].contains(mode) else { throw ModelError.message("Unsupported sort order.") }
                prefs.set(mode,forKey:"deadlineListSort");notice="";onChange?()
            case "calendarRefresh":onCommand?("calendarRefresh")
            case "reload": notice = "Refreshed."; reload()
            case "full","mini","hideMini","quit","login": onCommand?(action)
            case "openWiki": openWiki(string("path"))
            case "openProjectLiterature","sendToLiquidText","importFromLiquidText","openProjectReferences","refreshLiteratureReferences","openLiteratureWiki","openURL":
                notice="External integrations are simulated in this demo.";onChange?()
            case "step":
                guard let index = input["step"] as? Int, (0..<11).contains(index), let project = data?.projects.first(where:{$0.id==id}) else { throw ModelError.message("Paper stage not found.") }
                let before = project.steps[index], after = before != true
                try mutate(revision:revision,kind:"step",target:id,summary:"\(project.title) · \(deskStages[index]) \(after ? "Complete" : "Reopen")") { next in
                    let p = next.projects.firstIndex(where:{$0.id==id})!; next.projects[p].steps[index] = after
                    if after && next.projects[p].focusStep == index { next.projects[p].focusStep = nil }
                    next.events.append(.init(id:UUID().uuidString,at:DeskCodec.iso(),actor:"user",kind:"step-value",target:id,summary:"Stage change",step:index,before:before,after:after))
                }
            case "undoStep":
                guard let event = data?.events.last(where:{$0.kind == "step-value" && !$0.undone}), let step = event.step else { throw ModelError.message("No stage change to undo.") }
                try mutate(revision:revision,kind:"undo",target:event.target,summary:"Undo stage change") { next in
                    guard let p = next.projects.firstIndex(where:{$0.id==event.target}), next.projects[p].steps[step] == event.after else { throw ModelError.message("The stage has since changed. Check the current record.") }
                    next.projects[p].steps[step] = event.before; next.events[next.events.firstIndex(where:{$0.id==event.id})!].undone = true
                }
            case "pin","focus","stopFocus","focusStep":
                try mutate(revision:revision,kind:action == "focus" ? "focus" : "preference",target:id,summary:action == "focus" ? "2hour focus declared" : "Focus display changed") { next in
                    if action == "stopFocus" { next.focus = nil; return }
                    guard let p = next.projects.firstIndex(where:{$0.id==id}) else { throw ModelError.message("Project not found.") }
                    if action == "pin" { next.pinnedProjectID = id }
                    if action == "focus" { next.pinnedProjectID = id; next.focus = .init(projectID:id,declaredAt:DeskCodec.iso(),until:DeskCodec.iso(Date().addingTimeInterval(7200))) }
                    if action == "focusStep", let step = input["step"] as? Int, (0..<11).contains(step) { next.projects[p].focusStep = next.projects[p].focusStep == step ? nil : step }
                }
            case "captureNote":
                guard let body=input["note"] as? [String:Any] else { throw ModelError.message("Invalid note format") }
                try mutate(revision:revision,kind:"research-note",target:id,summary:"Research note saved") { next in
                    try DeskNotes.append(body,id:string("noteID"),projectID:id,shared:false,to:&next)
                }
            case "saveProject":
                try mutate(revision:revision,kind:"project",target:id,summary:string("title")+" · Project record updated") { next in
                    var p = next.projects.first(where:{$0.id==id}) ?? .init(id:UUID().uuidString,title:"",journal:"",alternate:"",role:"",originalStatus:"",originalDue:"",sourceRow:0,steps:Array(repeating:false,count:11),included:true,priority:false,focusStep:nil,nextAction:"",wiki:"",state:"active",note:"")
                    p.title = string("title"); p.journal = string("journal"); p.alternate = string("alternate"); p.role = string("role"); p.nextAction = string("nextAction"); p.note = string("note"); p.state = string("state")
                    p.included = input["included"] as? Bool ?? p.included; p.priority = input["priority"] as? Bool ?? p.priority
                    if let index = next.projects.firstIndex(where:{$0.id==id}) { next.projects[index] = p } else { next.projects.append(p) }
                }
            case "savePlan":
                try mutate(revision:revision,kind:"plan",target:id,summary:"Updated plan / career record") { next in
                    var p = next.plans.first(where:{$0.id==id}) ?? .init(id:UUID().uuidString,kind:"career",period:"",text:"",original:"",source:"User input",state:"todo")
                    p.text = string("text");p.period = string("period");p.state = string("state");p.kind = string("kind")
                    if let lane = input["lane"] as? String { p.lane = lane }
                    guard !p.text.isEmpty else { throw ModelError.message("Enter a plan.") }
                    if let index = next.plans.firstIndex(where:{$0.id==id}) { next.plans[index] = p } else { next.plans.append(p) }
                }
            case "deadlineMeta":
                guard let d = deadlines.first(where:{$0.id==id}) else { throw ModelError.message("Deadline not found.") }
                try mutate(revision:revision,kind:"deadline",target:id,summary:d.title+" · Deadline status changed") { next in
                    var m = next.deadlineSettings[id] ?? .initial(d)
                    if let v = input["participation"] as? String { m.participation=v }
                    if let v = input["completed"] as? Bool { m.completed=v }
                    if let v = input["critical"] as? Bool { m.critical=v;m.criticalReason=string("criticalReason") }
                    if let v = input["nextAction"] as? String { m.nextAction=v }
                    if let v = input["category"] as? Int { m.category=v }
                    if let v = input["priority"] as? Int { m.priority=v == 0 ? nil : v }
                    if let v = input["projectID"] as? String { m.projectID=v }
                    if let v = input["timeZone"] as? String { m.timeZone=v }
                    next.deadlineSettings[id]=m
                }
            case "saveDeadline":
                guard error == nil, data?.revision == revision, let original = deadlineFile.observed, DeskCodec.hash(original) == string("deadlineHash"),
                      let date = DeadlineModel.parseDate(string("date")), !string("title").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw ModelError.message("Check source changes, deadline title and date (YYYY-MM-DD).") }
                let time = string("time").isEmpty ? "Not provided" : string("time")
                guard time == "Not provided" || time.range(of:#"^([01]\d|2[0-3]):[0-5]\d$"#,options:.regularExpression) != nil else { throw ModelError.message("Enter time as HH:mm, or leave blank.") }
                var rows=deadlines
                let record=Deadline(date:date,isoDate:string("date"),time:time,title:string("title"),detail:string("detail"),stableID:id.isEmpty ? "deadline-"+UUID().uuidString : id)
                if let index=rows.firstIndex(where:{$0.id==id}) { rows[index]=record } else { guard id.isEmpty else { throw ModelError.message("No deadline to edit.") }; rows.append(record) }
                let text=try DeskCodec.deadlineTable(rows,in:String(decoding:original,as:UTF8.self));try deadlineFile.save(Data(text.utf8));notice="Deadline saved. Set participation and priority separately.";reload()
            case "deleteDeadline":
                guard error == nil, let current=data, current.revision == revision,
                      let originalDeadline=deadlineFile.observed, DeskCodec.hash(originalDeadline) == string("deadlineHash"),
                      let originalDesk=deskFile.observed, let deleted=deadlines.first(where:{$0.id==id}) else {
                    throw ModelError.message("The record is stale or the deadline is missing. Refresh and try again.")
                }
                guard (try Data(contentsOf:deskFile.url)) == originalDesk else {
                    throw ModelError.message("Desk.md changed elsewhere. No overwrite occurred. Refresh before deleting.")
                }
                let rows=deadlines.filter {$0.id != id}
                let nextDeadlineText=try DeskCodec.deadlineTable(rows,in:String(decoding:originalDeadline,as:UTF8.self))
                var next=current
                next.deadlineSettings.removeValue(forKey:id)
                next.events.append(.init(id:UUID().uuidString,at:DeskCodec.iso(),actor:"user",kind:"deadline-delete",target:id,summary:deleted.title+" · Delete deadline",step:nil,before:nil,after:nil))
                next.updatedAt=DeskCodec.iso();next.revision=UUID().uuidString
                try next.validate()
                let nextDesk=try DeskCodec.replacing(next,in:originalDesk)
                try deadlineFile.save(Data(nextDeadlineText.utf8))
                do {
                    try deskFile.save(nextDesk)
                } catch let deskSaveError {
                    do { try deadlineFile.save(originalDeadline) }
                    catch let rollbackError {
                        throw ModelError.message("Deadline save and recovery failed. Check the backup before editing further. Save error: \(deskSaveError.localizedDescription) · Recovery error: \(rollbackError.localizedDescription)")
                    }
                    throw deskSaveError
                }
                notice="Deadline deleted. The previous file is backed up.";reload()
            case "snooze","hideAdvice","restoreAdvice":
                guard let d=deadlines.first(where:{$0.id==id}) else { break }
                try mutate(revision:revision,kind:"reminder",target:id,summary:"Assistant notification display changed") { next in
                    var m=next.deadlineSettings[id] ?? .initial(d)
                    if action=="snooze" { m.snoozedUntil=DeskCodec.iso(Date().addingTimeInterval(3600)) }
                    if action=="hideAdvice" { m.hiddenUntil=DeskCodec.iso(Calendar.current.date(byAdding:.day,value:1,to:Calendar.current.startOfDay(for:Date()))!) }
                    if action=="restoreAdvice" { m.hiddenUntil=nil;m.snoozedUntil=nil };next.deadlineSettings[id]=m
                }
            case "recordScore":
                try mutate(revision:revision,kind:"score",target:"portfolio",summary:"Record today’s score") { next in
                    let t=next.totals;next.history.append(.init(id:UUID().uuidString,date:DeskCodec.day(Date()),priorityTotal:Int(t["priorityTotal"]!),priorityMean:t["priorityMean"]!,total:Int(t["total"]!),mean:t["mean"]!,source:"Research Desk · User record"))
                }
            case "settings":
                let enabled=input["reminders"] as? Bool ?? false
                try mutate(revision:revision,kind:"settings",target:"desk",summary:"App settings changed") { next in
                    next.settings.reminders=enabled;next.settings.urgentDays=input["urgentDays"] as? Int ?? 7;next.settings.quietStart=input["quietStart"] as? Int ?? 21;next.settings.quietEnd=input["quietEnd"] as? Int ?? 9;next.settings.alwaysOnTop=input["alwaysOnTop"] as? Bool ?? true
                }
                onCommand?("applySettings")
                if enabled { UNUserNotificationCenter.current().requestAuthorization(options:[.alert]) { granted,err in DispatchQueue.main.async { self.notice=granted ? "Notifications enabled with quiet hours and deduplication." : "Notification permission is unavailable. The in-app assistant remains visible.";if let err { self.notice=err.localizedDescription };self.onChange?() } } }
            case "decoration":
                guard let item=DeskDecoration.all.first(where:{$0.id==id}), let visible=input["visible"] as? Bool,
                      let state=data else { throw ModelError.message("Check the decoration.") }
                let current=(state.rewards ?? DeskRewards(baselineStages:[],entries:[])).summary(in:state)
                guard !visible || (current["level"] as? Int ?? 1)>=item.level else { throw ModelError.message("This decoration is still locked.") }
                try mutate(revision:revision,kind:"preference",target:id,summary:item.name + (visible ? " Display" : " Hidden")) { next in
                    if next.rewards == nil { next.rewards=DeskRewards.recording(from:state,to:next) }
                    var shown=Set(next.rewards?.shownDecorations ?? [])
                    if visible { shown.insert(id) } else { shown.remove(id) }
                    next.rewards?.shownDecorations=shown.sorted()
                }
            case "collectionBuy","collectionEnvelope","collectionOpen","collectionDisplay","collectionFavorite","collectionMove","collectionResetPosition","collectionStickerSet","collectionStickerRemove":
                guard let state=data,var wallet=state.collectibles else { throw ModelError.message("Reopen the app to apply the collection shop update.") }
                let slot=string("slot")
                var position: DeskCollectiblePosition? = nil
                if action=="collectionMove",let x=input["x"] as? Double,let y=input["y"] as? Double { position = .init(x:x,y:y) }
                var sticker: DeskCardSticker? = nil
                if action=="collectionStickerSet",let x=input["x"] as? Double,let y=input["y"] as? Double,let size=input["size"] as? Double { sticker = .init(x:x,y:y,size:size) }
                let signature=DeskCollectibles.requestSignature(action,id:id,slot:slot,position:position,sticker:sticker)
                if let previous=wallet.requests[replyID] {
                    guard previous==signature else { throw ModelError.message("Request contents do not match.") }
                    notice="Request already applied.";onChange?();return
                }
                wallet.reconcile(state)
                try wallet.act(action,id:id,slot:slot,requestID:replyID,catalog:DeskCollectible.catalog(state),position:position,sticker:sticker)
                try mutate(revision:revision,kind:"collection",target:id,summary:action,actor:"tool") { $0.collectibles=wallet }
                notice=action=="collectionEnvelope" ? "Envelope placed on the desk." : action=="collectionOpen" ? "New collectible opened." : "Collection saved.";onChange?()
            case "activity":
                let eventID = "work:" + (replyID.isEmpty ? UUID().uuidString : replyID)
                if let saved = data?.events.first(where: { $0.id == eventID }) {
                    guard saved.kind == "activity", saved.target == id, saved.summary == string("text") else { throw ModelError.message("Work request contents do not match.") }
                    notice="Work already saved."; onChange?(); return
                }
                try mutate(revision:revision,kind:"activity",target:id,summary:string("text"),eventID:eventID) { next in guard next.projects.contains(where:{$0.id==id}),!string("text").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw ModelError.message("Enter the project and completed work.") } }
            default: throw ModelError.message("Unknown app action.")
            }
        } catch { replyOK=false;notice=error.localizedDescription;onChange?() }
    }
    func openWiki(_ relative: String) {
        let path=relative.isEmpty ? "Planning/Desk.md" : relative
        let target=wiki.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath(),base=wiki.standardizedFileURL.resolvingSymlinksInPath().path+"/"
        guard target.path.hasPrefix(base),["md","json"].contains(target.pathExtension) else { notice="Only Markdown and JSON files inside the demo wiki can be opened.";onChange?();return }
        NSWorkspace.shared.open(target)
    }
    func maybeNotify() {
        guard var state=data,error==nil,state.settings.reminders,!DeskAssistant.quiet(state.settings,now:Date()) else { return }
        let a=DeskAssistant.advice(state,deadlines:deadlines,now:Date())
        guard a.urgent,!a.deadlineID.isEmpty else { return }
        let key=DeskCodec.day(Date())+":"+a.id
        guard state.settings.lastNotificationKey != key else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                guard self.data?.revision == state.revision,let old=self.deskFile.observed else { return }
                state.settings.lastNotificationKey=key;state.updatedAt=DeskCodec.iso();state.revision=UUID().uuidString
                do { try self.deskFile.save(try DeskCodec.replacing(state,in:old));self.data=state } catch { self.notice=error.localizedDescription;self.onChange?();return }
                let content=UNMutableNotificationContent();content.title="Momo · "+a.title;content.body=a.message
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:"research-desk-"+a.deadlineID,content:content,trigger:nil)) { err in
                    if let err { DispatchQueue.main.async { self.notice="Notification failed: "+err.localizedDescription;self.onChange?() } }
                }
            }
        }
    }
    func payload() -> [String:Any] {
        var result:[String:Any]=["replyID":replyID,"replyOK":replyOK,"error":error as Any? ?? NSNull(),"notice":notice,"now":DeskCodec.iso(),"today":DeskCodec.day(Date()),"readAt":readAt,"timeZone":TimeZone.current.identifier,"deadlineHash":deadlineFile.observed.map(DeskCodec.hash) ?? "","activity":activity,"archive":archive]
        result["deadlineListSort"]=deadlineListSort
        result["timeRewardStatus"]=timeRewardStatus
        result["nags"]=nagPayload()
        guard let state=data else { result["data"]=NSNull();return result }
        result["data"]=(try? JSONSerialization.jsonObject(with:DeskCodec.encode(state))) ?? NSNull()
        result["totals"]=state.totals
        if let wallet=state.collectibles { result["collectibles"]=wallet.payload(state) }
        result["rewards"]=(state.rewards ?? DeskRewards(baselineStages:[],entries:[])).summary(in:state)
        result["advice"]=(try? JSONSerialization.jsonObject(with:DeskCodec.encode(currentAdvice()))) ?? NSNull()
        let today=Calendar.current.startOfDay(for:Date()),end=Calendar.current.date(byAdding:.month,value:1,to:today)!
        result["monthEnd"]=DeskCodec.day(end)
        result["deadlines"]=deadlines.map { d -> [String:Any] in
            let m=state.deadlineSettings[d.id] ?? .initial(d)
            return ["id":d.id,"date":d.isoDate,"time":d.time,"title":d.title,"shortTitle":DeadlineModel.shortTitle(d),"detail":d.detail,"days":Calendar.current.dateComponents([.day],from:today,to:d.date).day!,"withinMonth":d.date>=today && d.date<=end,"meta":(try? JSONSerialization.jsonObject(with:DeskCodec.encode(m))) ?? [:]]
        }
        return result
    }
}
