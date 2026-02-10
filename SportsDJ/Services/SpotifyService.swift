import Foundation
import UIKit

// MARK: - Spotify Track Model

struct SpotifyTrack: Identifiable, Codable {
    var id: String { uri }
    let uri: String
    let name: String
    let artist: String
    let albumName: String
    let durationMs: Int
    let artworkURL: String?
    
    var duration: Double {
        Double(durationMs) / 1000.0
    }
}

// MARK: - Spotify Service

class SpotifyService: NSObject, ObservableObject {
    static let shared = SpotifyService()
    
    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var currentTrack: SpotifyTrack?
    @Published var isPlaying: Bool = false
    @Published var playbackPosition: Double = 0
    @Published var currentArtwork: UIImage?
    @Published var errorMessage: String?
    
    // MARK: - Configuration
    // Replace these with your Spotify app credentials from developer.spotify.com
    private let clientID = "YOUR_SPOTIFY_CLIENT_ID"
    private let redirectURL = URL(string: "sportsdj://spotify-callback")!
    
    // MARK: - Private Properties
    private var accessToken: String? {
        didSet {
            UserDefaults.standard.set(accessToken, forKey: "spotifyAccessToken")
        }
    }
    
    // Note: SPTAppRemote requires the Spotify iOS SDK framework
    // For now, we'll create a placeholder that can be activated when the SDK is added
    private var appRemote: Any? // Will be SPTAppRemote when SDK is added
    
    private override init() {
        super.init()
        accessToken = UserDefaults.standard.string(forKey: "spotifyAccessToken")
        setupAppRemote()
    }
    
    // MARK: - Setup
    
    private func setupAppRemote() {
        // This will be implemented when Spotify SDK is added to the project
        // For now, this is a placeholder showing the integration points
        
        /*
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
        configuration.playURI = ""
        
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote?.connectionParameters.accessToken = accessToken
        appRemote?.delegate = self
        */
    }
    
    // MARK: - Connection
    
    func connect() {
        guard !isConnected && !isConnecting else { return }
        isConnecting = true
        
        // Check if Spotify is installed
        guard isSpotifyInstalled() else {
            errorMessage = "Spotify app is not installed. Please install Spotify to use this feature."
            isConnecting = false
            return
        }
        
        // This will trigger the Spotify app to open and authorize
        // When SDK is integrated:
        /*
        if let token = accessToken {
            appRemote?.connectionParameters.accessToken = token
            appRemote?.connect()
        } else {
            appRemote?.authorizeAndPlayURI("")
        }
        */
        
        // Placeholder for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.isConnecting = false
            self?.errorMessage = "Spotify SDK not yet integrated. Add SpotifyiOS.framework to enable."
        }
    }
    
    func disconnect() {
        /*
        appRemote?.disconnect()
        */
        isConnected = false
        currentTrack = nil
        isPlaying = false
    }
    
    // MARK: - Playback Control
    
    func play(uri: String, position: Double = 0) {
        guard isConnected else {
            errorMessage = "Not connected to Spotify"
            return
        }
        
        /*
        appRemote?.playerAPI?.play(uri, asRadio: false) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            
            if position > 0 {
                self?.seek(to: position)
            }
        }
        */
    }
    
    func pause() {
        /*
        appRemote?.playerAPI?.pause { _, error in
            if let error = error {
                print("Error pausing: \(error)")
            }
        }
        */
    }
    
    func resume() {
        /*
        appRemote?.playerAPI?.resume { _, error in
            if let error = error {
                print("Error resuming: \(error)")
            }
        }
        */
    }
    
    func seek(to position: Double) {
        /*
        appRemote?.playerAPI?.seek(toPosition: Int(position * 1000)) { _, error in
            if let error = error {
                print("Error seeking: \(error)")
            }
        }
        */
    }
    
    func stop() {
        pause()
        isPlaying = false
    }
    
    // MARK: - URL Handling
    
    func handleURL(_ url: URL) -> Bool {
        // Handle the callback from Spotify authorization
        /*
        let parameters = appRemote?.authorizationParameters(from: url)
        
        if let token = parameters?[SPTAppRemoteAccessTokenKey] {
            accessToken = token
            appRemote?.connectionParameters.accessToken = token
            appRemote?.connect()
            return true
        } else if let error = parameters?[SPTAppRemoteErrorDescriptionKey] {
            errorMessage = error
        }
        */
        return false
    }
    
    // MARK: - Helper Methods
    
    func isSpotifyInstalled() -> Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    func openSpotifyApp() {
        if let url = URL(string: "spotify:") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Artwork Loading
    
    func loadArtwork(for track: SpotifyTrack, completion: @escaping (UIImage?) -> Void) {
        guard let urlString = track.artworkURL,
              let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let image = UIImage(data: data)
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }
}

