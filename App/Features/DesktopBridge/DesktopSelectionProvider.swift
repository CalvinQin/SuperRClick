import Foundation
import AppKit

struct DesktopSelectionProvider {
    static func getSelectedFileURLs() -> [URL] {
        let scriptSource = """
        tell application "Finder"
            try
                set theSelection to selection
                set urlList to {}
                repeat with selectedItem in theSelection
                    set end of urlList to URL of selectedItem
                end repeat
                return urlList
            on error
                return {}
            end try
        end tell
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            let output = script.executeAndReturnError(&error)
            if error != nil {
                print("AppleScript error getting Finder selection: \(error!)")
                return []
            }
            
            var urls: [URL] = []
            
            // Output is typically an NSAppleEventDescriptor list
            if output.descriptorType == typeAEList, output.numberOfItems > 0 {
                for i in 1...output.numberOfItems {
                    if let itemDescriptor = output.atIndex(i),
                       let urlString = itemDescriptor.stringValue,
                       let url = URL(string: urlString) {
                        urls.append(url)
                    }
                }
            } else if let urlString = output.stringValue, let url = URL(string: urlString) {
                // Sometimes it returns a single string if there's exactly 1 item and applescript coerces it incorrectly? Usually it's a list.
                urls.append(url)
            }
            
            // Note: Finder AppleScript returns file URLs usually like "file:///Users/haoqiqin/Desktop/file.txt/"
            return urls
        }
        return []
    }
}
