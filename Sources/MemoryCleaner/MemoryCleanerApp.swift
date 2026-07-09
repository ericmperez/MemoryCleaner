import SwiftUI

@main
struct MemoryCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 440, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
