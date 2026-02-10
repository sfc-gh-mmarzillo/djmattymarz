import SwiftUI
import MediaPlayer

struct SongPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedSong: MPMediaItem?
    @Binding var songDuration: Double
    
    // For Spotify selection
    var onSpotifySelect: ((SpotifyTrack) -> Void)?
    
    @State private var searchText: String = ""
    @State private var songs: [MPMediaItem] = []
    @State private var playlists: [MPMediaPlaylist] = []
    @State private var selectedPlaylist: MPMediaPlaylist?
    @State private var selectedSource: SongSource = .library
    @State private var hasPermission: Bool = false
    @State private var isCheckingPermission: Bool = true
    
    // Spotify
    @State private var spotifyTracks: [SpotifyTrack] = []
    @State private var isSearchingSpotify: Bool = false
    @State private var spotifyError: String?
    @StateObject private var spotifyService = SpotifyService.shared
    
    enum SongSource: String, CaseIterable {
        case library = "Library"
        case playlists = "Playlists"
        case spotify = "Spotify"
    }
    
    var filteredSongs: [MPMediaItem] {
        let sourceSongs: [MPMediaItem]
        
        if let playlist = selectedPlaylist {
            sourceSongs = playlist.items
        } else {
            sourceSongs = songs
        }
        
        if searchText.isEmpty {
            return sourceSongs
        }
        return sourceSongs.filter { song in
            let title = song.title?.lowercased() ?? ""
            let artist = song.artist?.lowercased() ?? ""
            let search = searchText.lowercased()
            return title.contains(search) || artist.contains(search)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [
                        Color(hex: "#1a1a2e"),
                        Color(hex: "#16213e"),
                        Color(hex: "#0f0f23")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Source selector
                    sourceSelector
                    
                    // Search bar
                    searchBar
                    
                    // Content
                    if isCheckingPermission && selectedSource != .spotify {
                        loadingView
                    } else if !hasPermission && selectedSource != .spotify {
                        permissionView
                    } else {
                        contentView
                    }
                }
            }
            .navigationTitle("Select Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
            .toolbarBackground(Color(hex: "#1a1a2e"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                checkMusicLibraryPermission()
            }
        }
    }
    
    // MARK: - Source Selector
    
    private var sourceSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SongSource.allCases, id: \.self) { source in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedSource = source
                            selectedPlaylist = nil
                            if source == .spotify && !searchText.isEmpty {
                                searchSpotify()
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: iconForSource(source))
                                .font(.subheadline)
                            Text(source.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedSource == source ? .semibold : .medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedSource == source ?
                            LinearGradient(colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(selectedSource == source ? .white : .gray)
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private func iconForSource(_ source: SongSource) -> String {
        switch source {
        case .library: return "music.note.list"
        case .playlists: return "music.note.list"
        case .spotify: return "music.note"
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search songs...", text: $searchText)
                .foregroundColor(.white)
                .onChange(of: searchText) { _ in
                    if selectedSource == .spotify && !searchText.isEmpty {
                        searchSpotifyDebounced()
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedSource {
        case .library:
            libraryListView
        case .playlists:
            playlistsView
        case .spotify:
            spotifyView
        }
    }
    
    // MARK: - Library List View
    
    private var libraryListView: some View {
        Group {
            if filteredSongs.isEmpty {
                emptyLibraryView
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredSongs, id: \.persistentID) { song in
                            SongRow(song: song) {
                                selectedSong = song
                                songDuration = song.playbackDuration
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private var emptyLibraryView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: "#6366f1").opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "music.note")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "#6366f1"))
            }
            
            VStack(spacing: 8) {
                Text("No Songs Found")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Add music to your library in the\nApple Music app")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: openMusicApp) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open Music App")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Playlists View
    
    private var playlistsView: some View {
        Group {
            if let playlist = selectedPlaylist {
                // Show playlist contents
                VStack(spacing: 0) {
                    // Back button
                    Button(action: { selectedPlaylist = nil }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("All Playlists")
                            Spacer()
                        }
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#6366f1"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    
                    if filteredSongs.isEmpty {
                        emptyPlaylistView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(filteredSongs, id: \.persistentID) { song in
                                    SongRow(song: song) {
                                        selectedSong = song
                                        songDuration = song.playbackDuration
                                        dismiss()
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            } else {
                // Show playlists list
                if playlists.isEmpty {
                    emptyPlaylistsView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(playlists, id: \.persistentID) { playlist in
                                PlaylistRow(playlist: playlist) {
                                    selectedPlaylist = playlist
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
    
    private var emptyPlaylistView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("This playlist is empty")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
    }
    
    private var emptyPlaylistsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: "#6366f1").opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "#6366f1"))
            }
            
            VStack(spacing: 8) {
                Text("No Playlists")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Create playlists in the Music app\nto see them here")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Spotify View
    
    private var spotifyView: some View {
        Group {
            if !spotifyService.isConnected {
                spotifyConnectView
            } else if searchText.isEmpty {
                spotifySearchPromptView
            } else if isSearchingSpotify {
                loadingView
            } else if let error = spotifyError {
                spotifyErrorView(error)
            } else if spotifyTracks.isEmpty {
                spotifyNoResultsView
            } else {
                spotifyResultsView
            }
        }
    }
    
    private var spotifyConnectView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: "#1DB954").opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "music.note")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "#1DB954"))
            }
            
            VStack(spacing: 8) {
                Text("Connect to Spotify")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Link your Spotify account to\nbrowse and add songs")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { spotifyService.connect() }) {
                HStack {
                    Image(systemName: "link")
                    Text("Connect Spotify")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color(hex: "#1DB954"))
                .cornerRadius(30)
            }
            
            if !spotifyService.isSpotifyInstalled() {
                VStack(spacing: 8) {
                    Text("Spotify app required")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Button("Get Spotify") {
                        if let url = URL(string: "https://apps.apple.com/app/spotify-music-and-podcasts/id324684580") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(Color(hex: "#6366f1"))
                }
            }
            
            Spacer()
        }
    }
    
    private var spotifySearchPromptView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("Search for songs on Spotify")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Type in the search bar above")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    private func spotifyErrorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                searchSpotify()
            }
            .foregroundColor(Color(hex: "#6366f1"))
            
            Spacer()
        }
        .padding()
    }
    
    private var spotifyNoResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No results found")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    private var spotifyResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(spotifyTracks) { track in
                    SpotifyTrackRow(track: track) {
                        onSpotifySelect?(track)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Loading & Permission Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    private var permissionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: "#f43f5e").opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "lock.shield")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "#f43f5e"))
            }
            
            VStack(spacing: 8) {
                Text("Music Access Required")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("SportsDJ needs access to your music\nlibrary to play songs")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: openSettings) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkMusicLibraryPermission() {
        isCheckingPermission = true
        
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                hasPermission = (status == .authorized)
                isCheckingPermission = false
                
                if hasPermission {
                    loadMusicLibrary()
                }
            }
        }
    }
    
    private func loadMusicLibrary() {
        let query = MPMediaQuery.songs()
        songs = query.items ?? []
        
        let playlistQuery = MPMediaQuery.playlists()
        playlists = playlistQuery.collections?.compactMap { $0 as? MPMediaPlaylist } ?? []
    }
    
    private func openMusicApp() {
        if let url = URL(string: "music://") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Spotify Search
    
    private var searchDebounceTimer: Timer?
    
    private func searchSpotifyDebounced() {
        searchDebounceTimer?.invalidate()
        // Simple debounce - search after 0.5s of no typing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            if !searchText.isEmpty && selectedSource == .spotify {
                searchSpotify()
            }
        }
    }
    
    private func searchSpotify() {
        guard !searchText.isEmpty else { return }
        
        isSearchingSpotify = true
        spotifyError = nil
        
        Task {
            do {
                let tracks = try await SpotifySearchService.shared.searchTracks(query: searchText)
                await MainActor.run {
                    spotifyTracks = tracks
                    isSearchingSpotify = false
                }
            } catch {
                await MainActor.run {
                    spotifyError = error.localizedDescription
                    isSearchingSpotify = false
                }
            }
        }
    }
}

