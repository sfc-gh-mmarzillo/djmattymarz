import SwiftUI
import MediaPlayer

struct AddButtonView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @Environment(\.dismiss) var dismiss
    
    var preselectedCategory: String?
    
    @State private var buttonName: String = ""
    @State private var selectedSong: MPMediaItem?
    @State private var startTime: Double = 0
    @State private var selectedCategories: Set<String> = []
    @State private var selectedColor: String = "#6366f1"
    @State private var showingSongPicker = false
    @State private var songDuration: Double = 0
    @State private var fadeOutEnabled: Bool = false
    @State private var fadeOutDuration: Double = 2.0
    
    let colorOptions = [
        "#6366f1", "#8b5cf6", "#ec4899", "#f43f5e",
        "#f97316", "#eab308", "#22c55e", "#14b8a6",
        "#06b6d4", "#3b82f6"
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
                
                ScrollView {
                    VStack(spacing: 20) {
                        songSelectionCard
                        
                        if selectedSong != nil {
                            buttonNameCard
                            startPointCard
                            fadeOutCard
                            categoriesCard
                            colorSelectionCard
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: toolbarContent)
            .sheet(isPresented: $showingSongPicker) {
                SongPickerView(selectedSong: $selectedSong, songDuration: $songDuration)
            }
            .onChange(of: selectedSong) { newSong in
                if let song = newSong {
                    songDuration = song.playbackDuration
                    let title = song.title ?? "Unknown"
                    let artist = song.artist ?? ""
                    buttonName = artist.isEmpty ? title : "\(title) - \(artist)"
                }
            }
            .onAppear {
                if let category = preselectedCategory {
                    selectedCategories.insert(category)
                }
            }
            .onDisappear {
                audioPlayer.stopPreview()
            }
        }
    }
    
    // MARK: - Song Selection Card
    
    private var songSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Select Song", systemImage: "music.note")
                .font(.headline)
                .foregroundColor(.white)
            
            Button(action: { showingSongPicker = true }) {
                HStack(spacing: 14) {
                    // Album artwork
                    ZStack {
                        if let song = selectedSong,
                           let artwork = song.artwork {
                            Image(uiImage: artwork.image(at: CGSize(width: 70, height: 70)) ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 70, height: 70)
                                .cornerRadius(12)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#6366f1").opacity(0.3), Color(hex: "#8b5cf6").opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.title)
                                        .foregroundColor(.white.opacity(0.6))
                                )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedSong?.title ?? "Tap to select a song")
                            .font(.headline)
                            .foregroundColor(selectedSong == nil ? .gray : .white)
                            .lineLimit(1)
                        
                        if let artist = selectedSong?.artist {
                            Text(artist)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        } else if selectedSong == nil {
                            Text("Choose from your music library")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .cardStyle()
    }
    
    // MARK: - Button Name Card
    
    private var buttonNameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Button Name", systemImage: "textformat")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "pencil")
                    .foregroundColor(.gray)
                TextField("Enter button name", text: $buttonName)
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
        }
        .cardStyle()
    }
    
    // MARK: - Start Point Card
    
    private var startPointCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Start Point", systemImage: "clock")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                // Time display
                HStack {
                    VStack(alignment: .leading) {
                        Text("Start at")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(formatTime(startTime))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(formatTime(songDuration))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .monospacedDigit()
                    }
                }
                
                // Slider with gradient track
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    // Progress track
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#6366f1"), Color(hex: "#ec4899")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * (songDuration > 0 ? startTime / songDuration : 0), height: 8)
                    }
                    .frame(height: 8)
                }
                
                Slider(value: $startTime, in: 0...max(songDuration, 1))
                    .tint(Color(hex: "#6366f1"))
                    .onChange(of: startTime) { _ in
                        if audioPlayer.isPreviewing {
                            audioPlayer.seekPreview(to: startTime)
                        }
                    }
                
                // Control buttons
                HStack(spacing: 10) {
                    ForEach([("-5s", -5.0), ("-1s", -1.0), ("+1s", 1.0), ("+5s", 5.0)], id: \.0) { label, offset in
                        Button(action: {
                            startTime = max(0, min(songDuration, startTime + offset))
                        }) {
                            Text(label)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                    
                    // Preview button
                    Button(action: {
                        if let song = selectedSong {
                            if audioPlayer.isPreviewing || audioPlayer.isLoading {
                                audioPlayer.stopPreview()
                            } else {
                                audioPlayer.playPreview(song: song, startTime: startTime)
                            }
                        }
                    }) {
                        ZStack {
                            if audioPlayer.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: audioPlayer.isPreviewing ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(
                                        audioPlayer.isPreviewing ?
                                        LinearGradient(colors: [Color(hex: "#f43f5e"), Color(hex: "#ec4899")], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                        }
                        .frame(width: 36, height: 36)
                    }
                    .disabled(audioPlayer.isLoading)
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Fade Out Card
    
    private var fadeOutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Fade Out", systemImage: "speaker.wave.3.fill")
                .font(.headline)
                .foregroundColor(.white)
            
            // Toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Fade Out")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("Gradually lower volume when stopping")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $fadeOutEnabled)
                    .labelsHidden()
                    .tint(Color(hex: "#6366f1"))
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            
            // Duration selector (only show if enabled)
            if fadeOutEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Duration")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(String(format: "%.1f", fadeOutDuration))s")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "#6366f1"))
                    }
                    
                    HStack(spacing: 12) {
                        ForEach([1.0, 1.5, 2.0, 3.0, 5.0], id: \.self) { duration in
                            Button(action: { fadeOutDuration = duration }) {
                                Text("\(String(format: "%.1f", duration))s")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(fadeOutDuration == duration ? .white : .gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        fadeOutDuration == duration ?
                                        Color(hex: "#6366f1") :
                                        Color.white.opacity(0.1)
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardStyle()
        .animation(.spring(response: 0.3), value: fadeOutEnabled)
    }
    
    // MARK: - Categories Card
    
    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Categories", systemImage: "tag")
                .font(.headline)
                .foregroundColor(.white)
            
            if dataStore.filteredCategories.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.gray)
                    Text("No categories available. Create some in Manage.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                // iOS 15 compatible wrapping layout
                WrappingHStack(items: dataStore.filteredCategories, spacing: 10) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategories.contains(category.name)
                    ) {
                        if selectedCategories.contains(category.name) {
                            selectedCategories.remove(category.name)
                        } else {
                            selectedCategories.insert(category.name)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Color Selection Card
    
    private var colorSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Button Color", systemImage: "paintpalette")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                ForEach(colorOptions, id: \.self) { color in
                    Button(action: { selectedColor = color }) {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                            )
                            .scaleEffect(selectedColor == color ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3), value: selectedColor)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .cardStyle()
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .foregroundColor(.gray)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(action: saveButton) {
                Text("Add")
                    .fontWeight(.semibold)
                    .foregroundColor(buttonName.isEmpty || selectedSong == nil ? .gray : Color(hex: "#6366f1"))
            }
            .disabled(buttonName.isEmpty || selectedSong == nil)
        }
    }
    
    // MARK: - Helper Methods
    
    func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    func saveButton() {
        guard let song = selectedSong else { return }
        
        let button = SoundButton(
            name: buttonName,
            songPersistentID: song.persistentID,
            musicSource: .appleMusic,
            startTimeSeconds: startTime,
            categoryTags: Array(selectedCategories),
            colorHex: selectedColor,
            eventID: dataStore.selectedEventID,
            fadeOutEnabled: fadeOutEnabled,
            fadeOutDuration: fadeOutDuration
        )
        
        dataStore.addButton(button)
        dismiss()
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.caption)
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected ?
                Color(hex: category.colorHex) :
                Color.white.opacity(0.08)
            )
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Wrapping HStack (iOS 15 compatible)

struct WrappingHStack<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let content: (Item) -> Content
    
    init(items: [Item], spacing: CGFloat = 8, @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: calculateHeight())
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        
        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                content(item)
                    .padding(.trailing, spacing)
                    .padding(.bottom, spacing)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height + spacing
                        }
                        let result = width
                        if item.id == items.last?.id as? Item.ID {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item.id == items.last?.id as? Item.ID {
                            height = 0
                        }
                        return result
                    }
            }
        }
    }
    
    private func calculateHeight() -> CGFloat {
        // Estimate height based on item count - will adjust dynamically
        let estimatedRows = max(1, (items.count + 2) / 3)
        return CGFloat(estimatedRows) * 50
    }
}

// MARK: - Card Style Modifier

extension View {
    func cardStyle() -> some View {
        self
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

#Preview {
    AddButtonView()
        .environmentObject(DataStore())
        .environmentObject(AudioPlayerService())
}
