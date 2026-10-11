import SwiftUI
import SwiftData

@main
struct LogJamApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WorkRecord.self, EncounterRecord.self])
    }
}
