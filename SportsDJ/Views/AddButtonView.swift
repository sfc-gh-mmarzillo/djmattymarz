import SwiftUI
import MediaPlayer
import AVFoundation

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
    
    // Voice over settings
    @State private var voiceOverEnabled: Bool = false
    @State private var voiceOverText: String = ""
    @State private var voiceOverRate: Float = 0.5
    @State private var voiceOverPitch: Float = 1.0
    @State private var voiceOverVolume: Float = 1.0
    @State private var voiceOverPreDelay: Double = 0
    @State private var voiceOverPostDelay: Double = 0.5
    @State private var selectedVoiceID: String? = nil
    
    private let speechService = SpeechService.shared
    
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
                    VStack(spacing: 10) {
                        songSelectionCard
                        
                        if selectedSong != nil {
                            buttonNameCard
                            startPointCard
                            fadeOutCard
                            voiceOverCard
                            categoriesCard
                            colorSelectionCard
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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
                // Apply default settings
                let defaults = dataStore.defaultSettings
                selectedColor = defaults.colorHex
                fadeOutEnabled = defaults.fadeOutEnabled
                fadeOutDuration = defaults.fadeOutDuration
                if defaults.startFromBeginning {
                    startTime = 0
                }
                
                // Add default categories
                for category in defaults.defaultCategories {
                    selectedCategories.insert(category)
                }
                
                // Also add preselected category if provided
                if let category = preselectedCategory {
                    selectedCategories.insert(category)
                }
            }
            .onDisappear {
                audioPlayer.stopPreview()
            }
        }
    }
    
    // MARK: - Song Selection Card (Compact)
    
    private var songSelectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Select Song", systemImage: "music.note")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            Button(action: { showingSongPicker = true }) {
                HStack(spacing: 10) {
                    // Album artwork - smaller
                    ZStack {
                        if let song = selectedSong,
                           let artwork = song.artwork {
                            Image(uiImage: artwork.image(at: CGSize(width: 50, height: 50)) ?? UIImage())
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
                                    Image(systemName: "music.note")
                                        .font(.title3)
                                        .foregroundColor(.white.opacity(0.6))
                                )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedSong?.title ?? "Tap to select a song")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(selectedSong == nil ? .gray : .white)
                            .lineLimit(1)
                        
                        if let artist = selectedSong?.artist {
                            Text(artist)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        } else if selectedSong == nil {
                            Text("Choose from your music library")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }
        }
        .compactCardStyle()
    }
    
    // MARK: - Button Name Card (Compact)
    
    private var buttonNameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Button Name", systemImage: "textformat")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Enter button name", text: $buttonName)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
        }
        .compactCardStyle()
    }
    
    // MARK: - Start Point Card (Compact)
    
    private var startPointCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Start Point", systemImage: "clock")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 10) {
                // Time display - more compact
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start at")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(formatTime(startTime))
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    // Show current playback position when previewing
                    if audioPlayer.isPreviewing {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Playing")
                                .font(.caption2)
                                .foregroundColor(Color(hex: "#6366f1"))
                            Text(formatTime(audioPlayer.currentTime))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(hex: "#6366f1"))
                                .monospacedDigit()
                        }
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Duration")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(formatTime(songDuration))
                                .font(.caption)
                                .foregroundColor(.gray)
                                .monospacedDigit()
                        }
                    }
                }
                
                // Progress bar - shows current position during preview, start position otherwise
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    GeometryReader { geo in
                        let displayPosition = audioPlayer.isPreviewing ? audioPlayer.currentTime : startTime
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: audioPlayer.isPreviewing ? 
                                        [Color(hex: "#22c55e"), Color(hex: "#14b8a6")] :
                                        [Color(hex: "#6366f1"), Color(hex: "#ec4899")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * (songDuration > 0 ? displayPosition / songDuration : 0), height: 6)
                            .animation(.linear(duration: 0.1), value: displayPosition)
                    }
                    .frame(height: 6)
                }
                
                Slider(value: $startTime, in: 0...max(songDuration, 1))
                    .tint(Color(hex: "#6366f1"))
                    .onChange(of: startTime) { _ in
                        if audioPlayer.isPreviewing {
                            audioPlayer.seekPreview(to: startTime)
                        }
                    }
                
                // Control buttons - more compact
                HStack(spacing: 6) {
                    ForEach([("-5s", -5.0), ("-1s", -1.0), ("+1s", 1.0), ("+5s", 5.0)], id: \.0) { label, offset in
                        Button(action: {
                            startTime = max(0, min(songDuration, startTime + offset))
                        }) {
                            Text(label)
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(6)
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
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: audioPlayer.isPreviewing ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(
                                        audioPlayer.isPreviewing ?
                                        LinearGradient(colors: [Color(hex: "#f43f5e"), Color(hex: "#ec4899")], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                        }
                        .frame(width: 30, height: 30)
                    }
                    .disabled(audioPlayer.isLoading)
                }
            }
        }
        .compactCardStyle()
    }
    
    // MARK: - Fade Out Card (Compact)
    
    private var fadeOutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Fade Out", systemImage: "speaker.wave.3.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            // Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Fade Out")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("Gradually lower volume when stopping")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $fadeOutEnabled)
                    .labelsHidden()
                    .tint(Color(hex: "#6366f1"))
                    .scaleEffect(0.85)
            }
            .padding(10)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            
            // Duration selector (only show if enabled)
            if fadeOutEnabled {
                HStack {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach([1.0, 1.5, 2.0, 3.0, 5.0], id: \.self) { duration in
                            Button(action: { fadeOutDuration = duration }) {
                                Text("\(String(format: "%.1f", duration))s")
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(fadeOutDuration == duration ? .white : .gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        fadeOutDuration == duration ?
                                        Color(hex: "#6366f1") :
                                        Color.white.opacity(0.1)
                                    )
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .compactCardStyle()
        .animation(.spring(response: 0.3), value: fadeOutEnabled)
    }
    
    // MARK: - Voice Over Card (Compact)
    
    private var voiceOverCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Voice Announcement", systemImage: "speaker.wave.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            // Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Voice Over")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("Speak text before playing song")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $voiceOverEnabled)
                    .labelsHidden()
                    .tint(Color(hex: "#6366f1"))
                    .scaleEffect(0.85)
            }
            .padding(10)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            
            if voiceOverEnabled {
                // Text input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Announcement Text")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("e.g., Now batting, number 23...", text: $voiceOverText)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                
                // Voice settings
                VStack(spacing: 8) {
                    // Rate slider
                    HStack {
                        Text("Speed")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 50, alignment: .leading)
                        Slider(value: $voiceOverRate, in: 0...1)
                            .tint(Color(hex: "#6366f1"))
                        Text(voiceOverRate < 0.4 ? "Slow" : voiceOverRate > 0.6 ? "Fast" : "Normal")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .frame(width: 45)
                    }
                    
                    // Pitch slider
                    HStack {
                        Text("Pitch")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 50, alignment: .leading)
                        Slider(value: $voiceOverPitch, in: 0.5...2.0)
                            .tint(Color(hex: "#6366f1"))
                        Text(String(format: "%.1f", voiceOverPitch))
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .frame(width: 45)
                    }
                    
                    // Volume slider
                    HStack {
                        Text("Volume")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 50, alignment: .leading)
                        Slider(value: $voiceOverVolume, in: 0...1)
                            .tint(Color(hex: "#6366f1"))
                        Text("\(Int(voiceOverVolume * 100))%")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .frame(width: 45)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                
                // Delays
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pre-delay")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        HStack(spacing: 4) {
                            ForEach([0.0, 0.5, 1.0, 2.0], id: \.self) { delay in
                                Button(action: { voiceOverPreDelay = delay }) {
                                    Text("\(String(format: "%.1f", delay))s")
                                        .font(.caption2)
                                        .foregroundColor(voiceOverPreDelay == delay ? .white : .gray)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(
                                            voiceOverPreDelay == delay ?
                                            Color(hex: "#6366f1") :
                                            Color.white.opacity(0.1)
                                        )
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Post-delay")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        HStack(spacing: 4) {
                            ForEach([0.0, 0.5, 1.0, 2.0], id: \.self) { delay in
                                Button(action: { voiceOverPostDelay = delay }) {
                                    Text("\(String(format: "%.1f", delay))s")
                                        .font(.caption2)
                                        .foregroundColor(voiceOverPostDelay == delay ? .white : .gray)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(
                                            voiceOverPostDelay == delay ?
                                            Color(hex: "#6366f1") :
                                            Color.white.opacity(0.1)
                                        )
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                
                // Preview button
                Button(action: previewVoiceOver) {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text("Preview Voice")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#6366f1"))
                    .cornerRadius(8)
                }
                .disabled(voiceOverText.isEmpty)
                .opacity(voiceOverText.isEmpty ? 0.5 : 1)
            }
        }
        .compactCardStyle()
        .animation(.spring(response: 0.3), value: voiceOverEnabled)
    }
    
    private func previewVoiceOver() {
        let settings = VoiceOverSettings(
            enabled: true,
            text: voiceOverText,
            voiceIdentifier: selectedVoiceID,
            rate: voiceOverRate,
            pitch: voiceOverPitch,
            volume: voiceOverVolume,
            preDelay: 0,
            postDelay: 0
        )
        speechService.previewVoice(text: voiceOverText, settings: settings)
    }
    
    // MARK: - Categories Card (Compact)
    
    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Categories", systemImage: "tag")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            if dataStore.filteredCategories.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("No categories yet. Create some in Manage.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(8)
            } else {
                // Simple horizontal scroll for categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(dataStore.filteredCategories) { category in
                            CompactCategoryChip(
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
            }
        }
        .compactCardStyle()
    }
    
    // MARK: - Color Selection Card (Compact)
    
    private var colorSelectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Button Color", systemImage: "paintpalette")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                ForEach(colorOptions, id: \.self) { color in
                    Button(action: { selectedColor = color }) {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                            )
                            .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3), value: selectedColor)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .compactCardStyle()
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
        
        // Create voice over settings if enabled
        var voiceOver: VoiceOverSettings? = nil
        if voiceOverEnabled && !voiceOverText.isEmpty {
            voiceOver = VoiceOverSettings(
                enabled: true,
                text: voiceOverText,
                voiceIdentifier: selectedVoiceID,
                rate: voiceOverRate,
                pitch: voiceOverPitch,
                volume: voiceOverVolume,
                preDelay: voiceOverPreDelay,
                postDelay: voiceOverPostDelay
            )
        }
        
        let button = SoundButton(
            name: buttonName,
            songPersistentID: song.persistentID,
            musicSource: .appleMusic,
            startTimeSeconds: startTime,
            categoryTags: Array(selectedCategories),
            colorHex: selectedColor,
            eventID: dataStore.selectedEventID,
            fadeOutEnabled: fadeOutEnabled,
            fadeOutDuration: fadeOutDuration,
            voiceOver: voiceOver,
            isVoiceOnly: false
        )
        
        dataStore.addButton(button)
        dismiss()
    }
}

// MARK: - Compact Category Chip

struct CompactCategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption2)
                Text(category.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected ?
                Color(hex: category.colorHex) :
                Color.white.opacity(0.08)
            )
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.clear : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Compact Card Style Modifier

extension View {
    func compactCardStyle() -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
    
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

// MARK: - Wrapping HStack (iOS 15 compatible) - kept for other views

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
        let estimatedRows = max(1, (items.count + 2) / 3)
        return CGFloat(estimatedRows) * 50
    }
}

// MARK: - CategoryChip (kept for other views)

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

#Preview {
    AddButtonView()
        .environmentObject(DataStore())
        .environmentObject(AudioPlayerService())
}
