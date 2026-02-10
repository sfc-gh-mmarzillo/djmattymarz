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
    @State private var isEditMode = false
    @State private var isReorderMode = false
    @State private var showLineup = false
    
    var filteredButtons: [SoundButton] {
        let eventFiltered = dataStore.filteredButtons.sorted { $0.order < $1.order }
        if selectedFilter == "All" {
            return eventFiltered
        }
        return eventFiltered.filter { $0.categoryTags.contains(selectedFilter) }
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
                    
                    if dataStore.buttons.isEmpty {
                        emptyState
                    } else if filteredButtons.isEmpty {
                        noMatchingButtonsState
                    } else {
                        buttonGrid
                    }
                    
                    Spacer(minLength: 0)
                    nowPlayingBar
                }
            }
            .navigationTitle("SportsDJ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button(action: { isEditMode.toggle() }) {
                            Text(isEditMode ? "Done" : "Edit")
                                .foregroundColor(.white)
                        }
                        
                        if filteredButtons.count > 1 {
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    isReorderMode.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isReorderMode ? "checkmark" : "arrow.up.arrow.down")
                                        .font(.caption)
                                    Text(isReorderMode ? "Done" : "Reorder")
                                        .font(.subheadline)
                                }
                                .foregroundColor(isReorderMode ? Color(hex: "#22c55e") : Color(hex: "#6366f1"))
                            }
                        }
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
                
                ForEach(dataStore.filteredCategories) { category in
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
    
    // MARK: - Empty States
    
    var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // DJ Kids branding (subtle)
            if let _ = UIImage(named: "djkids") {
                Image("djkids")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .opacity(0.6)
            }
            
            ZStack {
                Circle()
                    .fill(Color(hex: "#6366f1").opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "#6366f1"))
            }
            
            VStack(spacing: 8) {
                Text("No Sound Buttons Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Tap + to add your first sound button")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Button(action: { showingAddButton = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Sound")
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
            
            // Subtle branding at bottom
            djKidsBranding
        }
    }
    
    // MARK: - DJ Kids Branding
    
    var djKidsBranding: some View {
        Group {
            if let _ = UIImage(named: "djkids") {
                HStack(spacing: 6) {
                    Image("djkids")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    Text("Powered by DJ Kids")
                        .font(.caption2)
                }
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom, 8)
            }
        }
    }
    
    var noMatchingButtonsState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No sounds in this category")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Try selecting a different filter")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    // MARK: - Button Grid
    
    var buttonGrid: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isReorderMode {
                    // Reorder list view
                    reorderListView
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filteredButtons) { button in
                            ModernSoundButtonView(
                                button: button,
                                isPlaying: audioPlayer.currentButtonID == button.id && audioPlayer.isPlaying,
                                isLoading: audioPlayer.currentButtonID == button.id && audioPlayer.isLoading,
                                isEditMode: isEditMode
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
                            .onLongPressGesture {
                                editingButton = button
                            }
                        }
                        
                        // Add Sound Button in grid
                        AddSoundGridButton {
                            showingAddButton = true
                        }
                    }
                    .padding(16)
                    
                    // Lineup Section
                    lineupSection
                }
            }
        }
    }
    
    // MARK: - Reorder List View
    
    var reorderListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(filteredButtons.enumerated()), id: \.element.id) { index, button in
                HStack(spacing: 12) {
                    // Button info
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: button.colorHex))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: button.iconName)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(button.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            if !button.categoryTags.isEmpty {
                                Text(button.categoryTags.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Reorder buttons
                    VStack(spacing: 6) {
                        Button(action: { moveButton(at: index, direction: -1) }) {
                            Image(systemName: "chevron.up")
                                .font(.caption.weight(.bold))
                                .foregroundColor(index > 0 ? .white : .gray.opacity(0.3))
                                .frame(width: 32, height: 24)
                                .background(index > 0 ? Color(hex: "#6366f1") : Color.white.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .disabled(index == 0)
                        
                        Button(action: { moveButton(at: index, direction: 1) }) {
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundColor(index < filteredButtons.count - 1 ? .white : .gray.opacity(0.3))
                                .frame(width: 32, height: 24)
                                .background(index < filteredButtons.count - 1 ? Color(hex: "#6366f1") : Color.white.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .disabled(index == filteredButtons.count - 1)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                )
            }
        }
        .padding(16)
    }
    
    private func moveButton(at index: Int, direction: Int) {
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < filteredButtons.count else { return }
        
        // Get the actual buttons from the full list
        let sourceButton = filteredButtons[index]
        let destButton = filteredButtons[newIndex]
        
        // Find their indices in the main buttons array
        guard let sourceIdx = dataStore.buttons.firstIndex(where: { $0.id == sourceButton.id }),
              let destIdx = dataStore.buttons.firstIndex(where: { $0.id == destButton.id }) else { return }
        
        // Swap the order values
        withAnimation(.spring(response: 0.3)) {
            var btn1 = dataStore.buttons[sourceIdx]
            var btn2 = dataStore.buttons[destIdx]
            let tempOrder = btn1.order
            btn1.order = btn2.order
            btn2.order = tempOrder
            dataStore.updateButton(btn1)
            dataStore.updateButton(btn2)
        }
    }
    
    // MARK: - Lineup Section
    
    var lineupSection: some View {
        VStack(spacing: 0) {
            // Lineup toggle header
            Button(action: { withAnimation(.spring(response: 0.3)) { showLineup.toggle() } }) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.subheadline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Lineup")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    
                    if !dataStore.filteredPlayers.isEmpty {
                        Text("(\(dataStore.filteredPlayers.count))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: showLineup ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
            }
            
            if showLineup {
                LineupView()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3), value: showLineup)
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
            
            // Edit mode indicator
            if isEditMode {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color(hex: "#6366f1"))
                                    .frame(width: 24, height: 24)
                            )
                    }
                    Spacer()
                }
                .padding(6)
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
