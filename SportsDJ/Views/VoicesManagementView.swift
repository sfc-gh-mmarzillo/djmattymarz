import SwiftUI

// MARK: - Team Voice Configuration View
// One voice per team - simple and clean
struct VoicesManagementView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @StateObject private var elevenLabsService = ElevenLabsService.shared
    
    var currentTeam: TeamEvent? {
        guard let id = dataStore.selectedEventID else { return nil }
        return dataStore.teamEvents.first { $0.id == id }
    }
    
    var currentVoice: Voice? {
        guard let team = currentTeam, let voiceID = team.voiceID else { return nil }
        return dataStore.voices.first { $0.id == voiceID }
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
                    VStack(spacing: 20) {
                        currentTeamHeader
                        
                        if let voice = currentVoice {
                            currentVoiceCard(voice: voice)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 8)
                        
                        selectVoiceSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Voice Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        elevenLabsService.stopAudio()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Current Team Header
    
    private var currentTeamHeader: some View {
        VStack(spacing: 8) {
            if let team = currentTeam {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: team.colorHex).opacity(0.3))
                            .frame(width: 50, height: 50)
                        Image(systemName: team.iconName)
                            .font(.title2)
                            .foregroundColor(Color(hex: team.colorHex))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice for")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(team.name)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
            }
            
            Text("All players in this lineup will use this voice")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Current Voice Card
    
    private func currentVoiceCard(voice: Voice) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#22c55e"), Color(hex: "#16a34a")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "checkmark")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Voice")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#22c55e"))
                
                Text(voice.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: voice.isElevenLabs ? "waveform" : "iphone")
                        .font(.caption2)
                    Text(voice.isElevenLabs ? "ElevenLabs AI" : "iOS Voice")
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: { clearVoice() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#22c55e").opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#22c55e").opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Select Voice Section
    
    private var selectVoiceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(currentVoice == nil ? "Select a Voice" : "Change Voice")
                .font(.headline)
                .foregroundColor(.white)
            
            // ElevenLabs voices (PRIMARY)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(Color(hex: "#6366f1"))
                    Text("AI Voices")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("RECOMMENDED")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Color(hex: "#6366f1"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#6366f1").opacity(0.2))
                        .cornerRadius(4)
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(elevenLabsService.availableVoices) { voice in
                        ElevenLabsVoiceButton(
                            voice: voice,
                            isSelected: isVoiceSelected(elevenLabsId: voice.id),
                            onSelect: { selectElevenLabsVoice(voice) },
                            onPreview: { previewElevenLabsVoice(voice) }
                        )
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            
            // iOS voices (SECONDARY)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(Color(hex: "#22c55e"))
                    Text("iOS Voices")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("BASIC")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text("Tap to select, no preview available")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        IOSVoiceButton(
                            name: "Default",
                            isSelected: isIOSVoiceSelected(nil),
                            onSelect: { selectIOSVoice(nil) }
                        )
                        
                        ForEach(SpeechService.shared.availableVoices.prefix(8), id: \.identifier) { sysVoice in
                            IOSVoiceButton(
                                name: sysVoice.name.replacingOccurrences(of: " (Enhanced)", with: ""),
                                isSelected: isIOSVoiceSelected(sysVoice.identifier),
                                onSelect: { selectIOSVoice(sysVoice.identifier) }
                            )
                        }
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Voice Selection Logic
    
    private func isVoiceSelected(elevenLabsId: String) -> Bool {
        guard let voice = currentVoice else { return false }
        return voice.isElevenLabs && voice.voiceIdentifier == elevenLabsId
    }
    
    private func isIOSVoiceSelected(_ identifier: String?) -> Bool {
        guard let voice = currentVoice else { return false }
        return !voice.isElevenLabs && voice.voiceIdentifier == identifier
    }
    
    private func selectElevenLabsVoice(_ elevenLabsVoice: ElevenLabsVoice) {
        guard let teamID = dataStore.selectedEventID else { return }
        
        // Stop any playing audio
        elevenLabsService.stopAudio()
        
        // Create or update the voice for this team
        let voiceName = "\(elevenLabsVoice.name) (AI)"
        
        print("[VoicesView] Selecting ElevenLabs voice: \(elevenLabsVoice.name) (ID: \(elevenLabsVoice.id))")
        
        // Check if we already have a voice for this team we can update
        if var existingVoice = currentVoice {
            print("[VoicesView] Updating existing voice from \(existingVoice.voiceIdentifier ?? "nil") to \(elevenLabsVoice.id)")
            existingVoice.name = voiceName
            existingVoice.voiceType = .elevenLabs
            existingVoice.voiceIdentifier = elevenLabsVoice.id
            dataStore.updateVoice(existingVoice)
            // CRITICAL: Also trigger precaching with new voice ID
            dataStore.assignVoiceToTeam(voiceID: existingVoice.id, teamID: teamID)
        } else {
            // Create new voice and assign to team
            let newVoice = Voice(
                name: voiceName,
                voiceType: .elevenLabs,
                voiceIdentifier: elevenLabsVoice.id,
                rate: 0.5,
                pitch: 1.0,
                volume: 1.0,
                preDelay: 0,
                postDelay: 0.5
            )
            dataStore.addVoice(newVoice)
            dataStore.assignVoiceToTeam(voiceID: newVoice.id, teamID: teamID)
        }
    }
    
    private func selectIOSVoice(_ identifier: String?) {
        guard let teamID = dataStore.selectedEventID else { return }
        
        elevenLabsService.stopAudio()
        
        let voiceName = identifier == nil ? "iOS Default" : "iOS Voice"
        
        if var existingVoice = currentVoice {
            existingVoice.name = voiceName
            existingVoice.voiceType = .system
            existingVoice.voiceIdentifier = identifier
            dataStore.updateVoice(existingVoice)
        } else {
            let newVoice = Voice(
                name: voiceName,
                voiceType: .system,
                voiceIdentifier: identifier,
                rate: 0.5,
                pitch: 1.0,
                volume: 1.0,
                preDelay: 0,
                postDelay: 0.5
            )
            dataStore.addVoice(newVoice)
            dataStore.assignVoiceToTeam(voiceID: newVoice.id, teamID: teamID)
        }
    }
    
    private func clearVoice() {
        guard let teamID = dataStore.selectedEventID else { return }
        elevenLabsService.stopAudio()
        dataStore.assignVoiceToTeam(voiceID: nil, teamID: teamID)
    }
    
    private func previewElevenLabsVoice(_ voice: ElevenLabsVoice) {
        elevenLabsService.stopAudio()
        print("[VoicesView] Previewing ElevenLabs voice: \(voice.name) (ID: \(voice.id))")
        elevenLabsService.previewVoice(voiceId: voice.id, text: "Now batting, number 14, First Base, Paul Konerko")
    }
}

// MARK: - ElevenLabs Voice Button

struct ElevenLabsVoiceButton: View {
    let voice: ElevenLabsVoice
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    
    @ObservedObject private var elevenLabsService = ElevenLabsService.shared
    @State private var isPreviewing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(voice.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isSelected ? .white : .gray)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#22c55e"))
                }
            }
            
            Text(voice.description)
                .font(.caption2)
                .foregroundColor(isSelected ? .white.opacity(0.7) : .gray.opacity(0.7))
                .lineLimit(2)
            
            HStack(spacing: 8) {
                Button(action: {
                    isPreviewing = true
                    onPreview()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        isPreviewing = false
                    }
                }) {
                    HStack(spacing: 4) {
                        if isPreviewing && elevenLabsService.isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#6366f1")))
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: isPreviewing ? "speaker.wave.2.fill" : "play.circle.fill")
                                .font(.caption)
                        }
                        Text(isPreviewing ? "Playing..." : "Preview")
                            .font(.caption2)
                    }
                    .foregroundColor(Color(hex: "#6366f1"))
                }
                
                Spacer()
                
                Button(action: onSelect) {
                    Text(isSelected ? "Selected" : "Use")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color(hex: "#22c55e") : Color(hex: "#6366f1"))
                        .cornerRadius(12)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color(hex: "#6366f1").opacity(0.2) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color(hex: "#6366f1") : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - iOS Voice Button

struct IOSVoiceButton: View {
    let name: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            Text(name)
                .font(.caption.weight(.medium))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "#22c55e") : Color.white.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

#Preview {
    VoicesManagementView()
        .environmentObject(DataStore())
}
