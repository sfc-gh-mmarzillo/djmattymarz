import SwiftUI

struct VoicesManagementView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var speechService = SpeechService.shared
    
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
}

struct VoiceCard: View {
    @EnvironmentObject var dataStore: DataStore
    let voice: Voice
    let onEdit: () -> Void
    @ObservedObject private var speechService = SpeechService.shared
    @State private var showingDeleteAlert = false
    
    var assignedTeams: [TeamEvent] {
        dataStore.teamEvents.filter { $0.voiceID == voice.id }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#22c55e"), Color(hex: "#14b8a6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
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
            
            Button(action: previewVoice) {
                Image(systemName: speechService.isSpeaking ? "stop.fill" : "play.fill")
                    .font(.body)
                    .foregroundColor(Color(hex: "#6366f1"))
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
        if speechService.isSpeaking {
            speechService.stop()
        } else {
            let settings = voice.toVoiceOverSettings(text: "Now batting, number 7, Center Field, Mickey Mantle")
            speechService.previewVoice(text: settings.text, settings: settings)
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
    
    let voice: Voice?
    
    @State private var voiceName: String = ""
    @State private var voiceRate: Float = 0.5
    @State private var voicePitch: Float = 1.0
    @State private var voiceVolume: Float = 1.0
    @State private var selectedVoiceIdentifier: String? = nil
    @State private var selectedLineupIDs: Set<UUID> = []
    
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
                        systemVoiceCard
                        voiceSettingsCard
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
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVoice()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(voiceName.isEmpty ? .gray : Color(hex: "#6366f1"))
                    .disabled(voiceName.isEmpty)
                }
            }
            .onAppear {
                loadVoice()
            }
        }
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
                Image(systemName: speechService.isSpeaking ? "stop.fill" : "play.fill")
                Text(speechService.isSpeaking ? "Stop" : "Preview Voice")
                    .font(.headline)
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#22c55e"), Color(hex: "#14b8a6")],
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
            voiceRate = v.rate
            voicePitch = v.pitch
            voiceVolume = v.volume
            selectedVoiceIdentifier = v.voiceIdentifier
            selectedLineupIDs = Set(dataStore.teamEvents.filter { $0.voiceID == v.id }.map { $0.id })
        } else {
            voiceName = ""
            voiceRate = 0.5
            voicePitch = 1.0
            voiceVolume = 1.0
            selectedVoiceIdentifier = nil
            selectedLineupIDs = []
        }
    }
    
    private func previewVoice() {
        if speechService.isSpeaking {
            speechService.stop()
        } else {
            let settings = VoiceOverSettings(
                enabled: true,
                text: "Now batting, number 7, Center Field, Mickey Mantle",
                voiceIdentifier: selectedVoiceIdentifier,
                rate: voiceRate,
                pitch: voicePitch,
                volume: voiceVolume,
                preDelay: 0,
                postDelay: 0
            )
            speechService.previewVoice(text: settings.text, settings: settings)
        }
    }
    
    private func saveVoice() {
        speechService.stop()
        
        if var existingVoice = voice {
            existingVoice.name = voiceName
            existingVoice.voiceIdentifier = selectedVoiceIdentifier
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
                voiceIdentifier: selectedVoiceIdentifier,
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