// MARK: - Song Row

struct SongRow: View {
    let song: MPMediaItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Artwork
                if let artwork = song.artwork?.image(at: CGSize(width: 50, height: 50)) {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title ?? "Unknown")
                        .font(.body)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(song.artist ?? "Unknown Artist")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
        }
    }
}

// MARK: - Playlist Row

struct PlaylistRow: View {
    let playlist: MPMediaPlaylist
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Artwork
                if let artwork = playlist.representativeItem?.artwork?.image(at: CGSize(width: 50, height: 50)) {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#6366f1").opacity(0.3), Color(hex: "#8b5cf6").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .foregroundColor(.white.opacity(0.6))
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name ?? "Unknown Playlist")
                        .font(.body)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(playlist.items.count) songs")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
        }
    }
}

// MARK: - Spotify Track Row

struct SpotifyTrackRow: View {
    let track: SpotifyTrack
    let onSelect: () -> Void
    
    @State private var artwork: UIImage?
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Artwork
                if let artwork = artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#1DB954").opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(Color(hex: "#1DB954"))
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(.body)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Spotify badge
                Image(systemName: "music.note")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#1DB954"))
                    .padding(4)
                    .background(Color(hex: "#1DB954").opacity(0.2))
                    .cornerRadius(4)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
        }
        .onAppear {
            loadArtwork()
        }
    }
    
    private func loadArtwork() {
        guard let urlString = track.artworkURL,
              let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.artwork = image
                }
            }
        }.resume()
    }
}
