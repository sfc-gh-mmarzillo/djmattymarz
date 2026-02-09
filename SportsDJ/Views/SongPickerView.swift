import SwiftUI
import MediaPlayer

struct SongPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedSong: MPMediaItem?
    @Binding var songDuration: Double
    
    @State private var searchText: String = ""
    @State private var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @State private var selectedSource: SongSource = .downloaded
    @State private var songs: [MPMediaItem] = []
    @State private var playlists: [MPMediaPlaylist] = []
    @State private var selectedPlaylist: MPMediaPlaylist?
    
    enum SongSource: String, CaseIterable {
        case downloaded = "Downloaded"
        case library = "Library"
        case playlists = "Playlists"
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
            let album = song.albumTitle?.lowercased() ?? ""
            let search = searchText.lowercased()
            return title.contains(search) || artist.contains(search) || album.contains(search)
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                switch authorizationStatus {
                case .authorized:
                    songListContent
                case .denied, .restricted:
                    permissionDeniedView
                case .notDetermined:
                    requestingPermissionView
                @unknown default:
                    requestingPermissionView
                }
            }
            .navigationTitle("Select Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                checkAuthorization()
            }
        }
    }
    
    var songListContent: some View {
        VStack(spacing: 0) {
            // Source picker
            Picker("Source", selection: $selectedSource) {
                ForEach(SongSource.allCases, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedSource) { _ in
                selectedPlaylist = nil
                loadSongs()
            }
            
            if selectedSource == .playlists && selectedPlaylist == nil {
                playlistsList
            } else if songs.isEmpty && selectedPlaylist == nil {
                emptyStateView
            } else {
                songList
            }
        }
    }
    
    var playlistsList: some View {
        List {
            if playlists.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Playlists Found")
                        .font(.headline)
                    Text("Create playlists in the Music app to see them here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(playlists, id: \.persistentID) { playlist in
                    Button(action: {
                        selectedPlaylist = playlist
                    }) {
                        HStack {
                            if let artwork = playlist.representativeItem?.artwork {
                                Image(uiImage: artwork.image(at: CGSize(width: 50, height: 50)) ?? UIImage())
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(4)
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray4))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: "music.note.list")
                                            .foregroundColor(.secondary)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name ?? "Unknown Playlist")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("\(playlist.items.count) songs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
    
    var songList: some View {
        VStack {
            if selectedPlaylist != nil {
                HStack {
                    Button(action: { selectedPlaylist = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Playlists")
                        }
                        .font(.subheadline)
                    }
                    Spacer()
                    Text(selectedPlaylist?.name ?? "")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
            
            List(filteredSongs, id: \.persistentID) { song in
                Button(action: {
                    selectedSong = song
                    songDuration = song.playbackDuration
                    dismiss()
                }) {
                    HStack {
                        if let artwork = song.artwork {
                            Image(uiImage: artwork.image(at: CGSize(width: 50, height: 50)) ?? UIImage())
                                .resizable()
                                .frame(width: 50, height: 50)
                                .cornerRadius(4)
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray4))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .foregroundColor(.secondary)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title ?? "Unknown Title")
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(song.artist ?? "Unknown Artist")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(formatDuration(song.playbackDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search songs...")
        }
    }
    
    var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: selectedSource == .downloaded ? "arrow.down.circle" : "music.note")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                
                Text(selectedSource == .downloaded ? "No Downloaded Songs" : "No Songs in Library")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("To add songs:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if selectedSource == .downloaded {
                        instructionRow(number: "1", text: "Open the Music app")
                        instructionRow(number: "2", text: "Find a song you want to use")
                        instructionRow(number: "3", text: "Tap the ••• button on the song")
                        instructionRow(number: "4", text: "Select \"Download\"")
                        instructionRow(number: "5", text: "Return here and pull to refresh")
                    } else {
                        instructionRow(number: "1", text: "Open the Music app")
                        instructionRow(number: "2", text: "Find a song or album")
                        instructionRow(number: "3", text: "Tap + or \"Add to Library\"")
                        instructionRow(number: "4", text: "Return here and pull to refresh")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Button(action: {
                    if let url = URL(string: "music://") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Open Music App", systemImage: "music.note")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: loadSongs) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxHeight: .infinity)
        }
    }
    
    func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("Music Access Required")
                .font(.headline)
            Text("Please allow access to your music library in Settings to select songs.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    var requestingPermissionView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Requesting access to your music library...")
                .foregroundColor(.secondary)
        }
    }
    
    func checkAuthorization() {
        authorizationStatus = MPMediaLibrary.authorizationStatus()
        
        switch authorizationStatus {
        case .authorized:
            loadSongs()
            loadPlaylists()
        case .notDetermined:
            MPMediaLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    authorizationStatus = status
                    if status == .authorized {
                        loadSongs()
                        loadPlaylists()
                    }
                }
            }
        default:
            break
        }
    }
    
    func loadSongs() {
        let query = MPMediaQuery.songs()
        
        switch selectedSource {
        case .downloaded:
            // Only show songs that are downloaded (not cloud items)
            query.addFilterPredicate(MPMediaPropertyPredicate(
                value: false,
                forProperty: MPMediaItemPropertyIsCloudItem
            ))
        case .library:
            // Show all songs in library (including cloud)
            break
        case .playlists:
            // Playlists are handled separately
            break
        }
        
        songs = query.items ?? []
    }
    
    func loadPlaylists() {
        let query = MPMediaQuery.playlists()
        playlists = query.collections?.compactMap { $0 as? MPMediaPlaylist } ?? []
    }
    
    func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
