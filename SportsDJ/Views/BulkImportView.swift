import SwiftUI
import MediaPlayer

struct BulkImportView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedSongs: Set<UInt64> = []
    @State private var songs: [MPMediaItem] = []
    @State private var searchText = ""
    @State private var showingConfig = false
    @State private var hasPermission = false
    @State private var isLoading = true
    
    // Bulk config settings
    @State private var selectedCategories: Set<String> = []
    @State private var selectedColor = "#6366f1"
    @State private var useStartOfSong = true
    
    let maxSelection = 50
    
    let colorOptions = [
        "#6366f1", "#8b5cf6", "#ec4899", "#f43f5e",
        "#f97316", "#eab308", "#22c55e", "#14b8a6",
        "#06b6d4", "#3b82f6"
    ]
    
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
            ZStack {
                // Background
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
                
                if showingConfig {
                    bulkConfigView
                } else {
                    songSelectionView
                }
            }
            .navigationTitle(showingConfig ? "Configure Import" : "Select Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showingConfig ? "Back" : "Cancel") {
                        if showingConfig {
                            showingConfig = false
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if showingConfig {
                        Button("Import \(selectedSongs.count)") {
                            importSongs()
                        }
                        .font(.body.weight(.semibold))
                        .foregroundColor(Color(hex: "#6366f1"))
                    } else {
                        Button("Next") {
                            showingConfig = true
                        }
                        .font(.body.weight(.semibold))
                        .foregroundColor(selectedSongs.isEmpty ? .gray : Color(hex: "#6366f1"))
                        .disabled(selectedSongs.isEmpty)
                    }
                }
            }
            .onAppear {
                checkPermissionAndLoad()
                
                // Apply default settings
                let defaults = dataStore.defaultSettings
                selectedColor = defaults.colorHex
                useStartOfSong = defaults.startFromBeginning
                for category in defaults.defaultCategories {
                    selectedCategories.insert(category)
                }
            }
        }
    }
    
    // MARK: - Song Selection View
    
    private var songSelectionView: some View {
        VStack(spacing: 0) {
            // Selection counter
            selectionHeader
            
            // Search bar
            searchBar
            
            // Song list
            if isLoading {
                loadingView
            } else if !hasPermission {
                permissionView
            } else if filteredSongs.isEmpty {
                emptyView
            } else {
                songListView
            }
        }
    }
    
    private var selectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedSongs.count) of \(maxSelection) selected")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                
                Text("Tap songs to select them for bulk import")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if !selectedSongs.isEmpty {
                Button("Clear All") {
                    selectedSongs.removeAll()
                }
                .font(.caption.weight(.medium))
                .foregroundColor(Color(hex: "#f43f5e"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search songs...", text: $searchText)
                .foregroundColor(.white)
            
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
        .padding(.vertical, 12)
    }
    
    private var songListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredSongs, id: \.persistentID) { song in
                    BulkSongRow(
                        song: song,
                        isSelected: selectedSongs.contains(song.persistentID),
                        isDisabled: selectedSongs.count >= maxSelection && !selectedSongs.contains(song.persistentID)
                    ) {
                        toggleSong(song)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    private func toggleSong(_ song: MPMediaItem) {
        if selectedSongs.contains(song.persistentID) {
            selectedSongs.remove(song.persistentID)
        } else if selectedSongs.count < maxSelection {
            selectedSongs.insert(song.persistentID)
        }
    }
    
    // MARK: - Bulk Config View
    
    private var bulkConfigView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary
                summaryCard
                
                // Categories
                categoriesCard
                
                // Color
                colorCard
                
                // Start time option
                startTimeCard
            }
            .padding(16)
        }
    }
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Import Summary", systemImage: "doc.on.doc")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(selectedSongs.count) songs")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    
                    Text("will be imported to the current event")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "music.note.list")
                    .font(.title)
                    .foregroundColor(Color(hex: "#6366f1"))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#6366f1").opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Categories (Optional)", systemImage: "tag")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            Text("Apply categories to all imported songs")
                .font(.caption)
                .foregroundColor(.gray)
            
            if dataStore.filteredCategories.isEmpty {
                Text("No categories available")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(dataStore.filteredCategories) { category in
                            Button(action: {
                                if selectedCategories.contains(category.name) {
                                    selectedCategories.remove(category.name)
                                } else {
                                    selectedCategories.insert(category.name)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: category.iconName)
                                        .font(.caption2)
                                    Text(category.name)
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundColor(selectedCategories.contains(category.name) ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategories.contains(category.name) ?
                                    Color(hex: category.colorHex) :
                                    Color.white.opacity(0.1)
                                )
                                .cornerRadius(16)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }
    
    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Button Color", systemImage: "paintpalette")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 10) {
                ForEach(colorOptions, id: \.self) { color in
                    Button(action: { selectedColor = color }) {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                            )
                            .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
        .animation(.spring(response: 0.3), value: selectedColor)
    }
    
    private var startTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Start Time", systemImage: "clock")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                Button(action: { useStartOfSong = true }) {
                    HStack {
                        Image(systemName: useStartOfSong ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(useStartOfSong ? Color(hex: "#6366f1") : .gray)
                        Text("Start from beginning (0:00)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(useStartOfSong ? 0.1 : 0.05))
                    .cornerRadius(10)
                }
                
                Button(action: { useStartOfSong = false }) {
                    HStack {
                        Image(systemName: !useStartOfSong ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(!useStartOfSong ? Color(hex: "#6366f1") : .gray)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Edit start times individually")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Text("You can adjust each song after import")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(!useStartOfSong ? 0.1 : 0.05))
                    .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }
    
    // MARK: - Helper Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("Loading library...")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    private var permissionView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "#f43f5e"))
            Text("Music Access Required")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            Text("Please grant access to your music library in Settings")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No songs found")
                .font(.headline)
                .foregroundColor(.white)
            Text("Add songs to your Music library first")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    // MARK: - Methods
    
    private func checkPermissionAndLoad() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                hasPermission = (status == .authorized)
                isLoading = false
                
                if hasPermission {
                    loadSongs()
                }
            }
        }
    }
    
    private func loadSongs() {
        let query = MPMediaQuery.songs()
        songs = query.items ?? []
    }
    
    private func importSongs() {
        let selectedItems = songs.filter { selectedSongs.contains($0.persistentID) }
        
        for song in selectedItems {
            let button = SoundButton(
                name: song.title ?? "Unknown",
                songPersistentID: song.persistentID,
                musicSource: .appleMusic,
                startTimeSeconds: useStartOfSong ? 0 : 0,
                categoryTags: Array(selectedCategories),
                colorHex: selectedColor,
                eventID: dataStore.selectedEventID
            )
            dataStore.addButton(button)
        }
        
        dismiss()
    }
}

// MARK: - Bulk Song Row

struct BulkSongRow: View {
    let song: MPMediaItem
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "#6366f1") : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "#6366f1"))
                            .frame(width: 16, height: 16)
                    }
                }
                
                // Artwork
                if let artwork = song.artwork?.image(at: CGSize(width: 44, height: 44)) {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundColor(.gray)
                        )
                }
                
                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(isDisabled ? .gray : .white)
                        .lineLimit(1)
                    
                    Text(song.artist ?? "Unknown Artist")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Duration
                Text(formatDuration(song.playbackDuration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(hex: "#6366f1").opacity(0.15) : Color.white.opacity(0.04))
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    BulkImportView()
        .environmentObject(DataStore())
}
