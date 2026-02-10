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
                        songInfoCard
                        buttonNameCard
                        startPointCard
                        categoriesCard
                        colorSelectionCard
                        deleteCard
                    }
                    .padding(16)
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
                    .fontWeight(.semibold)
                    .foregroundColor(buttonName.isEmpty ? .gray : Color(hex: "#6366f1"))
                    .disabled(buttonName.isEmpty)
                }
            }
            .toolbarBackground(Color(hex: "#1a1a2e"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
    
    // MARK: - Song Info Card
    
    private var songInfoCard: some View {
        HStack(spacing: 16) {
            // Album artwork
            ZStack {
                if let artwork = songArtwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(14)
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#6366f1").opacity(0.3), Color(hex: "#8b5cf6").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.6))
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(songTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if !songArtist.isEmpty {
                    Text(songArtist)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: button.musicSource == .spotify ? "music.note" : "applelogo")
                        .font(.caption2)
                    Text(button.musicSource == .spotify ? "Spotify" : "Apple Music")
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
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
                
                // Progress visualization
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
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
                    Button(action: togglePreview) {
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
                FlowLayout(spacing: 10) {
                    ForEach(dataStore.filteredCategories) { category in
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
    
    // MARK: - Delete Card
    
    private var deleteCard: some View {
        Button(action: { showDeleteAlert = true }) {
            HStack {
                Spacer()
                Image(systemName: "trash")
                Text("Delete Sound")
                    .fontWeight(.semibold)
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#f43f5e"), Color(hex: "#dc2626")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
        }
    }
    
    // MARK: - Helper Methods
    
    func loadButtonData() {
        buttonName = button.name
        startTime = button.startTimeSeconds
        selectedCategories = Set(button.categoryTags)
        selectedColor = button.colorHex
        
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
                songArtwork = artwork.image(at: CGSize(width: 160, height: 160))
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
        
        dataStore.updateButton(updatedButton)
        audioPlayer.stopPreview()
        dismiss()
    }
}

#Preview {
    EditButtonView(button: SoundButton(name: "Test", songPersistentID: 0))
        .environmentObject(DataStore())
        .environmentObject(AudioPlayerService())
}
