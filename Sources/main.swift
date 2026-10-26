import AppKit
import WebKit
import ServiceManagement
import UserNotifications
import UniformTypeIdentifiers

func researchDeskWikiURL() -> URL {
    let root = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Demo Data")
    let wiki = root.appendingPathComponent("Research Wiki")
    if !FileManager.default.fileExists(atPath:wiki.path) {
        try! FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        try! FileManager.default.copyItem(at:Bundle.main.resourceURL!.appendingPathComponent("Toy Wiki"),to:wiki)
    }
    return wiki
}

final class DeskPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
final class DeskApp: NSObject, NSApplicationDelegate, NSWindowDelegate, WKScriptMessageHandler, WKNavigationDelegate, UNUserNotificationCenterDelegate {
    let resources = Bundle.main.resourceURL!
    lazy var wiki: URL = researchDeskWikiURL()
    lazy var store=DeskStore(wiki:wiki,resources:resources)
    lazy var conversation=DemoConversation(store:store,calendar:{ [weak self] in self?.calendarLink?.payload ?? [:] })
    var full: NSWindow!, mini: DeskPanel!
    var fullWeb: WKWebView!, miniWeb: WKWebView!
    var status: NSStatusItem!
    var calendarLink: DemoCalendar?
    var calendarTimer: Timer?
    var planner: DemoPlanner?
    var plannerTimer: Timer?
    var cloudStatus: NSMenuItem?
    var backupStatus: NSMenuItem?
    var pendingCloudURLs: [URL] = []
    var collapsed=false
    func web(mode: String) -> WKWebView {
        let config=WKWebViewConfiguration();config.userContentController.add(self,name:"deskAction")
        config.userContentController.addUserScript(WKUserScript(source:"window.__DESK_MODE__ = '\(mode)';",injectionTime:.atDocumentStart,forMainFrameOnly:true))
        MonthlyCardExport.installArtwork(in:config.userContentController,resources:resources)
        config.preferences.javaScriptCanOpenWindowsAutomatically=false
        let view=WKWebView(frame:.zero,configuration:config)
        view.navigationDelegate=self
        view.loadFileURL(resources.appendingPathComponent("index.html"),allowingReadAccessTo:resources)
        return view
    }
    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate=self
        full=NSWindow(contentRect:NSRect(x:0,y:0,width:1180,height:850),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        full.title="Research Desk Demo · TOY DATA";full.minSize=NSSize(width:850,height:620);full.isReleasedWhenClosed=false
        full.backgroundColor = .white;full.delegate=self
        full.setFrameAutosaveName("ResearchDeskFull");if !full.setFrameUsingName("ResearchDeskFull") { full.center() }
        fullWeb=web(mode:"full");full.contentView=fullWeb
        mini=DeskPanel(contentRect:NSRect(x:0,y:0,width:385,height:680),styleMask:[.titled,.closable,.resizable,.nonactivatingPanel],backing:.buffered,defer:false)
        mini.title="Demo · TOY DATA";mini.isReleasedWhenClosed=false;mini.minSize=NSSize(width:340,height:125);mini.maxSize=NSSize(width:560,height:1400)
        mini.hidesOnDeactivate=false;mini.isFloatingPanel=true;mini.delegate=self
        mini.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.canJoinAllApplications]
        mini.backgroundColor = .white
        mini.setFrameAutosaveName("ResearchDeskMini")
        if !mini.setFrameUsingName("ResearchDeskMini"),let screen=NSScreen.main {
            let area=screen.visibleFrame;mini.setFrameOrigin(NSPoint(x:area.maxX-405,y:max(area.minY,area.maxY-720)))
        }
        miniWeb=web(mode:"mini");mini.contentView=miniWeb
        store.onChange={ [weak self] in self?.planner?.tick();self?.push() }
        store.onCommand={ [weak self] action in self?.command(action) }
        conversation.onChange={ [weak self] in self?.push() }
        store.start();store.enableTimeRewards();store.applyOctoberRewards();store.syncCollectibles();applySettings()
        calendarLink=DemoCalendar(resources:resources,wiki:wiki)
        planner=DemoPlanner(store:store,conversation:conversation)
        planner?.onChange={ [weak self] in self?.push() }
        calendarLink?.refresh()
        store.syncTimeRewards(calendarLink!.payload)
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        status.button?.image=NSImage(systemSymbolName:"note.text",accessibilityDescription:"Research Desk Demo")
        let menu=NSMenu()
        for (title,selector,key) in [("Research Desk Open",#selector(showFull),""),("Show mini window",#selector(showMini),""),("Hide mini window",#selector(hideMini),""),("Open wiki",#selector(openWiki),""),("Refresh",#selector(refresh),"r"),("Launch at login",#selector(toggleLogin),""),("Quit",#selector(quit),"q")] {
            let item=menu.addItem(withTitle:title,action:selector,keyEquivalent:key);item.target=self
        }
        status.menu=menu
        let demoItem=menu.addItem(withTitle:"Demo guide · External connections are simulated",action:#selector(connectCloud),keyEquivalent:"")
        demoItem.target=self
        mini.orderFrontRegardless();showFull()
    }
    func applySettings() { mini?.level = store.data?.settings.alwaysOnTop == false ? .normal : .floating }
    func push() {
        var payload=store.payload()
        payload["loginEnabled"]=SMAppService.mainApp.status == .enabled
        payload["collapsed"]=collapsed
        payload["calendar"]=calendarLink?.payload ?? ["status":"loading","windows":[],"personalExcluded":true]
        payload["planner"]=planner?.payload ?? [:]
        for view in [fullWeb,miniWeb] {
            var projected=payload
            if view === fullWeb { projected["chat"]=conversation.payload }
            guard let json=try? JSONSerialization.data(withJSONObject:projected,options:[.sortedKeys]),let text=String(data:json,encoding:.utf8) else { continue }
            view?.evaluateJavaScript("window.Desk && window.Desk.receive(\(text));",completionHandler:nil)
        }
    }
    func userContentController(_ userContentController: WKUserContentController,didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,let view=message.webView,view==fullWeb || view==miniWeb,
              view.url?.isFileURL==true,view.url?.lastPathComponent=="index.html",let body=message.body as? [String:Any] else { return }
        let externalActions=["openProjectLiterature","sendToLiquidText","importFromLiquidText","openProjectReferences","refreshLiteratureReferences","openLiteratureWiki","openURL"]
        if externalActions.contains(body["action"] as? String ?? "") { connectCloud();return }
        if let action=body["action"] as? String, action.hasPrefix("chat") {
            guard view === fullWeb else { return }
            conversation.handle(body);return
        }
        if let action=body["action"] as? String, action.hasPrefix("planner") { planner?.handle(body);return }
        if body["action"] as? String == "collapse" {
            collapsed.toggle();var frame=mini.frame;let h:CGFloat=collapsed ? 125 : 700;frame.origin.y+=frame.height-h;frame.size.height=h;mini.setFrame(frame,display:true);push();return
        }
        if ["exportMonthlyCard","copyMonthlyCard"].contains(body["action"] as? String ?? "") {
            guard view === fullWeb, let month=body["month"] as? String,
                  month.range(of:"^[0-9]{4}-[0-9]{2}$",options:.regularExpression) != nil,
                  let encoded=body["png"] as? String, encoded.utf8.count<8_000_000,
                  let bytes=Data(base64Encoded:encoded), bytes.starts(with:[137,80,78,71,13,10,26,10]) else {
                store.notice="Could not validate image data. Try again.";push();return
            }
            if body["action"] as? String == "copyMonthlyCard" {
                store.notice=MonthlyCardExport.copyPNG(bytes) ? "Copied the card image, including stickers." : "Could not copy image. Try again."
                push();return
            }
            let panel=NSSavePanel();panel.nameFieldStringValue="Research-Desk-"+month+".png"
            panel.title="Save monthly achievement card";panel.allowedContentTypes=[.png]
            NSApp.activate(ignoringOtherApps:true)
            full.makeKeyAndOrderFront(nil)
            panel.beginSheetModal(for:full) { response in
                guard response == .OK,let url=panel.url else { return }
                do { try bytes.write(to:url,options:.atomic);self.store.notice="Monthly achievement card saved." }
                catch { self.store.notice="Image save failed: \(error.localizedDescription)" }
                self.push()
            }
            return
        }
        store.handle(body)
    }
    func webView(_ webView: WKWebView,decidePolicyFor navigationAction: WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void) {
        guard let url=navigationAction.request.url else { decisionHandler(.cancel);return }
        if url.isFileURL && url.standardizedFileURL.path.hasPrefix(resources.standardizedFileURL.path+"/") { decisionHandler(.allow) }
        else { if navigationAction.navigationType == .linkActivated,["https","http"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) };decisionHandler(.cancel) }
    }
    func webView(_ webView: WKWebView,didFinish navigation: WKNavigation!) {
        push()
        if webView==fullWeb,let index=CommandLine.arguments.firstIndex(of:"--snapshot"),CommandLine.arguments.count>index+1 {
            let output=CommandLine.arguments[index+1]
            let pageIndex=CommandLine.arguments.firstIndex(of:"--page")
            let page=pageIndex.flatMap { CommandLine.arguments.count>$0+1 ? CommandLine.arguments[$0+1] : nil } ?? "pipeline"
            let safe=["pipeline","history","deadlines","assistant","office","plans","time","notes"].contains(page) ? page : "pipeline"
            DispatchQueue.main.asyncAfter(deadline:.now()+1) {
                webView.evaluateJavaScript("window.Desk.showPage('\(safe)')") { _,_ in
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.4) {
                        webView.evaluateJavaScript("document.body.innerText") { value,_ in if let text=value as? String { try? text.write(toFile:output+".txt",atomically:true,encoding:.utf8) } };webView.takeSnapshot(with:nil) { image,error in
                            guard let image,let tiff=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff),let png=bitmap.representation(using:.png,properties:[:]) else { fputs("Snapshot failed: \(String(describing:error))\n",stderr);NSApp.terminate(nil);return }
                            do { try png.write(to:URL(fileURLWithPath:output)) } catch { fputs("\(error)\n",stderr) };NSApp.terminate(nil)
                        }
                    }
                }
            }
        }
    }
    func command(_ action:String) {
        switch action {
        case "full":showFull()
        case "mini":showMini()
        case "hideMini":hideMini()
        case "quit":quit()
        case "login":toggleLogin()
        case "applySettings":applySettings()
        case "calendarRefresh":calendarLink?.refresh(force:true)
        default:break
        }
    }
    @objc func showFull() { full.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true) }
    @objc func showMini() { mini.orderFrontRegardless() }
    @objc func hideMini() { mini.orderOut(nil) }
    @objc func openWiki() { store.openWiki("Planning/Desk.md") }
    @objc func refresh() { store.reload() }
    @objc func connectCloud() {
        let alert=NSAlert();alert.messageText="TOY DATA · Research Desk Demo"
        alert.informativeText="All papers, deadlines, plans and time records are fictional. Edits stay in Demo Data. AI chat, calendar and literature connections are simulated. No real accounts, wiki, mobile sync or production backups are connected."
        alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func toggleLogin() { connectCloud() }
    func windowDidMove(_ notification:Notification) { if notification.object as? NSWindow === mini { mini.saveFrame(usingName:"ResearchDeskMini") } }
    func windowShouldClose(_ sender:NSWindow)->Bool { sender.orderOut(nil);return false }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool { showFull();return true }
    func applicationWillTerminate(_ notification:Notification) { planner?.shutdown();conversation.shutdown() }
    func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping(UNNotificationPresentationOptions)->Void) { completionHandler([.banner,.list]) }
}
let app=NSApplication.shared
let delegate=DeskApp()
app.delegate=delegate
app.run()
