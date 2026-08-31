import SwiftUI

@main
struct KitibApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif
    @StateObject private var state: AppState
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let s = AppState()
        _state = StateObject(wrappedValue: s)
        #if os(macOS)
        AppDelegate.state = s
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
            #if os(macOS)
                .frame(minWidth: 760, minHeight: 480)
            #else
                .onChange(of: scenePhase) { phase in
                    if phase != .active { state.saveCurrentFile() }
                }
            #endif
        }
        #if os(macOS)
        .windowToolbarStyle(.unified)
        #endif
        // Both platforms: iPadOS builds a real menu bar from these too, and
        // without them File held only the system's "Close Window" (D78).
        .commands { KitibCommands(state: state) }
    }
}
