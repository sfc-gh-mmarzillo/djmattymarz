import SwiftUI

@main
struct SportsDJApp: App {
    @StateObject private var audioPlayer = AudioPlayerService()
    @StateObject private var dataStore = DataStore()
    @StateObject private var spotifyService = SpotifyService.shared
    
    init() {
        // Link will be set in onAppear since StateObjects aren't ready in init
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioPlayer)
                .environmentObject(dataStore)
                .environmentObject(spotifyService)
                .onAppear {
                    // Connect audio player to data store for dynamic voice lookup
                    audioPlayer.dataStore = dataStore
                }
                .onOpenURL { url in
                    // Handle Spotify callback URL
                    if url.scheme == "sportsdj" {
                        _ = spotifyService.handleURL(url)
                    }
                }
        }
    }
}
