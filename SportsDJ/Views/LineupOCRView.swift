import SwiftUI
import Vision
import PhotosUI

struct LineupOCRView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isProcessing = false
    @State private var recognizedPlayers: [RecognizedPlayer] = []
    @State private var errorMessage: String?
    @State private var showResults = false
    
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
                
                if showResults {
                    resultsView
                } else {
                    importView
                }
            }
            .navigationTitle(showResults ? "Review Players" : "Import Lineup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if showResults {
                        Button("Import") { importPlayers() }
                            .font(.body.weight(.semibold))
                            .foregroundColor(selectedPlayersCount > 0 ? Color(hex: "#6366f1") : .gray)
                            .disabled(selectedPlayersCount == 0)
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onChange(of: selectedImage) { newValue in
                if let image = newValue {
                    processImage(image)
                }
            }
        }
    }
    
    // MARK: - Import View
    
    private var importView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#6366f1").opacity(0.2), Color(hex: "#8b5cf6").opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Import from Screenshot")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                
                Text("Take a screenshot of your roster from\nGameChanger or another app")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: 1, text: "Open GameChanger or your roster app")
                instructionRow(number: 2, text: "Navigate to your team's lineup/roster")
                instructionRow(number: 3, text: "Take a screenshot showing player names & numbers")
                instructionRow(number: 4, text: "Select the screenshot below")
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .padding(.horizontal)
            
            Spacer()
            
            // Select image button
            Button(action: { showImagePicker = true }) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Select Screenshot")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            
            if isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Analyzing image...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 32)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(Color(hex: "#f43f5e"))
                    .padding()
            }
        }
    }
    
    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#6366f1"))
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    // MARK: - Results View
    
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Summary header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Found \(recognizedPlayers.count) player\(recognizedPlayers.count == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(selectedPlayersCount) selected for import")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: selectAll) {
                    Text(allSelected ? "Deselect All" : "Select All")
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color(hex: "#6366f1"))
                }
            }
            .padding()
            .background(Color(hex: "#1a1a2e").opacity(0.8))
            
            // Player list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach($recognizedPlayers) { $player in
                        RecognizedPlayerRow(player: $player)
                    }
                }
                .padding()
            }
            
            // Retry button
            Button(action: { 
                showResults = false
                recognizedPlayers = []
                selectedImage = nil
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Try Different Screenshot")
                }
                .font(.subheadline)
                .foregroundColor(Color(hex: "#8b5cf6"))
            }
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Computed Properties
    
    private var selectedPlayersCount: Int {
        recognizedPlayers.filter { $0.isSelected }.count
    }
    
    private var allSelected: Bool {
        recognizedPlayers.allSatisfy { $0.isSelected }
    }
    
    // MARK: - Actions
    
    private func selectAll() {
        let newValue = !allSelected
        for i in recognizedPlayers.indices {
            recognizedPlayers[i].isSelected = newValue
        }
    }
    
    private func processImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        
        guard let cgImage = image.cgImage else {
            errorMessage = "Could not process image"
            isProcessing = false
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            DispatchQueue.main.async {
                isProcessing = false
                
                if let error = error {
                    errorMessage = "Recognition failed: \(error.localizedDescription)"
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    errorMessage = "No text found in image"
                    return
                }
                
                let recognizedText = observations.compactMap { observation -> String? in
                    observation.topCandidates(1).first?.string
                }
                
                parseRoster(from: recognizedText)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Failed to process image: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    private func parseRoster(from lines: [String]) {
        var players: [RecognizedPlayer] = []
        
        // Common patterns for roster formats:
        // "12 John Smith" or "#12 John Smith" or "John Smith 12" or "John Smith #12"
        // "12 John Smith P" or "12 John Smith Pitcher"
        
        let numberPattern = #"#?(\d{1,3})"#
        let numberRegex = try? NSRegularExpression(pattern: numberPattern, options: [])
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Try to find a number in the line
            guard let regex = numberRegex,
                  let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)),
                  let numberRange = Range(match.range(at: 1), in: trimmed),
                  let number = Int(trimmed[numberRange]) else {
                continue
            }
            
            // Remove the number from the string to get the name
            var nameString = trimmed
            if let fullMatchRange = Range(match.range, in: trimmed) {
                nameString = trimmed.replacingCharacters(in: fullMatchRange, with: "")
            }
            
            // Clean up the name
            nameString = nameString.trimmingCharacters(in: .whitespacesAndNewlines)
            nameString = nameString.trimmingCharacters(in: CharacterSet(charactersIn: "-–—"))
            nameString = nameString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip if name is too short or looks like a position only
            guard nameString.count >= 2 else { continue }
            
            // Try to extract position (common abbreviations at end)
            let positionPatterns = ["P", "C", "1B", "2B", "3B", "SS", "LF", "CF", "RF", "DH", "OF", "IF", 
                                    "Pitcher", "Catcher", "First Base", "Second Base", "Third Base", 
                                    "Shortstop", "Left Field", "Center Field", "Right Field"]
            
            var position: String? = nil
            var name = nameString
            
            for posPattern in positionPatterns {
                if nameString.hasSuffix(" \(posPattern)") || nameString.hasSuffix(" \(posPattern.lowercased())") {
                    position = posPattern
                    name = String(nameString.dropLast(posPattern.count + 1))
                    break
                }
            }
            
            // Filter out obvious non-player entries
            let skipWords = ["lineup", "roster", "team", "batting", "order", "position", "name", "number", "#"]
            let nameLower = name.lowercased()
            if skipWords.contains(where: { nameLower == $0 }) {
                continue
            }
            
            // Create recognized player
            let player = RecognizedPlayer(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                number: number,
                position: position,
                isSelected: true
            )
            
            // Avoid duplicates
            if !players.contains(where: { $0.number == number && $0.name == player.name }) {
                players.append(player)
            }
        }
        
        // Sort by number
        players.sort { $0.number < $1.number }
        
        if players.isEmpty {
            errorMessage = "Could not find any players in the image. Try a clearer screenshot."
        } else {
            recognizedPlayers = players
            showResults = true
        }
    }
    
    private func importPlayers() {
        guard let eventID = dataStore.selectedEventID else { return }
        
        let selectedPlayers = recognizedPlayers.filter { $0.isSelected }
        
        for recognized in selectedPlayers {
            let player = Player(
                name: recognized.name,
                number: recognized.number,
                position: recognized.position,
                lineupOrder: dataStore.filteredPlayers.count,
                teamEventID: eventID
            )
            
            _ = dataStore.addPlayerWithAnnouncement(player)
        }
        
        dismiss()
    }
}

// MARK: - Supporting Types

struct RecognizedPlayer: Identifiable {
    let id = UUID()
    var name: String
    var number: Int
    var position: String?
    var isSelected: Bool
}

struct RecognizedPlayerRow: View {
    @Binding var player: RecognizedPlayer
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: { player.isSelected.toggle() }) {
                Image(systemName: player.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(player.isSelected ? Color(hex: "#6366f1") : .gray)
            }
            
            // Number badge
            ZStack {
                Circle()
                    .fill(
                        player.isSelected ?
                        LinearGradient(colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 40, height: 40)
                
                Text("\(player.number)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(player.isSelected ? .white : .gray)
                
                if let position = player.position {
                    Text(position)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(player.isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(player.isSelected ? Color(hex: "#6366f1").opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            
            provider.loadObject(ofClass: UIImage.self) { image, error in
                DispatchQueue.main.async {
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}

#Preview {
    LineupOCRView()
        .environmentObject(DataStore())
}
