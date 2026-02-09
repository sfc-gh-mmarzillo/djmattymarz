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
    @State private var selectedColor: String = "#007AFF"
    @State private var showingSongPicker = false
    @State private var songDuration: Double = 0
    
    let colorOptions = [
        "#007AFF", "#34C759", "#FF3B30", "#FF9500",
        "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                songSelectionSection
                buttonInfoSection
                startPointSection
                categoriesSection
                colorSection
            }
            .navigationTitle("Add Sound Button")
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
                // Pre-select category if one was passed
                if let category = preselectedCategory {
                    selectedCategories.insert(category)
                }
            }
            .onDisappear {
                audioPlayer.stopPreview()
            }
        }
    }
    
    private var songSelectionSection: some View {
        Section("Select Song") {
            Button(action: { showingSongPicker = true }) {
                HStack(spacing: 12) {
                    // Album artwork
                    if let song = selectedSong,
                       let artwork = song.artwork {
                        Image(uiImage: artwork.image(at: CGSize(width: 60, height: 60)) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedSong?.title ?? "Tap to select a song")
                            .font(.headline)
                            .foregroundColor(selectedSong == nil ? .secondary : .primary)
                            .lineLimit(1)
                        
                        if let artist = selectedSong?.artist {
                            Text(artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private var buttonInfoSection: some View {
        if selectedSong != nil {
            Section("Button Name") {
                TextField("Button Name", text: $buttonName)
            }
        }
    }
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
                saveButton()
            }
            .disabled(buttonName.isEmpty || selectedSong == nil)
        }
    }
    
    @ViewBuilder
    private var startPointSection: some View {
        if let song = selectedSong {
            Section("Start Point") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Start at: \(formatTime(startTime))")
                        Spacer()
                        Text("Duration: \(formatTime(songDuration))")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    
                    Slider(value: $startTime, in: 0...max(songDuration, 1))
                        .onChange(of: startTime) { _ in
                            if audioPlayer.isPreviewing {
                                audioPlayer.seekPreview(to: startTime)
                            }
                        }
                    
                    HStack {
                        startPointButtons
                        
                        Spacer()
                        
                        Button(action: {
                            if audioPlayer.isPreviewing || audioPlayer.isLoading {
                                audioPlayer.stopPreview()
                            } else {
                                audioPlayer.playPreview(song: song, startTime: startTime)
                            }
                        }) {
                            if audioPlayer.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 28, height: 28)
                            } else {
                                Image(systemName: audioPlayer.isPreviewing ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                    .foregroundColor(audioPlayer.isPreviewing ? .red : .blue)
                            }
                        }
                        .disabled(audioPlayer.isLoading)
                    }
                }
            }
        }
    }
    
    private var startPointButtons: some View {
        HStack {
            Button("-5s") { startTime = max(0, startTime - 5) }
                .buttonStyle(.bordered)
            Button("-1s") { startTime = max(0, startTime - 1) }
                .buttonStyle(.bordered)
            Spacer()
            Button("+1s") { startTime = min(songDuration, startTime + 1) }
                .buttonStyle(.bordered)
            Button("+5s") { startTime = min(songDuration, startTime + 5) }
                .buttonStyle(.bordered)
        }
        .font(.caption)
    }
    
    @ViewBuilder
    private var categoriesSection: some View {
        if selectedSong != nil {
            Section("Categories") {
                ForEach(dataStore.categories) { category in
                    categoryRow(category)
                }
            }
        }
    }
    
    private func categoryRow(_ category: Category) -> some View {
        Button(action: {
            if selectedCategories.contains(category.name) {
                selectedCategories.remove(category.name)
            } else {
                selectedCategories.insert(category.name)
            }
        }) {
            HStack {
                Circle()
                    .fill(Color(hex: category.colorHex))
                    .frame(width: 12, height: 12)
                Text(category.name)
                    .foregroundColor(.primary)
                Spacer()
                if selectedCategories.contains(category.name) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    @ViewBuilder
    private var colorSection: some View {
        if selectedSong != nil {
            Section("Button Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(colorOptions, id: \.self) { color in
                        colorCircle(color)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func colorCircle(_ color: String) -> some View {
        Circle()
            .fill(Color(hex: color))
            .frame(width: 44, height: 44)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
            )
            .onTapGesture {
                selectedColor = color
            }
    }
    
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
            startTimeSeconds: startTime,
            categoryTags: Array(selectedCategories),
            colorHex: selectedColor
        )
        
        dataStore.addButton(button)
        dismiss()
    }
}
