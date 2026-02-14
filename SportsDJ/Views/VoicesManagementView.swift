import SwiftUI

struct VoicesManagementView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var speechService = SpeechService.shared
    @ObservedObject private var elevenLabsService = ElevenLabsService.shared
    
    @State private var showingAddVoice = false
    @State private var editingVoice: Voice?
    
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
                    LazyVStack(spacing: 12) {
                        elevenLabsStatusCard
                        
                        ForEach(dataStore.voices) { voice in
                            VoiceCard(voice: voice) {
                                editingVoice = voice
                            }
                        }
                        
                        AddVoiceCard {
                            showingAddVoice = true
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Voices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingAddVoice) {
                EditVoiceView(voice: nil)
            }
            .sheet(item: $editingVoice) { voice in
                EditVoiceView(voice: voice)
            }
        }
    }
    
    private var elevenLabsStatusCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "waveform")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ElevenLabs AI Voices")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Realistic AI announcer voices enabled")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#22c55e"))
                }
                
                Spacer()
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "#22c55e"))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#6366f1").opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct VoiceCard: View {
    @EnvironmentObject var dataStore: DataStore
    let voice: Voice
    let onEdit: () -> Void
    @ObservedObject private var speechService = SpeechService.shared
    @ObservedObject private var elevenLabsService = ElevenLabsService.shared
    @State private var showingDeleteAlert = false
    @State private var isPlaying = false
    
    var assignedTeams: [TeamEvent] {
        dataStore.teamEvents.filter { $0.voiceID == voice.id }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: voice.isElevenLabs ? 
                                [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")] :
                                [Color(hex: "#22c55e"), Color(hex: "#14b8a6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: voice.isElevenLabs ? "waveform" : "mic.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(voice.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if voice.isElevenLabs {
                        Text("AI")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#6366f1"))
                            .cornerRadius(4)
                    }
                }
                
                if assignedTeams.isEmpty {
                    Text("Not assigned to any lineup")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("Assigned to: \(assignedTeams.map { $0.name }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#22c55e"))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if elevenLabsService.isGenerating && isPlaying {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#6366f1")))
                    .scaleEffect(0.8)
            } else {
                Button(action: previewVoice) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.body)
                        .foregroundColor(Color(hex: "#6366f1"))
                }
            }
            
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "#6366f1"))
            }
            
            Button(action: { showingDeleteAlert = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .alert("Delete Voice?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                dataStore.deleteVoice(voice)
            }
        } message: {
            Text("This will remove the voice from any lineups using it.")
        }
    }
    
    private func previewVoice() {
        if isPlaying {
            speechService.stop()
            elevenLabsService.stopAudio()
            isPlaying = false
        } else {
            isPlaying = true
            let sampleText = "Now batting, number 14, First Base, Paul Konerko"
            
            if voice.isElevenLabs, let voiceId = voice.voiceIdentifier {
                elevenLabsService.previewVoice(voiceId: voiceId, text: sampleText)
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    isPlaying = false
                }
            } else {
                let settings = voice.toVoiceOverSettings(text: sampleText)
                speechService.previewVoice(text: settings.text, settings: settings)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    isPlaying = false
                }
            }
        }
    }
}

struct AddVoiceCard: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                
                Text("Add New Voice")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
                    )
            )
        }
    }
}

