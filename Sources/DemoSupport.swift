import Foundation

final class DemoCalendar {
    var payload: [String:Any]
    init(resources: URL,wiki: URL) {
        payload=(try? JSONSerialization.jsonObject(with:Data(contentsOf:resources.appendingPathComponent("demo-calendar.json")))) as? [String:Any] ?? [:]
    }
    func refresh(force: Bool = false) { payload["fetchedAt"]=DeskCodec.iso() }
}
final class DemoConversation {
    let store: DeskStore
    var onChange: (() -> Void)?
    var messages: [[String:Any]]=[]
    var draft=""
    var file: URL { store.wiki.deletingLastPathComponent().appendingPathComponent("demo-conversation.json") }
    func save() { if let bytes=try? JSONSerialization.data(withJSONObject:["messages":messages,"draft":draft]) { try? bytes.write(to:file,options:.atomic) } }
    var payload: [String:Any] { ["messages":messages,"draft":draft,"busy":false,"engine":"DEMO · Simulated replies · No AI calls"] }
    init(store: DeskStore,calendar: @escaping () -> [String:Any]) { self.store=store
        if let bytes=try? Data(contentsOf:file),let data=(try? JSONSerialization.jsonObject(with:bytes)) as? [String:Any] { messages=data["messages"] as? [[String:Any]] ?? [];draft=data["draft"] as? String ?? "" }
    }
    func handle(_ body: [String:Any]) {
        let action=body["action"] as? String ?? ""
        if action=="chatDraft" { draft=body["text"] as? String ?? "";save();return }
        if action=="chatClear" { messages=[];draft="" }
        if action=="chatSend" {
            let text=body["text"] as? String ?? ""
            messages.append(["role":"user","text":text]);draft=""
            let p=store.data?.projects.first
            let title=p?.title ?? "Fictional paper"
            let response=text.localizedCaseInsensitiveContains("why") ? "[Simulated reply] \(title) has the nearest fictional deadline. This is a simulated response, with no AI or personal calendar access." : "[Simulated reply] Spend 30 minutes polishing the opening paragraph of \(title), then check the toy table. This is a prepared demonstration response."
            var reply: [String:Any]=["role":"assistant","text":response,"sources":["Toy projects","Fictional deadlines"]]
            if text.contains("Work record") || text.localizedCaseInsensitiveContains("remind") {
                var proposal:[String:Any]=["id":UUID().uuidString,"projectID":p?.id ?? "toy-01","projectTitle":title]
                proposal[text.localizedCaseInsensitiveContains("remind") ? "nag" : "activity"]=text
                reply["proposal"]=proposal;reply["outcome"]="pending";reply["text"]="[Simulated reply] Confirm below to save only to demo data."
            }
            messages.append(reply)
        }
        if ["chatConfirm","chatDismiss"].contains(action), let id=body["proposalID"] as? String,
           let index=messages.firstIndex(where:{ ($0["proposal"] as? [String:Any])?["id"] as? String == id }),messages[index]["outcome"] as? String == "pending",
           let proposal=messages[index]["proposal"] as? [String:Any] {
            if action=="chatConfirm" {
                let pid=proposal["projectID"] as? String ?? ""
                if let nag=proposal["nag"] as? String { try? store.addNag(projectID:pid,text:nag) }
                else { store.handle(["action":"activity","id":pid,"text":proposal["activity"] as? String ?? "Demo activity","revision":store.data?.revision ?? "","requestID":id]) }
            }
            messages[index]["outcome"]="done"; messages[index]["outcomeText"]=action=="chatConfirm" ? "Saved to demo data." : "Not recorded."
        }
        save();onChange?()
    }
    func shutdown() {}
}
final class DemoPlanner {
    let store: DeskStore
    var onChange: (() -> Void)?
    var enabled=true
    var hidden=Set<String>()
    var payload: [String:Any] {
        let projects=Array((store.data?.projects ?? []).prefix(3))
        let recs:[[String:Any]]=projects.filter{!hidden.contains($0.id)}.map { p in
            ["id":p.id,"projectID":p.id,"task":p.nextAction,"kind":"work","minutes":30,"reason":"Simulated suggestion based on fictional priorities and next actions.","sourceLabels":["Synthetic project: "+p.title]]
        }
        return ["enabled":enabled,"busy":false,"note":"Simulated suggestions · No AI calls","summary":"Demonstrating next actions with fictional projects.","generatedAt":DeskCodec.iso(),"recommendations":enabled ? recs : [],"uncertainties":["All calendar events and research records are fictional."],"personalWarning":"No real calendar connection."]
    }
    init(store: DeskStore,conversation: DemoConversation) { self.store=store }
    func tick() {}
    func handle(_ body:[String:Any]) {
        switch body["action"] as? String {
        case "plannerToggle":enabled.toggle()
        case "plannerDone","plannerDefer":hidden.insert(body["id"] as? String ?? "")
        case "plannerRefresh":hidden=[]
        default:break
        }
        onChange?()
    }
    func shutdown() {}
}
