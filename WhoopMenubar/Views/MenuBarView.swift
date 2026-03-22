import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let nsImage = menuBarImage {
            Image(nsImage: nsImage)
        } else {
            Text("RB")
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
    }

    private var menuBarImage: NSImage? {
        guard let original = NSImage(named: "MenuBarIcon") else { return nil }

        let targetSize = NSSize(width: 18, height: 18)
        let resized = NSImage(size: targetSize, flipped: false) { rect in
            original.draw(in: rect)
            return true
        }
        resized.isTemplate = true
        return resized
    }
}
