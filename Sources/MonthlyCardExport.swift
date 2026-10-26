import Foundation
import AppKit
import WebKit

// File images taint a canvas in WKWebView. Supply the bundled artwork as a
// data URL so export works without relaxing WebKit's file-origin protections.
enum MonthlyCardExport {
    static func copyPNG(_ bytes: Data, to pasteboard: NSPasteboard = .general) -> Bool {
        guard bytes.starts(with:[137,80,78,71,13,10,26,10]),let bitmap=NSBitmapImageRep(data:bytes),bitmap.pixelsWide>0,bitmap.pixelsHigh>0,let tiff=bitmap.tiffRepresentation else { return false }
        let item=NSPasteboardItem();item.setData(bytes,forType:.png);item.setData(tiff,forType:.tiff)
        pasteboard.clearContents();return pasteboard.writeObjects([item])
    }

    static func installArtwork(in controller: WKUserContentController, resources: URL) {
        guard let bytes = try? Data(contentsOf: resources.appendingPathComponent("completion-laurel-wax.png")) else { return }
        let source = "window.__DESK_EXPORT_SEAL__ = 'data:image/png;base64,\(bytes.base64EncodedString())';"
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }
}
