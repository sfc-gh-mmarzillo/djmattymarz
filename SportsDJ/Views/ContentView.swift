import SwiftUI
import MediaPlayer

struct ContentView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedFilter: String = "All"
    @State private var showingAddButton = false
    @State private var showingManageView = false
    @State private var showingBulkImport = false
    @State private var editingButton: SoundButton?
    @State private var editingPlayer: Player?
    @State private var isEditMode = false
    @State private var showLineupOCR = false
    @State private var showAddPlayer = false
    
    // Filter out Lineup sounds from main grid - they show in batting order
    var filteredButtons: [SoundButton] {
        let eventFiltered = dataStore.filteredButtons
            .filter { !$0.categoryTags.contains("Lineup") }
            .sorted { $0.order < $1.order }
        if selectedFilter == "All" {
            return eventFiltered
        }
        return eventFiltered.filter { $0.categoryTags.contains(selectedFilter) }
    }
    
    // Filter categories to hide "Lineup" from filter bar
    var visibleCategories: [Category] {
        dataStore.filteredCategories.filter { $0.name != "Lineup" }
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
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
                    eventSelector
                    filterBar
                    
                    mainContentArea
                    
                    Spacer(minLength: 0)
                    nowPlayingBar
                }
            }
            .navigationTitle("SportsDJ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isEditMode.toggle() }) {
                        Text(isEditMode ? "Done" : "Edit")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddButton = true }) {
                            Label("Add Sound Button", systemImage: "plus.circle")
                        }
                        Button(action: { showingBulkImport = true }) {
                            Label("Bulk Import", systemImage: "square.stack.3d.up")
                        }
                        Divider()
                        Button(action: { showingManageView = true }) {
                            Label("Manage Teams & Categories", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAddButton) {
                AddButtonView(preselectedCategory: selectedFilter == "All" ? nil : selectedFilter)
            }
            .sheet(isPresented: $showingBulkImport) {
                BulkImportView()
            }
            .sheet(isPresented: $showingManageView) {
                ManageView()
            }
            .sheet(item: $editingButton) { button in
                EditButtonView(button: button)
            }
        }
    }
    
    // MARK: - Event Selector (Instagram Stories Style)
    
    var eventSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Event circles
                ForEach(dataStore.events) { event in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(
                                    dataStore.selectedEventID == event.id ?
                                    LinearGradient(colors: [Color(hex: event.colorHex), Color(hex: event.colorHex).opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 3
                                )
                                .frame(width: 68, height: 68)
                            
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: event.colorHex).opacity(0.3), Color(hex: event.colorHex).opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: event.iconName)
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .scaleEffect(dataStore.selectedEventID == event.id ? 1.05 : 1.0)
                        
                        Text(event.name)
                            .font(.caption2)
                            .fontWeight(dataStore.selectedEventID == event.id ? .semibold : .regular)
                            .foregroundColor(dataStore.selectedEventID == event.id ? .white : .gray)
                            .lineLimit(1)
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            dataStore.selectEvent(event)
                        }
                    }
                }
                
                // Add Event Button
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .frame(width: 68, height: 68)
                        
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    
                    Text("Add")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .onTapGesture {
                    showingManageView = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Filter Bar
    
    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ModernFilterChip(title: "All", isSelected: selectedFilter == "All", color: Color(hex: "#6366f1")) {
                    selectedFilter = "All"
                }
                
                ForEach(visibleCategories) { category in
                    ModernFilterChip(
                        title: category.name,
                        isSelected: selectedFilter == category.name,
                        color: Color(hex: category.colorHex),
                        icon: category.iconName
                    ) {
                        selectedFilter = category.name
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Main Content Area (always shows batting order)
    
    var mainContentArea: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Sound buttons section
                if dataStore.buttons.isEmpty {
                    soundsEmptyState
                } else if filteredButtons.isEmpty {
                    noMatchingSoundsState
                } else {
                    soundButtonsGrid
                }
                
                // Batting Order Section - always visible
                battingOrderSection
            }
            .padding(.top, 16)
        }
    }
    
    // MARK: - Sound Buttons Grid
    
    var soundButtonsGrid: some View {
        let buttons = filteredButtons
        let columnCount = 3
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Array(buttons.enumerated()), id: \.element.id) { index, button in
                ModernSoundButtonView(
                    button: button,
                    isPlaying: audioPlayer.currentButtonID == button.id && audioPlayer.isPlaying,
                    isLoading: audioPlayer.currentButtonID == button.id && audioPlayer.isLoading,
                    isEditMode: isEditMode,
                    isFirst: index == 0,
                    isLast: index == buttons.count - 1,
                    canMoveUp: index >= columnCount,
                    canMoveDown: index < buttons.count - columnCount,
                    onMoveLeft: { moveSoundButtonLeft(at: index) },
                    onMoveRight: { moveSoundButtonRight(at: index) },
                    onMoveUp: { moveSoundButtonUp(at: index) },
                    onMoveDown: { moveSoundButtonDown(at: index) }
                )
                .onTapGesture {
                    if isEditMode {
                        editingButton = button
                    } else {
                        if audioPlayer.currentButtonID == button.id && (audioPlayer.isPlaying || audioPlayer.isLoading) {
                            audioPlayer.stop()
                        } else {
                            audioPlayer.play(button: button)
                        }
                    }
                }
            }
            
            // Add Sound Button in grid
            AddSoundGridButton {
                showingAddButton = true
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Sounds Empty State (compact version)
    
    var soundsEmptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#6366f1").opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 35))
                    .foregroundColor(Color(hex: "#6366f1"))
            }
            
            VStack(spacing: 6) {
                Text("No Sound Buttons Yet")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Tap + to add your first sound")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Button(action: { showingAddButton = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Sound")
                }
                .font(.subheadline.weight(.semibold))
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
                .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
    
    var noMatchingSoundsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundColor(.gray)
            
            Text("No sounds in this category")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Text("Try selecting a different filter")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }


    // MARK: - Batting Order Section
    
    var battingOrderSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "list.number")
                    .font(.subheadline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#22c55e"), Color(hex: "#16a34a")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Batting Order")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Import from screenshot
                Button(action: { showLineupOCR = true }) {
                    Image(systemName: "doc.viewfinder")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#8b5cf6"))
                }
                .padding(.trailing, 8)
                
                // Add player
                Button(action: { showAddPlayer = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color(hex: "#22c55e"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#22c55e").opacity(0.1))
            
            if dataStore.filteredPlayers.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No players in lineup")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Button(action: { showLineupOCR = true }) {
                        HStack {
                            Image(systemName: "doc.viewfinder")
                            Text("Import from Screenshot")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color(hex: "#8b5cf6"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#8b5cf6").opacity(0.15))
                        .cornerRadius(20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Players list with batting order numbers
                let players = dataStore.filteredPlayers
                VStack(spacing: 8) {
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        BattingOrderRow(
                            player: player,
                            battingOrder: index + 1,
                            isPlaying: isPlayerPlaying(player),
                            isEditMode: isEditMode,
                            isFirst: index == 0,
                            isLast: index == players.count - 1,
                            onPlay: { playPlayer(player) },
                            onEdit: { editingPlayer = player },
                            onMoveUp: { movePlayerUp(at: index) },
                            onMoveDown: { movePlayerDown(at: index) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .sheet(isPresented: $showLineupOCR) {
            LineupOCRView()
        }
        .sheet(isPresented: $showAddPlayer) {
            AddPlayerView()
        }
        .sheet(item: $editingPlayer) { player in
            EditPlayerView(player: player)
        }
    }
    
    private func isPlayerPlaying(_ player: Player) -> Bool {
        guard let soundID = player.announcementSoundID else { return false }
        return audioPlayer.currentButtonID == soundID && audioPlayer.isPlaying
    }
    
    private func playPlayer(_ player: Player) {
        guard let soundID = player.announcementSoundID,
              let sound = dataStore.buttons.first(where: { $0.id == soundID }) else { return }
        
        if audioPlayer.currentButtonID == soundID && (audioPlayer.isPlaying || audioPlayer.isLoading) {
            audioPlayer.stop()
        } else {
            audioPlayer.play(button: sound)
        }
    }
    
    private func movePlayerUp(at index: Int) {
        guard index > 0 else { return }
        dataStore.movePlayer(from: IndexSet(integer: index), to: index - 1)
    }
    
    private func movePlayerDown(at index: Int) {
        let players = dataStore.filteredPlayers
        guard index < players.count - 1 else { return }
        dataStore.movePlayer(from: IndexSet(integer: index), to: index + 2)
    }
    
    private func moveSoundButtonLeft(at index: Int) {
        guard index > 0 else { return }
        dataStore.moveButton(from: IndexSet(integer: index), to: index - 1)
    }
    
    private func moveSoundButtonRight(at index: Int) {
        let buttons = filteredButtons
        guard index < buttons.count - 1 else { return }
        dataStore.moveButton(from: IndexSet(integer: index), to: index + 2)
    }
    
    private func moveSoundButtonUp(at index: Int) {
        let columnCount = 3
        guard index >= columnCount else { return }
        // Move up by column count (one full row)
        dataStore.moveButton(from: IndexSet(integer: index), to: index - columnCount)
    }
    
    private func moveSoundButtonDown(at index: Int) {
        let buttons = filteredButtons
        let columnCount = 3
        guard index < buttons.count - columnCount else { return }
        // Move down by column count (one full row)
        dataStore.moveButton(from: IndexSet(integer: index), to: index + columnCount + 1)
    }
    
    // MARK: - Now Playing Bar
    
    var nowPlayingBar: some View {
        Group {
            if audioPlayer.isPlaying || audioPlayer.isLoading || !audioPlayer.nowPlayingTitle.isEmpty {
                VStack(spacing: 0) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                            
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#6366f1"), Color(hex: "#ec4899")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: audioPlayer.duration > 0 ? geo.size.width * (audioPlayer.currentTime / audioPlayer.duration) : 0)
                        }
                    }
                    .frame(height: 3)
                    
                    HStack(spacing: 14) {
                        // Album artwork
                        ZStack {
                            if let artwork = audioPlayer.currentArtwork {
                                Image(uiImage: artwork)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 52, height: 52)
                                    .cornerRadius(10)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#6366f1").opacity(0.3), Color(hex: "#8b5cf6").opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .foregroundColor(.white.opacity(0.7))
                                    )
                            }
                            
                            if audioPlayer.isPlaying && !audioPlayer.isLoading {
                                // Animated playing indicator
                                Image(systemName: "waveform")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(audioPlayer.isLoading ? "Loading..." : "Now Playing")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(audioPlayer.nowPlayingTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if audioPlayer.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Text(formatTime(audioPlayer.currentTime))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: { audioPlayer.stop() }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#f43f5e"), Color(hex: "#ec4899")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Rectangle()
                                .fill(Color(hex: "#1a1a2e").opacity(0.8))
                        )
                )
            }
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Modern Filter Chip

struct ModernFilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .blue
    var icon: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.white.opacity(0.08)
                    }
                }
            )
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Modern Sound Button View

struct ModernSoundButtonView: View {
    let button: SoundButton
    let isPlaying: Bool
    let isLoading: Bool
    let isEditMode: Bool
    let isFirst: Bool
    let isLast: Bool
    let canMoveUp: Bool    // Can move up a row
    let canMoveDown: Bool  // Can move down a row
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    
    @State private var artwork: UIImage?
    
    var body: some View {
        ZStack {
            // Background with glassmorphism
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: button.colorHex).opacity(isPlaying ? 0.4 : 0.2),
                            Color(hex: button.colorHex).opacity(isPlaying ? 0.2 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: button.colorHex).opacity(isPlaying ? 0.8 : 0.3),
                            Color(hex: button.colorHex).opacity(isPlaying ? 0.4 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isPlaying ? 2 : 1
                )
            
            VStack(spacing: 8) {
                // Album artwork or icon
                ZStack {
                    if let artwork = artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: button.colorHex).opacity(0.3))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: isPlaying ? "waveform" : "music.note")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                            )
                    }
                    
                    if isLoading {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 48, height: 48)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
                .opacity(isLoading ? 0.7 : 1.0)
                
                Text(button.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .opacity(isLoading ? 0.6 : 1.0)
            }
            .padding(10)
            
            // Playing indicator
            if isPlaying && !isLoading {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color(hex: button.colorHex))
                            .cornerRadius(6)
                    }
                }
                .padding(6)
            }
            
            // Edit mode indicator with move buttons
            if isEditMode {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color(hex: "#6366f1"))
                                    .frame(width: 18, height: 18)
                            )
                    }
                    
                    Spacer()
                    
                    // D-pad style move buttons
                    VStack(spacing: 2) {
                        // Up button
                        Button(action: onMoveUp) {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.caption)
                                .foregroundColor(canMoveUp ? Color(hex: "#22c55e") : .gray.opacity(0.3))
                        }
                        .disabled(!canMoveUp)
                        
                        // Left and Right buttons
                        HStack(spacing: 12) {
                            Button(action: onMoveLeft) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(isFirst ? .gray.opacity(0.3) : Color(hex: "#22c55e"))
                            }
                            .disabled(isFirst)
                            
                            Button(action: onMoveRight) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(isLast ? .gray.opacity(0.3) : Color(hex: "#22c55e"))
                            }
                            .disabled(isLast)
                        }
                        
                        // Down button
                        Button(action: onMoveDown) {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.caption)
                                .foregroundColor(canMoveDown ? Color(hex: "#22c55e") : .gray.opacity(0.3))
                        }
                        .disabled(!canMoveDown)
                    }
                }
                .padding(4)
            }
        }
        .frame(height: 110)
        .scaleEffect(isPlaying ? 1.03 : 1.0)
        .shadow(color: isPlaying ? Color(hex: button.colorHex).opacity(0.4) : Color.clear, radius: 10)
        .animation(.spring(response: 0.3), value: isPlaying)
        .onAppear {
            loadArtwork()
        }
    }
    
    private func loadArtwork() {
        let predicate = MPMediaPropertyPredicate(
            value: button.songPersistentID,
            forProperty: MPMediaItemPropertyPersistentID
        )
        let query = MPMediaQuery()
        query.addFilterPredicate(predicate)
        
        if let song = query.items?.first,
           let songArtwork = song.artwork {
            artwork = songArtwork.image(at: CGSize(width: 96, height: 96))
        }
    }
}

