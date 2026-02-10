import SwiftUI
import MediaPlayer

struct EditButtonView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @Environment(\.dismiss) var dismiss
    
    let button: SoundButton
    
    @State private var buttonName: String = ""
    @State private var startTime: Double = 0
    @State private var selectedCategories: Set<String> = []
    @State private var selectedColor: String = "#6366f1"
    @State private var songDuration: Double = 0
    @State private var songTitle: String = ""
    @State private var songArtist: String = ""
    @State private var songArtwork: UIImage?
    @State private var showDeleteAlert = false
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
                    VStack(spacing: 10) {
                        songInfoCard
                        buttonNameCard
                        startPointCard
                        fadeOutCard
                        categoriesCard
                        colorSelectionCard
                        deleteCard
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        audioPlayer.stopPreview()
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(buttonName.isEmpty ? .gray : Color(hex: "#6366f1"))
                    .disabled(buttonName.isEmpty)
                }
            }
            .alert("Delete Sound?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    dataStore.deleteButton(button)
                    dismiss()
                }
            } message: {
                Text("This cannot be undone.")
            }
            .onAppear {
                loadButtonData()
            }
            .onDisappear {
                audioPlayer.stopPreview()
            }
        }
    }
    
    // MARK: - Song Info Card (Compact)
    
    private var songInfoCard: some View {
        HStack(spacing: 10) {
            // Album artwork - smaller
            ZStack {
                if let artwork = songArtwork {
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
                            Image(systemName: "music.note")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.6))
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(songTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if !songArtist.isEmpty {
                    Text(songArtist)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: button.musicSource == .spotify ? "music.note" : "applelogo")
                        .font(.caption2)
                    Text(button.musicSource == .spotify ? "Spotify" : "Apple Music")
                        .font(.caption2)
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
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
                // Time display - compact
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
                
                // Progress visualization
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#6366f1"), Color(hex: "#ec4899")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * (songDuration > 0 ? startTime / songDuration : 0), height: 6)
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
                
                // Control buttons - compact
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
                    Button(action: togglePreview) {
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
                            EditCompactCategoryChip(
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
    
    // MARK: - Delete Card (Compact)
    
    private var deleteCard: some View {
        Button(action: { showDeleteAlert = true }) {
            HStack {
                Spacer()
                Image(systemName: "trash")
                    .font(.subheadline)
                Text("Delete Sound")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#f43f5e"), Color(hex: "#dc2626")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(10)
        }
    }
    
    // MARK: - Helper Methods
    
    func loadButtonData() {
        buttonName = button.name
        startTime = button.startTimeSeconds
        selectedCategories = Set(button.categoryTags)
        selectedColor = button.colorHex
        fadeOutEnabled = button.fadeOutEnabled
        fadeOutDuration = button.fadeOutDuration
        
        if let duration = audioPlayer.getSongDuration(persistentID: button.songPersistentID) {
            songDuration = duration
        }
        
        let predicate = MPMediaPropertyPredicate(
            value: button.songPersistentID,
            forProperty: MPMediaItemPropertyPersistentID
        )
        let query = MPMediaQuery()
        query.addFilterPredicate(predicate)
        
        if let song = query.items?.first {
            songTitle = song.title ?? "Unknown"
            songArtist = song.artist ?? ""
            if let artwork = song.artwork {
                songArtwork = artwork.image(at: CGSize(width: 100, height: 100))
            }
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    func togglePreview() {
        if audioPlayer.isPreviewing || audioPlayer.isLoading {
            audioPlayer.stopPreview()
        } else {
            let predicate = MPMediaPropertyPredicate(
                value: button.songPersistentID,
                forProperty: MPMediaItemPropertyPersistentID
            )
            let query = MPMediaQuery()
            query.addFilterPredicate(predicate)
            if let song = query.items?.first {
                audioPlayer.playPreview(song: song, startTime: startTime)
            }
        }
    }
    
    func saveChanges() {
        var updatedButton = button
        updatedButton.name = buttonName
        updatedButton.startTimeSeconds = startTime
        updatedButton.categoryTags = Array(selectedCategories)
        updatedButton.colorHex = selectedColor
        updatedButton.fadeOutEnabled = fadeOutEnabled
        updatedButton.fadeOutDuration = fadeOutDuration
        
        dataStore.updateButton(updatedButton)
        audioPlayer.stopPreview()
        dismiss()
    }
}

// MARK: - Compact Category Chip (Edit View)

struct EditCompactCategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption2)
                Text(category.name)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected ?
                Color(hex: "#6366f1") :
                Color.white.opacity(0.1)
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

#Preview {
    EditButtonView(button: SoundButton(name: "Test", songPersistentID: 0))
        .environmentObject(DataStore())
        .environmentObject(AudioPlayerService())
}
