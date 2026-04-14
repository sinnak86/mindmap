import SwiftUI

@main
struct SilentAlarmApp: App {

    @StateObject private var alarmManager = AlarmManager()
    @StateObject private var audioManager = AudioManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Ensure audio session is configured before SwiftUI loads
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmManager)
                .environmentObject(audioManager)
                .onAppear {
                    // Wire up the dependency after both objects are ready
                    alarmManager.audioManager = audioManager
                }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                // Start silent audio loop to keep app alive in background
                audioManager.startSilentLoop()
            case .active:
                // Re-check headphone state when returning to foreground
                alarmManager.audioManager = audioManager
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
