import SwiftUI
import MediaPlayer

struct ContentView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedFilter: String = "All"
    @State private var showingAddButton = false
    @State private var showingManageCategories = false
    @State private var editingButton: SoundButton?
    @State private var isEditMode = false
    
    var filteredButtons: [SoundButton] {
        if selectedFilter == "All" {
            return dataStore.buttons
        }
        return dataStore.buttons.filter { $0.categoryTags.contains(selectedFilter) }
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterBar
                
                if dataStore.buttons.isEmpty {
                    emptyState
                } else {
                    buttonGrid
                }
                
                nowPlayingBar
            }
            .navigationTitle("SportsDJ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditMode ? "Done" : "Edit") {
                        isEditMode.toggle()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddButton = true }) {
                            Label("Add Sound Button", systemImage: "plus.circle")
                        }
                        Button(action: { showingManageCategories = true }) {
                            Label("Manage Categories", systemImage: "tag")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddButton) {
                AddButtonView(preselectedCategory: selectedFilter == "All" ? nil : selectedFilter)
            }
            .sheet(isPresented: $showingManageCategories) {
                ManageCategoriesView()
            }
            .sheet(item: $editingButton) { button in
                EditButtonView(button: button)
            }
        }
    }
    
    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedFilter == "All") {
                    selectedFilter = "All"
                }
                
                ForEach(dataStore.categories) { category in
                    FilterChip(
                        title: category.name,
                        isSelected: selectedFilter == category.name,
                        color: Color(hex: category.colorHex)
                    ) {
                        selectedFilter = category.name
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Sound Buttons Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap + to add your first sound button")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    var buttonGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredButtons) { button in
                    SoundButtonView(
                        button: button,
                        isPlaying: audioPlayer.currentButtonID == button.id && audioPlayer.isPlaying,
                        isLoading: audioPlayer.currentButtonID == button.id && audioPlayer.isLoading,
                        isEditMode: isEditMode
                    )
                    .onTapGesture {
                        if isEditMode {
                            editingButton = button
                        } else {
                            if audioPlayer.currentButtonID == button.id && (audioPlayer.isPlaying || audioPlayer.isLoading) {
                                audioPlayer.stop()
                            } else {
                                audioPlayer.play(button: button)
                            }
                        }
                    }
                    .onLongPressGesture {
                        editingButton = button
                    }
                }
            }
            .padding()
        }
    }
    
    var nowPlayingBar: some View {
        Group {
            if audioPlayer.isPlaying || audioPlayer.isLoading || !audioPlayer.nowPlayingTitle.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        // Album artwork
                        if let artwork = audioPlayer.currentArtwork {
                            Image(uiImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .cornerRadius(6)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .foregroundColor(.secondary)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(audioPlayer.isLoading ? "Loading..." : "Now Playing")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(audioPlayer.nowPlayingTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if audioPlayer.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(formatTime(audioPlayer.currentTime))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: { audioPlayer.stop() }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemBackground))
            }
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color(.systemGray6))
                .foregroundColor(isSelected ? color : .primary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
        }
    }
}

struct SoundButtonView: View {
    let button: SoundButton
    let isPlaying: Bool
    let isLoading: Bool
    let isEditMode: Bool
    
    @State private var artwork: UIImage?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: button.colorHex).opacity(isPlaying ? 0.3 : (isLoading ? 0.1 : 0.15)))
            
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: button.colorHex), lineWidth: isPlaying ? 3 : 1)
            
            VStack(spacing: 6) {
                // Album artwork or icon
                if let artwork = artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(hex: button.colorHex).opacity(0.5), lineWidth: 1)
                        )
                        .opacity(isLoading ? 0.5 : 1.0)
                } else {
                    Image(systemName: isPlaying ? "speaker.wave.3.fill" : "music.note")
                        .font(.title3)
                        .foregroundColor(Color(hex: button.colorHex))
                        .opacity(isLoading ? 0.5 : 1.0)
                }
                
                Text(button.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isLoading ? .secondary : .primary)
            }
            .padding(6)
            
            // Loading indicator overlay
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
            
            // Playing indicator overlay
            if isPlaying && !isLoading {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color(hex: button.colorHex))
                            .cornerRadius(4)
                    }
                }
                .padding(4)
            }
            
            if isEditMode {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                            .background(Color.white.clipShape(Circle()))
                    }
                    Spacer()
                }
                .padding(4)
            }
        }
        .frame(height: 100)
        .scaleEffect(isPlaying ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
        .onAppear {
            loadArtwork()
        }
    }
    
    private func loadArtwork() {
        let predicate = MPMediaPropertyPredicate(
            value: button.songPersistentID,
            forProperty: MPMediaItemPropertyPersistentID
        )
        let query = MPMediaQuery()
        query.addFilterPredicate(predicate)
        
        if let song = query.items?.first,
           let songArtwork = song.artwork {
            artwork = songArtwork.image(at: CGSize(width: 80, height: 80))
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayerService())
        .environmentObject(DataStore())
}
