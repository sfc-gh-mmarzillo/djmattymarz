import SwiftUI

struct AddPlayerView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var number: String = ""
    @State private var position: String = ""
    @State private var showVoiceSettings = false
    
    // Voice settings for customizing the announcement
    @State private var voiceRate: Float = 0.5
    @State private var voicePitch: Float = 1.0
    @State private var voiceVolume: Float = 1.0
    @State private var selectedVoiceID: String? = nil
    
    @StateObject private var speechService = SpeechService.shared
    
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
                        // Player info section
                        playerInfoCard
                        
                        // Announcement preview
                        announcementPreviewCard
                        
                        // Voice customization (collapsible)
                        voiceSettingsCard
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
        }
    }
    
    // MARK: - Player Info Card
    
    private var playerInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Player Information", systemImage: "person.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            // Name field
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "person")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Player name (required)", text: $name)
                        .font(.body)
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
            }
            
            // Number field
            VStack(alignment: .leading, spacing: 4) {
                Text("Jersey Number")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "number")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Jersey number (required)", text: $number)
                        .font(.body)
                        .foregroundColor(.white)
                        .keyboardType(.numberPad)
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
            }
            
            // Position field
            VStack(alignment: .leading, spacing: 4) {
                Text("Position")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "sportscourt")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Position (optional)", text: $position)
                        .font(.body)
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                
                Text("e.g., Pitcher, Catcher, Center Field, 1st Base")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Announcement Preview Card
    
    private var announcementPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Announcement Preview", systemImage: "speaker.wave.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            // Preview text
            Text(announcementText)
                .font(.body)
                .foregroundColor(canSave ? .white : .gray)
                .italic()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
            
            // Preview button
            Button(action: previewAnnouncement) {
                HStack {
                    Spacer()
                    Image(systemName: speechService.isSpeaking ? "stop.fill" : "play.fill")
                        .font(.caption)
                    Text(speechService.isSpeaking ? "Stop" : "Preview Announcement")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                }
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
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Voice Settings Card
    
    private var voiceSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { showVoiceSettings.toggle() } }) {
                HStack {
                    Label("Voice Settings", systemImage: "waveform")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: showVoiceSettings ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if showVoiceSettings {
                VStack(spacing: 12) {
                    // Voice selection
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voice")
                            .font(.caption)
                            .foregroundColor(.gray)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(speechService.availableVoices, id: \.identifier) { voice in
                                    Button(action: { selectedVoiceID = voice.identifier }) {
                                        Text(voice.name.replacingOccurrences(of: " (Enhanced)", with: ""))
                                            .font(.caption2.weight(.medium))
                                            .foregroundColor(selectedVoiceID == voice.identifier ? .white : .gray)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                selectedVoiceID == voice.identifier ?
                                                Color(hex: "#6366f1") :
                                                Color.white.opacity(0.1)
                                            )
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Rate slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Speed")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.0f%%", voiceRate * 100))
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        Slider(value: $voiceRate, in: 0...1)
                            .tint(Color(hex: "#6366f1"))
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    
                    // Pitch slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Pitch")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.1f", voicePitch))
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        Slider(value: $voicePitch, in: 0.5...2.0)
                            .tint(Color(hex: "#8b5cf6"))
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    
                    // Volume slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Volume")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.0f%%", voiceVolume * 100))
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        Slider(value: $voiceVolume, in: 0...1)
                            .tint(Color(hex: "#ec4899"))
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .animation(.spring(response: 0.3), value: showVoiceSettings)
    }
    
    // MARK: - Computed Properties
    
    private var canSave: Bool {
        !name.isEmpty && !number.isEmpty && Int(number) != nil
    }
    
    private var announcementText: String {
        guard let playerNumber = Int(number), !name.isEmpty else {
            return "Next up, number [NUMBER], [NAME]"
        }
        
        var text = "Next up, number \(playerNumber)"
        if !position.isEmpty {
            text += ", \(position)"
        }
        text += ", \(name)"
        return text
    }
    
    // MARK: - Actions
    
    private func previewAnnouncement() {
        if speechService.isSpeaking {
            speechService.stop()
        } else {
            let settings = VoiceOverSettings(
                enabled: true,
                text: announcementText,
                voiceIdentifier: selectedVoiceID,
                rate: voiceRate,
                pitch: voicePitch,
                volume: voiceVolume,
                preDelay: 0,
                postDelay: 0
            )
            speechService.previewVoice(text: announcementText, settings: settings)
        }
    }
    
    private func addPlayer() {
        guard let playerNumber = Int(number),
              let currentEventID = dataStore.selectedEventID else { return }
        
        // Create voice settings for the announcement
        let voiceSettings = VoiceOverSettings(
            enabled: true,
            text: announcementText,
            voiceIdentifier: selectedVoiceID,
            rate: voiceRate,
            pitch: voicePitch,
            volume: voiceVolume,
            preDelay: 0,
            postDelay: 0.5
        )
        
        // Create player
        var player = Player(
            name: name,
            number: playerNumber,
            position: position.isEmpty ? nil : position,
            lineupOrder: dataStore.filteredPlayers.count,
            teamEventID: currentEventID
        )
        
        // Add player with announcement (this creates the sound button automatically)
        _ = dataStore.addPlayerWithAnnouncement(player, voiceSettings: voiceSettings)
        
        speechService.stop()
        dismiss()
    }
}

#Preview {
    AddPlayerView()
        .environmentObject(DataStore())
}
