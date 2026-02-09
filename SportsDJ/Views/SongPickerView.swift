import SwiftUI
import MediaPlayer

struct SongPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedSong: MPMediaItem?
    @Binding var songDuration: Double
    
    @State private var songs: [MPMediaItem] = []
    @State private var searchText: String = ""
    @State private var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    
    var filteredSongs: [MPMediaItem] {
        if searchText.isEmpty {
            return songs
        }
        return songs.filter { song in
            let title = song.title?.lowercased() ?? ""
            let artist = song.artist?.lowercased() ?? ""
            let search = searchText.lowercased()
            return title.contains(search) || artist.contains(search)
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                switch authorizationStatus {
                case .authorized:
                    songList
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
    
    var songList: some View {
        VStack {
            if songs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No Songs Found")
                        .font(.headline)
                    Text("Sync songs from iTunes or download from Apple Music")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxHeight: .infinity)
            } else {
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
        case .notDetermined:
            MPMediaLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    authorizationStatus = status
                    if status == .authorized {
                        loadSongs()
                    }
                }
            }
        default:
            break
        }
    }
    
    func loadSongs() {
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(
            value: false,
            forProperty: MPMediaItemPropertyIsCloudItem
        ))
        songs = query.items ?? []
    }
    
    func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
