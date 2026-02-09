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
    @State private var selectedColor: String = "#007AFF"
    @State private var songDuration: Double = 0
    @State private var songTitle: String = ""
    @State private var showDeleteAlert = false
    
    let colorOptions = [
        "#007AFF", "#34C759", "#FF3B30", "#FF9500",
        "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Button Info") {
                    TextField("Button Name", text: $buttonName)
                    
                    HStack {
                        Text("Song")
                        Spacer()
                        Text(songTitle)
                            .foregroundColor(.secondary)
                    }
                }
                
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
                            Button("-5s") { startTime = max(0, startTime - 5) }
                                .buttonStyle(.bordered)
                            Button("-1s") { startTime = max(0, startTime - 1) }
                                .buttonStyle(.bordered)
                            Spacer()
                            
                            Button(action: togglePreview) {
                                Image(systemName: audioPlayer.isPreviewing ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                    .foregroundColor(audioPlayer.isPreviewing ? .red : .blue)
                            }
                            
                            Spacer()
                            Button("+1s") { startTime = min(songDuration, startTime + 1) }
                                .buttonStyle(.bordered)
                            Button("+5s") { startTime = min(songDuration, startTime + 5) }
                                .buttonStyle(.bordered)
                        }
                        .font(.caption)
                    }
                }
                
                Section("Categories") {
                    ForEach(dataStore.categories) { category in
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
                }
                
                Section("Button Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { color in
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
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        HStack {
                            Spacer()
                            Text("Delete Button")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Button")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        audioPlayer.stopPreview()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(buttonName.isEmpty)
                }
            }
            .alert("Delete Button?", isPresented: $showDeleteAlert) {
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
        songTitle = query.items?.first?.title ?? "Unknown"
    }
    
    func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    func togglePreview() {
        if audioPlayer.isPreviewing {
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
