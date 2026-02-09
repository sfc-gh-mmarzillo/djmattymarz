import SwiftUI
import MediaPlayer

struct AddButtonView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @Environment(\.dismiss) var dismiss
    
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
                Section("Button Info") {
                    TextField("Button Name", text: $buttonName)
                    
                    Button(action: { showingSongPicker = true }) {
                        HStack {
                            Text("Song")
                            Spacer()
                            if let song = selectedSong {
                                Text(song.title ?? "Unknown")
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("Select...")
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                if selectedSong != nil {
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
            }
            .navigationTitle("Add Sound Button")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .sheet(isPresented: $showingSongPicker) {
                SongPickerView(selectedSong: $selectedSong, songDuration: $songDuration)
            }
            .onChange(of: selectedSong) { _, newSong in
                if let song = newSong {
                    songDuration = song.playbackDuration
                    if buttonName.isEmpty {
                        buttonName = song.title ?? "Unknown"
                    }
                }
            }
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