// MARK: - SPTAppRemoteDelegate Implementation
// These will be activated when the Spotify SDK is added

/*
extension SpotifyService: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        self.isConnected = true
        self.isConnecting = false
        
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { result, error in
            if let error = error {
                print("Error subscribing to player state: \(error)")
            }
        })
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        isConnected = false
        isConnecting = false
        errorMessage = error?.localizedDescription ?? "Connection failed"
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        isConnected = false
        if let error = error {
            errorMessage = error.localizedDescription
        }
    }
}

extension SpotifyService: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        isPlaying = !playerState.isPaused
        playbackPosition = Double(playerState.playbackPosition) / 1000.0
        
        let track = playerState.track
        currentTrack = SpotifyTrack(
            uri: track.uri,
            name: track.name,
            artist: track.artist.name,
            albumName: track.album.name,
            durationMs: Int(track.duration),
            artworkURL: nil
        )
        
        // Load artwork
        appRemote?.imageAPI?.fetchImage(forItem: track, with: CGSize(width: 200, height: 200)) { [weak self] image, error in
            if let image = image as? UIImage {
                self?.currentArtwork = image
            }
        }
    }
}
*/

// MARK: - Spotify Search Service (Web API)

class SpotifySearchService {
    static let shared = SpotifySearchService()
    
    private let clientID = "YOUR_SPOTIFY_CLIENT_ID"
    private let clientSecret = "YOUR_SPOTIFY_CLIENT_SECRET"
    
    private var webAPIToken: String?
    private var tokenExpiry: Date?
    
    private init() {}
    
    // Get client credentials token for search (doesn't require user auth)
    func getClientToken() async throws -> String {
        if let token = webAPIToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }
        
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let credentials = "\(clientID):\(clientSecret)"
        let base64Credentials = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct TokenResponse: Codable {
            let access_token: String
            let expires_in: Int
        }
        
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        webAPIToken = response.access_token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expires_in - 60))
        
        return response.access_token
    }
    
    // Search for tracks
    func searchTracks(query: String) async throws -> [SpotifyTrack] {
        let token = try await getClientToken()
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=track&limit=30")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct SearchResponse: Codable {
            let tracks: TracksContainer
            
            struct TracksContainer: Codable {
                let items: [TrackItem]
            }
            
            struct TrackItem: Codable {
                let uri: String
                let name: String
                let duration_ms: Int
                let artists: [Artist]
                let album: Album
                
                struct Artist: Codable {
                    let name: String
                }
                
                struct Album: Codable {
                    let name: String
                    let images: [AlbumImage]
                    
                    struct AlbumImage: Codable {
                        let url: String
                        let width: Int?
                    }
                }
            }
        }
        
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        
        return response.tracks.items.map { item in
            SpotifyTrack(
                uri: item.uri,
                name: item.name,
                artist: item.artists.map { $0.name }.joined(separator: ", "),
                albumName: item.album.name,
                durationMs: item.duration_ms,
                artworkURL: item.album.images.first?.url
            )
        }
    }
}
