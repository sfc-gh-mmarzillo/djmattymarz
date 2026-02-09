import SwiftUI

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
            .navigationTitle("🎵 SportsDJ")
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
                AddButtonView()
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
                        isPlaying: audioPlayer.currentButtonID == button.id,
                        isEditMode: isEditMode
                    )
                    .onTapGesture {
                        if isEditMode {
                            editingButton = button
                        } else {
                            if audioPlayer.currentButtonID == button.id {
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
            if audioPlayer.isPlaying || !audioPlayer.nowPlayingTitle.isEmpty {
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Now Playing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(audioPlayer.nowPlayingTitle)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text(formatTime(audioPlayer.currentTime))
                            .font(.caption)
                            .monospacedDigit()
                        
                        Button(action: { audioPlayer.stop() }) {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
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
    let isEditMode: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: button.colorHex).opacity(isPlaying ? 0.3 : 0.15))
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: button.colorHex), lineWidth: isPlaying ? 3 : 1)
                
                VStack(spacing: 4) {
                    Image(systemName: isPlaying ? "speaker.wave.3.fill" : "music.note")
                        .font(.title2)
                        .foregroundColor(Color(hex: button.colorHex))
                    
                    Text(button.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                }
                .padding(8)
                
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
        }
        .frame(height: 100)
        .scaleEffect(isPlaying ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
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
