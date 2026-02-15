import SwiftUI
import MediaPlayer

struct LineupView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var audioPlayer: AudioPlayerService
    
    @State private var showAddPlayer = false
    @State private var showOCRImport = false
    @State private var editingPlayer: Player? = nil
    @State private var showDeleteAlert = false
    @State private var playerToDelete: Player? = nil
    @State private var isReordering = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            if dataStore.filteredPlayers.isEmpty {
                emptyStateView
            } else {
                lineupList
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lineup")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                
                if !dataStore.filteredPlayers.isEmpty {
                    Text("\(dataStore.filteredPlayers.count) player\(dataStore.filteredPlayers.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Reorder toggle button
            if dataStore.filteredPlayers.count > 1 {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isReordering.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                            .font(.caption)
                        Text(isReordering ? "Done" : "Reorder")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(isReordering ? Color(hex: "#22c55e") : Color(hex: "#6366f1"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isReordering ? Color(hex: "#22c55e").opacity(0.2) : Color(hex: "#6366f1").opacity(0.2))
                    )
                }
                .padding(.trailing, 8)
            }
            
            // Import from screenshot button (hide when reordering)
            if !isReordering {
                Button(action: { showOCRImport = true }) {
                    Image(systemName: "doc.viewfinder")
                        .font(.title3)
                        .foregroundColor(Color(hex: "#8b5cf6"))
                }
                .padding(.trailing, 8)
                
                // Add player button
                Button(action: { showAddPlayer = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#1a1a2e").opacity(0.8))
        .sheet(isPresented: $showAddPlayer) {
            AddPlayerView()
                .environmentObject(dataStore)
        }
        .sheet(isPresented: $showOCRImport) {
            LineupOCRView()
                .environmentObject(dataStore)
        }
        .sheet(item: $editingPlayer) { player in
            EditPlayerView(player: player)
                .environmentObject(dataStore)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#6366f1").opacity(0.5), Color(hex: "#8b5cf6").opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No Players Yet")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
            
            Text("Add players to your lineup manually\nor import from a screenshot")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button(action: { showAddPlayer = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Player")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
                
                Button(action: { showOCRImport = true }) {
                    HStack {
                        Image(systemName: "doc.viewfinder")
                        Text("Import")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color(hex: "#8b5cf6"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#8b5cf6").opacity(0.15))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#8b5cf6").opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Lineup List
    
    private var lineupList: some View {
        let sortedPlayers = dataStore.filteredPlayers.sorted(by: { $0.lineupOrder < $1.lineupOrder })
        
        return ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                    PlayerCard(
                        player: player,
                        isReordering: isReordering,
                        index: index,
                        totalCount: sortedPlayers.count,
                        onPlay: { playAnnouncement(for: player) },
                        onEdit: { editingPlayer = player },
                        onDelete: {
                            playerToDelete = player
                            showDeleteAlert = true
                        },
                        onMoveUp: { movePlayer(at: index, direction: -1) },
                        onMoveDown: { movePlayer(at: index, direction: 1) }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .alert("Delete Player?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let player = playerToDelete {
                    dataStore.deletePlayer(player)
                }
            }
        } message: {
            if let player = playerToDelete {
                Text("Remove \(player.name) from the lineup? This will also delete their announcement sound.")
            }
        }
    }
    
    private func movePlayer(at index: Int, direction: Int) {
        let sortedPlayers = dataStore.filteredPlayers.sorted(by: { $0.lineupOrder < $1.lineupOrder })
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < sortedPlayers.count else { return }
        
        let source = IndexSet(integer: index)
        let destination = direction > 0 ? newIndex + 1 : newIndex
        
        withAnimation(.spring(response: 0.3)) {
            dataStore.movePlayer(from: source, to: destination)
        }
    }
    
    // MARK: - Actions
    
    private func playAnnouncement(for player: Player) {
        // Find the announcement sound for this player
        if let soundID = player.announcementSoundID,
           let sound = dataStore.buttons.first(where: { $0.id == soundID }) {
            audioPlayer.play(button: sound)
        }
    }
}

// MARK: - Player Card

struct PlayerCard: View {
    let player: Player
    var isReordering: Bool = false
    var index: Int = 0
    var totalCount: Int = 1
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Player number badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Text("\(player.number)")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                
                if let position = player.position, !position.isEmpty {
                    Text(position)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if isReordering {
                // Reorder buttons
                VStack(spacing: 6) {
                    Button(action: { onMoveUp?() }) {
                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.bold))
                            .foregroundColor(index > 0 ? .white : .gray.opacity(0.3))
                            .frame(width: 32, height: 24)
                            .background(index > 0 ? Color(hex: "#6366f1") : Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .disabled(index == 0)
                    
                    Button(action: { onMoveDown?() }) {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundColor(index < totalCount - 1 ? .white : .gray.opacity(0.3))
                            .frame(width: 32, height: 24)
                            .background(index < totalCount - 1 ? Color(hex: "#6366f1") : Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .disabled(index == totalCount - 1)
                }
            } else {
                // Play announcement button
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#22c55e"), Color(hex: "#14b8a6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color(hex: "#6366f1"))
                }
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color(hex: "#f43f5e"))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Edit Player View

struct EditPlayerView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @Environment(\.dismiss) var dismiss
    
    let player: Player
    
    @State private var name: String = ""
    @State private var number: String = ""
    @State private var position: String = ""
    
    // Walk-up song
    @State private var selectedSong: MPMediaItem?
    @State private var showingSongPicker = false
    @State private var songDuration: Double = 0
    @State private var startTime: Double = 0
    @State private var hasSong: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
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
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Player Name", systemImage: "person.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            
                            TextField("Enter name", text: $name)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        
                        // Number field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Jersey Number", systemImage: "number")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            
                            TextField("Enter number", text: $number)
                                .font(.body)
                                .foregroundColor(.white)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        
                        // Position field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Position (Optional)", systemImage: "sportscourt")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            
                            TextField("e.g., Pitcher, Catcher, 1B", text: $position)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        
                        // Walk-up Song section
                        walkUpSongCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePlayer() }
                        .font(.body.weight(.semibold))
                        .foregroundColor(canSave ? Color(hex: "#6366f1") : .gray)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingSongPicker) {
                SongPickerView(selectedSong: $selectedSong, songDuration: $songDuration)
            }
            .onChange(of: selectedSong) { newSong in
                if let song = newSong {
                    songDuration = song.playbackDuration
                    hasSong = true
                }
            }
            .onAppear {
                loadPlayerData()
            }
        }
    }
    
    // MARK: - Walk-up Song Card
    
    private var walkUpSongCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Walk-up Song (Optional)", systemImage: "music.note")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            if let song = selectedSong {
                // Show selected song
                HStack(spacing: 12) {
                    // Album artwork
                    if let artwork = song.artwork?.image(at: CGSize(width: 50, height: 50)) {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#6366f1").opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(Color(hex: "#6366f1"))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title ?? "Unknown")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(song.artist ?? "Unknown Artist")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Remove song button
                    Button(action: {
                        selectedSong = nil
                        hasSong = false
                        startTime = 0
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                
                // Start time slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Start at")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(formatTime(startTime))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Color(hex: "#6366f1"))
                    }
                    
                    Slider(value: $startTime, in: 0...max(songDuration - 10, 0))
                        .accentColor(Color(hex: "#6366f1"))
                }
                .padding(.top, 8)
                
            } else {
                // No song selected - show add button
                Button(action: { showingSongPicker = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Add Walk-up Song")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(Color(hex: "#6366f1"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "#6366f1").opacity(0.1))
                    .cornerRadius(10)
                }
            }
            
            Text("Song plays after the announcement")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Helpers
    
    private var canSave: Bool {
        !name.isEmpty && !number.isEmpty && Int(number) != nil
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func loadPlayerData() {
        name = player.name
        number = String(player.number)
        position = player.position ?? ""
        
        // Load existing song if player has one
        if let soundID = player.announcementSoundID,
           let sound = dataStore.buttons.first(where: { $0.id == soundID }) {
            
            if sound.songPersistentID != 0 {
                // Has a song - try to load it
                let query = MPMediaQuery.songs()
                query.addFilterPredicate(MPMediaPropertyPredicate(
                    value: sound.songPersistentID,
                    forProperty: MPMediaItemPropertyPersistentID
                ))
                if let song = query.items?.first {
                    selectedSong = song
                    songDuration = song.playbackDuration
                    startTime = sound.startTimeSeconds
                    hasSong = true
                }
            }
        }
    }
    
    private func savePlayer() {
        guard let playerNumber = Int(number) else { return }
        
        var updatedPlayer = player
        updatedPlayer.name = name
        updatedPlayer.number = playerNumber
        updatedPlayer.position = position.isEmpty ? nil : position
        
        // CRITICAL: Update the Player model with song info so it persists
        // This is needed for updatePlayerSound to work correctly when voice changes
        if let song = selectedSong {
            updatedPlayer.songPersistentID = song.persistentID
            updatedPlayer.musicSource = .appleMusic
            updatedPlayer.songStartTimeSeconds = startTime
        } else {
            updatedPlayer.songPersistentID = nil
            updatedPlayer.musicSource = nil
            updatedPlayer.songStartTimeSeconds = 0
        }
        
        // Save the player FIRST (so updatePlayerSound has correct data)
        dataStore.updatePlayer(updatedPlayer)
        
        // Now update the sound button through the proper method
        // This ensures voice settings and isLineupAnnouncement are set correctly
        dataStore.updatePlayerSound(updatedPlayer)
        
        dismiss()
    }
}

#Preview {
    LineupView()
        .environmentObject(DataStore())
        .environmentObject(AudioPlayerService())
        .background(Color(hex: "#0f0f23"))
}
