import SwiftUI

@main
struct SportsDJApp: App {
    @StateObject private var audioPlayer = AudioPlayerService()
    @StateObject private var dataStore = DataStore()
    @StateObject private var spotifyService = SpotifyService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioPlayer)
                .environmentObject(dataStore)
                .environmentObject(spotifyService)
                .onOpenURL { url in
                    // Handle Spotify callback URL
                    if url.scheme == "sportsdj" {
                        _ = spotifyService.handleURL(url)
                    }
                }
        }
    }
}
