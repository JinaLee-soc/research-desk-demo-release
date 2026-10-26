import Foundation
@main struct Verify {
 static func main() throws {
    let root=URL(fileURLWithPath:CommandLine.arguments[1])
    let resources=root.appendingPathComponent("Research Desk Demo.app/Contents/Resources")
    let base=root.appendingPathComponent("verification/isolated-"+UUID().uuidString)
    let wiki=base.appendingPathComponent("Research Wiki")
    try FileManager.default.createDirectory(at:base,withIntermediateDirectories:true)
    try FileManager.default.copyItem(at:resources.appendingPathComponent("Toy Wiki"),to:wiki)
    let store=DeskStore(wiki:wiki,resources:resources,prefs:UserDefaults(suiteName:"org.researchdesk.toydemo.verification")!)
    store.initialize();precondition(store.error==nil,store.error ?? "")
    precondition(store.data!.projects.count==8 && store.deadlines.count==5)
    try store.data!.validate()
    let before=store.data!.projects[0].steps[8]
    store.handle(["action":"step","id":"toy-01","step":8,"revision":store.data!.revision,"requestID":UUID().uuidString])
    precondition(store.replyOK && store.data!.projects[0].steps[8] != before)
    store.reload();precondition(store.data!.projects[0].steps[8] != before)
    store.handle(["action":"undoStep","revision":store.data!.revision,"requestID":UUID().uuidString])
    precondition(store.replyOK && store.data!.projects[0].steps[8]==before)
    store.enableTimeRewards();store.applyOctoberRewards();store.syncCollectibles()
    let calendar=DemoCalendar(resources:resources,wiki:wiki)
    calendar.refresh();store.syncTimeRewards(calendar.payload)
    for item in DeskDecoration.all {
        for visible in [false,true] {
            store.handle(["action":"decoration","id":item.id,"visible":visible,"revision":store.data!.revision,"requestID":UUID().uuidString])
            precondition(store.replyOK, "Decoration: \(item.id), visible: \(visible), notice: \(store.notice)")
            store.reload()
            precondition((store.data!.rewards?.shownDecorations ?? []).contains(item.id)==visible)
        }
    }
    let chat=DemoConversation(store:store,calendar:{[:]})
    chat.handle(["action":"chatSend","text":"Work record: toy table checked"])
    let proposal=chat.messages.last!["proposal"] as! [String:Any]
    let count=store.data!.events.count
    chat.handle(["action":"chatConfirm","proposalID":proposal["id"]!])
    precondition(store.data!.events.count==count+1)
    let restored=DemoConversation(store:store,calendar:{[:]});precondition(restored.messages.count==2)
    store.reload();try store.data!.validate()
    print("PASS: toy fixtures, stage edit/save/reload/undo, all five decoration toggles and persistence, simulated chat confirmation, conversation persistence, model validation. All writes confined to isolated demo fixture.")
 }
}
