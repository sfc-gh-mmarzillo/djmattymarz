import SwiftUI
import MediaPlayer

struct AddPlayerView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var speechService = SpeechService.shared
    
    @State private var name: String = ""
    @State private var number: String = ""
    @State private var position: String = ""
    @State private var selectedSong: MPMediaItem?
    @State private var spotifyTrack: SpotifyTrack?
    @State private var startTimeSeconds: Double = 0
    @State private var songDuration: Double = 0
    @State private var showSongPicker = false
    
    private var teamVoice: Voice? {
        guard let eventID = dataStore.selectedEventID else { return nil }
        return dataStore.voiceForTeam(eventID)
    }
    
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
                        playerInfoCard
                        songSelectionCard
                        if hasSong {
                            startTimeCard
                        }
                        previewCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        speechService.stop()
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addPlayer()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(canSave ? Color(hex: "#6366f1") : .gray)
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showSongPicker) {
                SongPickerView(
                    selectedSong: $selectedSong,
                    songDuration: $songDuration,
                    onSpotifySelect: { track in
                        spotifyTrack = track
                        songDuration = track.duration
                    }
                )
            }
        }
    }
    
    private var playerInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Player Information", systemImage: "person.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                TextField("Player name", text: $name)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Number")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("#", text: $number)
                        .font(.body)
                        .foregroundColor(.white)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                }
                .frame(width: 80)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Position")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("e.g., SS, CF, P", text: $position)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var songSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Walk-Up Song", systemImage: "music.note")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            Button(action: { showSongPicker = true }) {
                HStack(spacing: 12) {
                    if let song = selectedSong {
                        if let artwork = song.artwork?.image(at: CGSize(width: 50, height: 50)) {
                            Image(uiImage: artwork)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                        } else {
                            songPlaceholder
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
                    } else if let track = spotifyTrack {
                        songPlaceholder
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    } else {
                        songPlaceholder
                        Text("Select a song (optional)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
            }
            
            if hasSong {
                Button(action: clearSong) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Remove Song")
                    }
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var songPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(hex: "#6366f1").opacity(0.3))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(.white.opacity(0.7))
            )
    }
    
    private var startTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Start Time", systemImage: "clock")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                HStack {
                    Text(formatTime(startTimeSeconds))
                        .font(.title2.monospacedDigit().weight(.medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("/ \(formatTime(songDuration))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Slider(value: $startTimeSeconds, in: 0...max(songDuration - 1, 1))
                    .tint(Color(hex: "#6366f1"))
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Announcement Preview", systemImage: "speaker.wave.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            if let voice = teamVoice {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.caption2)
                    Text("Using \"\(voice.name)\" voice")
                        .font(.caption)
                }
                .foregroundColor(Color(hex: "#22c55e"))
            }
            
            Text(announcementText)
                .font(.body)
                .foregroundColor(canSave ? .white : .gray)
                .italic()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
            
            Button(action: previewAnnouncement) {
                HStack {
                    Spacer()
                    Image(systemName: speechService.isSpeaking ? "stop.fill" : "play.fill")
                    Text(speechService.isSpeaking ? "Stop" : "Preview")
                    Spacer()
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: canSave ? [Color(hex: "#22c55e"), Color(hex: "#14b8a6")] : [Color.gray, Color.gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.5)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var canSave: Bool {
        !name.isEmpty && !number.isEmpty && Int(number) != nil
    }
    
    private var hasSong: Bool {
        selectedSong != nil || spotifyTrack != nil
    }
    
    private var announcementText: String {
        guard let playerNumber = Int(number), !name.isEmpty else {
            return "Now batting, number [NUMBER], [NAME]"
        }
        
        var text = "Now batting, number \(playerNumber)"
        if !position.isEmpty {
            text += ", \(position)"
        }
        text += ", \(name)"
        return text
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func clearSong() {
        selectedSong = nil
        spotifyTrack = nil
        startTimeSeconds = 0
        songDuration = 0
    }
    
    private func previewAnnouncement() {
        if speechService.isSpeaking {
            speechService.stop()
        } else {
            let settings: VoiceOverSettings
            if let voice = teamVoice {
                settings = voice.toVoiceOverSettings(text: announcementText)
            } else {
                settings = VoiceOverSettings(
                    enabled: true,
                    text: announcementText,
                    voiceIdentifier: nil,
                    rate: 0.5,
                    pitch: 1.0,
                    volume: 1.0,
                    preDelay: 0,
                    postDelay: 0
                )
            }
            speechService.previewVoice(text: announcementText, settings: settings)
        }
    }
    
    private func addPlayer() {
        guard let playerNumber = Int(number),
              let currentEventID = dataStore.selectedEventID else { return }
        
        speechService.stop()
        
        let player = Player(
            name: name,
            number: playerNumber,
            position: position.isEmpty ? nil : position,
            lineupOrder: dataStore.filteredPlayers.count,
            teamEventID: currentEventID,
            songPersistentID: selectedSong?.persistentID,
            spotifyURI: spotifyTrack?.uri,
            musicSource: spotifyTrack != nil ? .spotify : .appleMusic,
            songStartTimeSeconds: startTimeSeconds
        )
        
        _ = dataStore.addPlayerWithAnnouncement(player)
        dismiss()
    }
}

#Preview {
    AddPlayerView()
        .environmentObject(DataStore())
        .environmentObject(AudioPlayerService())
}