struct EditVoiceView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var speechService = SpeechService.shared
    @ObservedObject private var elevenLabsService = ElevenLabsService.shared
    
    let voice: Voice?
    
    @State private var voiceName: String = ""
    @State private var voiceType: VoiceType = .system
    @State private var voiceRate: Float = 0.5
    @State private var voicePitch: Float = 1.0
    @State private var voiceVolume: Float = 1.0
    @State private var selectedVoiceIdentifier: String? = nil
    @State private var selectedElevenLabsVoice: String? = nil
    @State private var selectedLineupIDs: Set<UUID> = []
    @State private var isPreviewPlaying = false
    
    var isEditing: Bool { voice != nil }
    
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
                        voiceNameCard
                        voiceTypeSelector
                        
                        if voiceType == .system {
                            systemVoiceCard
                            voiceSettingsCard
                        } else {
                            elevenLabsVoiceCard
                        }
                        
                        assignToLineupsCard
                        previewButton
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "Edit Voice" : "New Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        speechService.stop()
                        elevenLabsService.stopAudio()
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVoice()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(canSave ? Color(hex: "#6366f1") : .gray)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadVoice()
            }
        }
    }
    
    private var canSave: Bool {
        guard !voiceName.isEmpty else { return false }
        if voiceType == .elevenLabs {
            return selectedElevenLabsVoice != nil
        }
        return true
    }
    
    private var voiceNameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Voice Name", systemImage: "textformat")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            TextField("e.g., Stadium Announcer", text: $voiceName)
                .font(.body)
                .foregroundColor(.white)
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var voiceTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Voice Type", systemImage: "speaker.wave.3.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                Button(action: { voiceType = .system }) {
                    VStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.title2)
                        Text("iOS Voice")
                            .font(.caption.weight(.medium))
                        Text("Built-in")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(voiceType == .system ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        voiceType == .system ?
                        Color(hex: "#22c55e") :
                        Color.white.opacity(0.08)
                    )
                    .cornerRadius(12)
                }
                
                Button(action: { voiceType = .elevenLabs }) {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.title2)
                        Text("ElevenLabs")
                            .font(.caption.weight(.medium))
                        Text("AI Voice")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(voiceType == .elevenLabs ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        voiceType == .elevenLabs ?
                        Color(hex: "#6366f1") :
                        Color.white.opacity(0.08)
                    )
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var systemVoiceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("System Voice", systemImage: "person.wave.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(action: { selectedVoiceIdentifier = nil }) {
                        VStack(spacing: 2) {
                            Text("Announcer")
                                .font(.caption2.weight(.medium))
                            Text("(Default)")
                                .font(.caption2)
                        }
                        .foregroundColor(selectedVoiceIdentifier == nil ? .white : .gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            selectedVoiceIdentifier == nil ?
                            Color(hex: "#22c55e") :
                            Color.white.opacity(0.1)
                        )
                        .cornerRadius(6)
                    }
                    
                    ForEach(speechService.availableVoices.prefix(10), id: \.identifier) { sysVoice in
                        Button(action: { selectedVoiceIdentifier = sysVoice.identifier }) {
                            Text(sysVoice.name.replacingOccurrences(of: " (Enhanced)", with: ""))
                                .font(.caption2.weight(.medium))
                                .foregroundColor(selectedVoiceIdentifier == sysVoice.identifier ? .white : .gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    selectedVoiceIdentifier == sysVoice.identifier ?
                                    Color(hex: "#6366f1") :
                                    Color.white.opacity(0.1)
                                )
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var elevenLabsVoiceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ElevenLabs Voice", systemImage: "waveform")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(elevenLabsService.availableVoices) { voice in
                    Button(action: { selectedElevenLabsVoice = voice.id }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(voice.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(selectedElevenLabsVoice == voice.id ? .white : .gray)
                            
                            Text(voice.description)
                                .font(.caption2)
                                .foregroundColor(selectedElevenLabsVoice == voice.id ? .white.opacity(0.7) : .gray.opacity(0.7))
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            selectedElevenLabsVoice == voice.id ?
                            Color(hex: "#6366f1") :
                            Color.white.opacity(0.08)
                        )
                        .cornerRadius(8)
                    }
                }
            }
            
            Text("Tip: Josh and Patrick are great for stadium announcements")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var voiceSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Voice Settings", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speed")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.0f%%", voiceRate * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white)
                }
                Slider(value: $voiceRate, in: 0...1)
                    .tint(Color(hex: "#6366f1"))
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pitch")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.1f", voicePitch))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white)
                }
                Slider(value: $voicePitch, in: 0.5...2.0)
                    .tint(Color(hex: "#8b5cf6"))
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.0f%%", voiceVolume * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white)
                }
                Slider(value: $voiceVolume, in: 0...1)
                    .tint(Color(hex: "#ec4899"))
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var assignToLineupsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Assign to Lineups", systemImage: "list.number")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            Text("Players added to these lineups will use this voice")
                .font(.caption)
                .foregroundColor(.gray)
            
            ForEach(dataStore.teamEvents) { team in
                Button(action: {
                    if selectedLineupIDs.contains(team.id) {
                        selectedLineupIDs.remove(team.id)
                    } else {
                        selectedLineupIDs.insert(team.id)
                    }
                }) {
                    HStack {
                        Image(systemName: team.iconName)
                            .font(.caption)
                            .foregroundColor(Color(hex: team.colorHex))
                        
                        Text(team.name)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: selectedLineupIDs.contains(team.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedLineupIDs.contains(team.id) ? Color(hex: "#22c55e") : .gray)
                    }
                    .padding(12)
                    .background(
                        selectedLineupIDs.contains(team.id) ?
                        Color(hex: "#22c55e").opacity(0.1) :
                        Color.white.opacity(0.08)
                    )
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var previewButton: some View {
        Button(action: previewVoice) {
            HStack {
                Spacer()
                if elevenLabsService.isGenerating && isPreviewPlaying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: isPreviewPlaying ? "stop.fill" : "play.fill")
                }
                Text(isPreviewPlaying ? "Stop" : "Preview Voice")
                    .font(.headline)
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: voiceType == .elevenLabs ? 
                        [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")] :
                        [Color(hex: "#22c55e"), Color(hex: "#14b8a6")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }
    
    private func loadVoice() {
        if let v = voice {
            voiceName = v.name
            voiceType = v.voiceType
            voiceRate = v.rate
            voicePitch = v.pitch
            voiceVolume = v.volume
            if v.isElevenLabs {
                selectedElevenLabsVoice = v.voiceIdentifier
            } else {
                selectedVoiceIdentifier = v.voiceIdentifier
            }
            selectedLineupIDs = Set(dataStore.teamEvents.filter { $0.voiceID == v.id }.map { $0.id })
        } else {
            voiceName = ""
            voiceType = .system
            voiceRate = 0.5
            voicePitch = 1.0
            voiceVolume = 1.0
            selectedVoiceIdentifier = nil
            selectedElevenLabsVoice = nil
            selectedLineupIDs = []
        }
    }
    
    private func previewVoice() {
        let sampleText = "Now batting, number 14, First Base, Paul Konerko"
        
        if isPreviewPlaying {
            speechService.stop()
            elevenLabsService.stopAudio()
            isPreviewPlaying = false
        } else {
            isPreviewPlaying = true
            
            if voiceType == .elevenLabs, let voiceId = selectedElevenLabsVoice {
                elevenLabsService.previewVoice(voiceId: voiceId, text: sampleText)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    isPreviewPlaying = false
                }
            } else {
                let settings = VoiceOverSettings(
                    enabled: true,
                    text: sampleText,
                    voiceIdentifier: selectedVoiceIdentifier,
                    rate: voiceRate,
                    pitch: voicePitch,
                    volume: voiceVolume,
                    preDelay: 0,
                    postDelay: 0
                )
                speechService.previewVoice(text: settings.text, settings: settings)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    isPreviewPlaying = false
                }
            }
        }
    }
    
    private func saveVoice() {
        speechService.stop()
        elevenLabsService.stopAudio()
        
        let voiceIdentifier = voiceType == .elevenLabs ? selectedElevenLabsVoice : selectedVoiceIdentifier
        
        if var existingVoice = voice {
            existingVoice.name = voiceName
            existingVoice.voiceType = voiceType
            existingVoice.voiceIdentifier = voiceIdentifier
            existingVoice.rate = voiceRate
            existingVoice.pitch = voicePitch
            existingVoice.volume = voiceVolume
            dataStore.updateVoice(existingVoice)
            
            for team in dataStore.teamEvents {
                if selectedLineupIDs.contains(team.id) {
                    dataStore.assignVoiceToTeam(voiceID: existingVoice.id, teamID: team.id)
                } else if team.voiceID == existingVoice.id {
                    dataStore.assignVoiceToTeam(voiceID: nil, teamID: team.id)
                }
            }
        } else {
            let newVoice = Voice(
                name: voiceName,
                voiceType: voiceType,
                voiceIdentifier: voiceIdentifier,
                rate: voiceRate,
                pitch: voicePitch,
                volume: voiceVolume,
                preDelay: 0,
                postDelay: 0.5
            )
            dataStore.addVoice(newVoice)
            
            for teamID in selectedLineupIDs {
                dataStore.assignVoiceToTeam(voiceID: newVoice.id, teamID: teamID)
            }
        }
        
        dismiss()
    }
}

#Preview {
    VoicesManagementView()
        .environmentObject(DataStore())
}
