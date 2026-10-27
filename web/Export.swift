import Foundation
@main struct Export {
 static func main() throws {
  let root=URL(fileURLWithPath:CommandLine.arguments[1])
  let resources=root.appendingPathComponent("fixtures")
  let wiki=root.appendingPathComponent("Wiki")
  try FileManager.default.copyItem(at:resources.appendingPathComponent("Toy Wiki"),to:wiki)
  let prefs=UserDefaults(suiteName:"org.researchdesk.web.export")!
  prefs.removePersistentDomain(forName:"org.researchdesk.web.export")
  let store=DeskStore(wiki:wiki,resources:resources,prefs:prefs)
  store.initialize();store.enableTimeRewards();store.applyOctoberRewards();store.syncCollectibles()
  let calendar=DemoCalendar(resources:resources,wiki:wiki)
  calendar.refresh();store.syncTimeRewards(calendar.payload)
  var payload=store.payload()
  payload["calendar"]=calendar.payload
  payload["chat"]=["messages":[],"draft":"","busy":false,"engine":"DEMO · Prepared replies · No AI calls"] as [String:Any]
  let chat=DemoConversation(store:store,calendar:{calendar.payload})
  payload["planner"]=DemoPlanner(store:store,conversation:chat).payload
  payload["loginEnabled"]=false;payload["collapsed"]=false
  let bytes=try JSONSerialization.data(withJSONObject:payload,options:[.sortedKeys])
  try bytes.write(to:root.appendingPathComponent("seed.json"))
 }
}