// MARK: - Add Sound Grid Button

struct AddSoundGridButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Dashed border background
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.03))
                
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        Color.white.opacity(0.2),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "#6366f1").opacity(0.2))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(Color(hex: "#6366f1"))
                    }
                    
                    Text("Add Sound")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                }
                .padding(10)
            }
            .frame(height: 110)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Batting Order Row

struct BattingOrderRow: View {
    let player: Player
    let battingOrder: Int
    let isPlaying: Bool
    let isEditMode: Bool
    let isFirst: Bool
    let isLast: Bool
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Move up/down buttons
            VStack(spacing: 2) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundColor(isFirst ? .gray.opacity(0.3) : Color(hex: "#22c55e"))
                }
                .disabled(isFirst)
                
                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundColor(isLast ? .gray.opacity(0.3) : Color(hex: "#22c55e"))
                }
                .disabled(isLast)
            }
            .frame(width: 24)
            
            // Batting order number
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#22c55e"), Color(hex: "#16a34a")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Text("\(battingOrder)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
            }
            
            // Jersey number badge
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 36, height: 28)
                
                Text("#\(player.number)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundColor(.white)
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let position = player.position, !position.isEmpty {
                    Text(position)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Playing indicator or edit button
            if isPlaying {
                if #available(iOS 17.0, *) {
                    Image(systemName: "waveform")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#22c55e"))
                        .symbolEffect(.variableColor.iterative)
                } else {
                    Image(systemName: "waveform")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#22c55e"))
                }
            }
            
            if isEditMode {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "#6366f1"))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isPlaying ? Color(hex: "#22c55e").opacity(0.15) : Color.white.opacity(0.05))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditMode {
                onPlay()
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayerService())
        .environmentObject(DataStore())
}
