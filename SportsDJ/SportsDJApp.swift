import SwiftUI

@main
struct SportsDJApp: App {
    @StateObject private var audioPlayer = AudioPlayerService()
    @StateObject private var dataStore = DataStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioPlayer)
                .environmentObject(dataStore)
        }
    }
}
