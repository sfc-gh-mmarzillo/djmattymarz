import Foundation
import Combine

// MARK: - Default Song Settings

struct DefaultSongSettings: Codable {
    var colorHex: String = "#6366f1"
    var fadeOutEnabled: Bool = false
    var fadeOutDuration: Double = 2.0
    var defaultCategories: [String] = []
    var startFromBeginning: Bool = true
}

class DataStore: ObservableObject {
    @Published var buttons: [SoundButton] = []
    @Published var categories: [Category] = []
    @Published var teamEvents: [TeamEvent] = []
    @Published var players: [Player] = []
    @Published var voices: [Voice] = []
    @Published var selectedEventID: UUID?
    @Published var defaultSettings: DefaultSongSettings = DefaultSongSettings()
    
    private let buttonsKey = "soundButtons"
    private let categoriesKey = "categories"
    private let eventsKey = "events"
    private let playersKey = "players"
    private let voicesKey = "voices"
    private let selectedEventKey = "selectedEvent"
    private let defaultSettingsKey = "defaultSongSettings"
    
    // Legacy compatibility - expose as 'events' for existing code
    var events: [TeamEvent] {
        get { teamEvents }
        set { teamEvents = newValue }
    }
    
    init() {
        loadData()
        migrateDataIfNeeded()
        
        // Create default team/event for new users
        if teamEvents.isEmpty {
            let defaultEvent = TeamEvent(
                name: "My First Team",
                date: nil,
                colorHex: "#6366f1",
                iconName: "sportscourt.fill"
            )
            teamEvents.append(defaultEvent)
            saveEvents()
        }
        
        // Always ensure a team/event is selected
        if selectedEventID == nil && !teamEvents.isEmpty {
            selectedEventID = teamEvents.first?.id
            UserDefaults.standard.set(selectedEventID?.uuidString, forKey: selectedEventKey)
        }
        
        if categories.isEmpty {
            categories = [
                Category(name: "First Category", colorHex: "#6366f1", iconName: "star.fill")
            ]
            saveCategories()
        }
        
        // Create default voice for new users - ElevenLabs Josh (best announcer voice)
        if voices.isEmpty {
            let defaultVoice = Voice(
                name: "Josh (AI)",
                voiceType: .elevenLabs,
                voiceIdentifier: "TxGEqnHWrfWFTfGW9XjX", // Josh - authoritative sports announcer
                rate: 0.5,
                pitch: 1.0,
                volume: 1.0,
                preDelay: 0,
                postDelay: 0.5
            )
            voices.append(defaultVoice)
            saveVoices()
            
            // Auto-assign to first team
            if let firstTeam = teamEvents.first {
                teamEvents[0].voiceID = defaultVoice.id
                saveEvents()
            }
        }
    }
    
    // MARK: - Event Filtering
    
    var filteredCategories: [Category] {
        categories.filter { category in
            category.isGlobal || category.eventID == selectedEventID
        }
    }
    
    var filteredButtons: [SoundButton] {
        guard let eventID = selectedEventID else { return [] }
        return buttons.filter { $0.eventID == eventID }
    }
    
    var filteredPlayers: [Player] {
        guard let eventID = selectedEventID else { return [] }
        return players.filter { $0.teamEventID == eventID }.sorted { $0.lineupOrder < $1.lineupOrder }
    }
    
    // MARK: - Button Methods
    
    func addButton(_ button: SoundButton) {
        guard let eventID = selectedEventID else {
            print("Warning: Cannot add button without a selected event")
            return
        }
        var newButton = button
        newButton.order = buttons.count
        newButton.eventID = eventID
        buttons.append(newButton)
        saveButtons()
    }
    
    func updateButton(_ button: SoundButton) {
        if let index = buttons.firstIndex(where: { $0.id == button.id }) {
            buttons[index] = button
            saveButtons()
        }
    }
    
    func deleteButton(_ button: SoundButton) {
        buttons.removeAll { $0.id == button.id }
        saveButtons()
    }
    
    func moveButton(from source: IndexSet, to destination: Int) {
        buttons.move(fromOffsets: source, toOffset: destination)
        for i in buttons.indices {
            buttons[i].order = i
        }
        saveButtons()
    }
    
    // MARK: - Category Methods
    
    func addCategory(_ category: Category) {
        categories.append(category)
        saveCategories()
    }
    
    func updateCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories()
        }
    }
    
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        for i in buttons.indices {
            buttons[i].categoryTags.removeAll { $0 == category.name }
        }
        saveCategories()
        saveButtons()
    }
    
    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        for i in categories.indices {
            categories[i].order = i
        }
        saveCategories()
    }
    
    // MARK: - Team/Event Methods
    
    func addEvent(_ event: TeamEvent) {
        teamEvents.append(event)
        saveEvents()
    }
    
    func updateEvent(_ event: TeamEvent) {
        if let index = teamEvents.firstIndex(where: { $0.id == event.id }) {
            teamEvents[index] = event
            saveEvents()
        }
    }
    
    func deleteEvent(_ event: TeamEvent) {
        // Prevent deleting the last team/event
        guard teamEvents.count > 1 else { return }
        
        // Delete all categories specific to this team/event
        categories.removeAll { $0.eventID == event.id }
        
        // Delete all buttons specific to this team/event
        buttons.removeAll { $0.eventID == event.id }
        
        // Delete all players in this team/event
        players.removeAll { $0.teamEventID == event.id }
        
        // Remove the team/event
        teamEvents.removeAll { $0.id == event.id }
        
        // Auto-select another team/event if deleted one was selected
        if selectedEventID == event.id {
            selectedEventID = teamEvents.first?.id
            UserDefaults.standard.set(selectedEventID?.uuidString, forKey: selectedEventKey)
        }
        
        saveEvents()
        saveCategories()
        saveButtons()
        savePlayers()
    }
    
    func selectEvent(_ event: TeamEvent?) {
        selectedEventID = event?.id
        UserDefaults.standard.set(selectedEventID?.uuidString, forKey: selectedEventKey)
        
        // Pre-cache audio for the newly selected team's players
        if let eventID = event?.id {
            precacheTeamPlayerAudio(teamID: eventID)
        }
    }
    
    func moveEvent(from source: IndexSet, to destination: Int) {
        teamEvents.move(fromOffsets: source, toOffset: destination)
        for i in teamEvents.indices {
            teamEvents[i].order = i
        }
        saveEvents()
    }
    
    // MARK: - Voice Methods
    
    func addVoice(_ voice: Voice) {
        voices.append(voice)
        saveVoices()
    }
    
    func updateVoice(_ voice: Voice) {
        if let index = voices.firstIndex(where: { $0.id == voice.id }) {
            voices[index] = voice
            saveVoices()
        }
    }
    
    func deleteVoice(_ voice: Voice) {
        // Remove voice reference from any teams using it
        for i in teamEvents.indices {
            if teamEvents[i].voiceID == voice.id {
                teamEvents[i].voiceID = nil
            }
        }
        voices.removeAll { $0.id == voice.id }
        saveVoices()
        saveEvents()
    }
    
    // Get voice for a specific team/lineup
    func voiceForTeam(_ teamID: UUID) -> Voice? {
        guard let team = teamEvents.first(where: { $0.id == teamID }),
              let voiceID = team.voiceID else { return nil }
        return voices.first(where: { $0.id == voiceID })
    }
    
    // Assign a voice to a team/lineup and update all existing player sounds
    func assignVoiceToTeam(voiceID: UUID?, teamID: UUID) {
        if let index = teamEvents.firstIndex(where: { $0.id == teamID }) {
            teamEvents[index].voiceID = voiceID
            saveEvents()
            
            // Update all existing players' announcement sounds with new voice
            updateAllPlayerSoundsForTeam(teamID: teamID)
            
            // Pre-cache ElevenLabs audio for all players in this team
            precacheTeamPlayerAudio(teamID: teamID)
        }
    }
    
    // Pre-cache ElevenLabs audio for all players in a team
    private func precacheTeamPlayerAudio(teamID: UUID) {
        guard let voice = voiceForTeam(teamID),
              voice.voiceType == .elevenLabs,
              let elevenLabsId = voice.elevenLabsID else {
            print("[DataStore] Precache: Skipping - not an ElevenLabs voice")
            return
        }
        
        let teamPlayers = players.filter { $0.teamEventID == teamID }
        guard !teamPlayers.isEmpty else {
            print("[DataStore] Precache: No players in team")
            return
        }
        
        print("[DataStore] Precache: Starting for \(teamPlayers.count) players with voice \(voice.name)")
        
        let announcements = teamPlayers.map { player in
            (text: player.announcementText, voiceId: elevenLabsId)
        }
        
        ElevenLabsService.shared.precachePlayerAnnouncements(players: announcements)
    }
    
    // Pre-cache all ElevenLabs audio for all teams on app startup
    // This ensures offline playback works immediately without network dependency
    func precacheAllPlayerAudio() {
        print("[DataStore] Startup precache: Checking all teams...")
        
        for team in teamEvents {
            guard let voice = voiceForTeam(team.id),
                  voice.voiceType == .elevenLabs,
                  let elevenLabsId = voice.elevenLabsID else {
                continue
            }
            
            let teamPlayers = players.filter { $0.teamEventID == team.id }
            guard !teamPlayers.isEmpty else { continue }
            
            print("[DataStore] Startup precache: Team '\(team.name)' - \(teamPlayers.count) players")
            
            let announcements = teamPlayers.map { player in
                (text: player.announcementText, voiceId: elevenLabsId)
            }
            
            ElevenLabsService.shared.precachePlayerAnnouncements(players: announcements)
        }
    }
    
    // Update all player sounds when team voice changes
    private func updateAllPlayerSoundsForTeam(teamID: UUID) {
        let teamPlayers = players.filter { $0.teamEventID == teamID }
        for player in teamPlayers {
            updatePlayerSound(player)
        }
    }
    
    // MARK: - Player/Lineup Methods
    
    func addPlayer(_ player: Player) -> Player {
        var newPlayer = player
        newPlayer.lineupOrder = filteredPlayers.count
        players.append(newPlayer)
        savePlayers()
        return newPlayer
    }
    
    func updatePlayer(_ player: Player) {
        if let index = players.firstIndex(where: { $0.id == player.id }) {
            players[index] = player
            savePlayers()
        }
    }
    
    func deletePlayer(_ player: Player) {
        // Also delete the associated announcement sound if exists
        if let soundID = player.announcementSoundID {
            buttons.removeAll { $0.id == soundID }
            saveButtons()
        }
        players.removeAll { $0.id == player.id }
        
        // Reorder remaining players
        reorderPlayersForCurrentEvent()
        savePlayers()
    }
    
    func movePlayer(from source: IndexSet, to destination: Int) {
        var currentPlayers = filteredPlayers
        currentPlayers.move(fromOffsets: source, toOffset: destination)
        
        // Update lineup order
        for (index, player) in currentPlayers.enumerated() {
            if let playerIndex = players.firstIndex(where: { $0.id == player.id }) {
                players[playerIndex].lineupOrder = index
            }
        }
        savePlayers()
    }
    
    private func reorderPlayersForCurrentEvent() {
        let currentPlayers = filteredPlayers
        for (index, player) in currentPlayers.enumerated() {
            if let playerIndex = players.firstIndex(where: { $0.id == player.id }) {
                players[playerIndex].lineupOrder = index
            }
        }
    }
    
    // Create announcement sound for a player
    func createAnnouncementSound(for player: Player, voiceSettings: VoiceOverSettings? = nil) -> SoundButton {
        let teamVoice = voiceForTeam(player.teamEventID)
        
        let settings: VoiceOverSettings
        if let customSettings = voiceSettings {
            settings = customSettings
        } else if let voice = teamVoice {
            settings = voice.toVoiceOverSettings(text: player.announcementText)
        } else {
            // FALLBACK: Use default ElevenLabs voice (Adam) when no team voice is set
            // This ensures ElevenLabs is ALWAYS used, never iOS robot voice
            settings = VoiceOverSettings(
                enabled: true,
                text: player.announcementText,
                voiceType: .elevenLabs,
                voiceIdentifier: "pNInz6obpgDQGcFmaJgB", // Adam - default announcer voice
                rate: 0.5,
                pitch: 1.0,
                volume: 1.0,
                preDelay: 0,
                postDelay: 0.5
            )
        }
        
        var finalSettings = settings
        if finalSettings.text.isEmpty {
            finalSettings.text = player.announcementText
        }
        
        let hasSong = player.hasSong
        
        let sound = SoundButton(
            name: "📢 \(player.name)",
            songPersistentID: player.songPersistentID ?? 0,
            spotifyURI: player.spotifyURI,
            musicSource: player.musicSource ?? .appleMusic,
            startTimeSeconds: player.songStartTimeSeconds,
            categoryTags: ["Lineup"],
            colorHex: "#22c55e",
            order: buttons.count,
            eventID: player.teamEventID,
            fadeOutEnabled: false,
            fadeOutDuration: 0,
            voiceOver: finalSettings,
            isVoiceOnly: !hasSong,
            isLineupAnnouncement: hasSong
        )
        
        return sound
    }
    
    // Add player with auto-generated announcement
    func addPlayerWithAnnouncement(_ player: Player, voiceSettings: VoiceOverSettings? = nil) -> Player {
        var newPlayer = player
        newPlayer.lineupOrder = filteredPlayers.count
        
        // Create and add announcement sound
        let sound = createAnnouncementSound(for: newPlayer, voiceSettings: voiceSettings)
        buttons.append(sound)
        saveButtons()
        
        // Link player to sound
        newPlayer.announcementSoundID = sound.id
        players.append(newPlayer)
        savePlayers()
        
        // Pre-cache ElevenLabs audio for instant playback
        precachePlayerAudio(newPlayer)
        
        return newPlayer
    }
    
    // Pre-cache ElevenLabs audio for a single player
    private func precachePlayerAudio(_ player: Player) {
        guard let voice = voiceForTeam(player.teamEventID),
              voice.voiceType == .elevenLabs,
              let elevenLabsId = voice.elevenLabsID else {
            return
        }
        
        print("[DataStore] Precache: Generating audio for new player '\(player.name)'")
        ElevenLabsService.shared.precacheAudio(text: player.announcementText, voiceId: elevenLabsId)
    }
    
    func updatePlayerSound(_ player: Player) {
        guard let soundID = player.announcementSoundID,
              let soundIndex = buttons.firstIndex(where: { $0.id == soundID }) else { return }
        
        let teamVoice = voiceForTeam(player.teamEventID)
        let settings: VoiceOverSettings
        if let voice = teamVoice {
            settings = voice.toVoiceOverSettings(text: player.announcementText)
        } else {
            // FALLBACK: Use default ElevenLabs voice (Adam) when no team voice is set
            // This ensures ElevenLabs is ALWAYS used, never iOS robot voice
            settings = VoiceOverSettings(
                enabled: true,
                text: player.announcementText,
                voiceType: .elevenLabs,
                voiceIdentifier: "pNInz6obpgDQGcFmaJgB", // Adam - default announcer voice
                rate: 0.5,
                pitch: 1.0,
                volume: 1.0,
                preDelay: 0,
                postDelay: 0.5
            )
        }
        
        let hasSong = player.hasSong
        
        buttons[soundIndex].name = "📢 \(player.name)"
        buttons[soundIndex].songPersistentID = player.songPersistentID ?? 0
        buttons[soundIndex].spotifyURI = player.spotifyURI
        buttons[soundIndex].musicSource = player.musicSource ?? .appleMusic
        buttons[soundIndex].startTimeSeconds = player.songStartTimeSeconds
        buttons[soundIndex].voiceOver = settings
        buttons[soundIndex].isVoiceOnly = !hasSong
        buttons[soundIndex].isLineupAnnouncement = hasSong
        
        saveButtons()
        
        // Pre-cache the updated announcement audio
        precachePlayerAudio(player)
    }
    
    // MARK: - Default Settings Methods
    
    func updateDefaultSettings(_ settings: DefaultSongSettings) {
        defaultSettings = settings
        saveDefaultSettings()
    }
    
    // MARK: - Persistence
    
    private func saveButtons() {
        if let encoded = try? JSONEncoder().encode(buttons) {
            UserDefaults.standard.set(encoded, forKey: buttonsKey)
        }
    }
    
    private func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
        }
    }
    
    private func saveEvents() {
        if let encoded = try? JSONEncoder().encode(teamEvents) {
            UserDefaults.standard.set(encoded, forKey: eventsKey)
        }
    }
    
    private func savePlayers() {
        if let encoded = try? JSONEncoder().encode(players) {
            UserDefaults.standard.set(encoded, forKey: playersKey)
        }
    }
    
    private func saveVoices() {
        if let encoded = try? JSONEncoder().encode(voices) {
            UserDefaults.standard.set(encoded, forKey: voicesKey)
        }
    }
    
    private func saveDefaultSettings() {
        if let encoded = try? JSONEncoder().encode(defaultSettings) {
            UserDefaults.standard.set(encoded, forKey: defaultSettingsKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: buttonsKey),
           let decoded = try? JSONDecoder().decode([SoundButton].self, from: data) {
            buttons = decoded.sorted { $0.order < $1.order }
        }
        
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([Category].self, from: data) {
            categories = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: eventsKey),
           let decoded = try? JSONDecoder().decode([TeamEvent].self, from: data) {
            teamEvents = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: playersKey),
           let decoded = try? JSONDecoder().decode([Player].self, from: data) {
            players = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: voicesKey),
           let decoded = try? JSONDecoder().decode([Voice].self, from: data) {
            voices = decoded
        }
        
        if let eventIDString = UserDefaults.standard.string(forKey: selectedEventKey) {
            selectedEventID = UUID(uuidString: eventIDString)
        }
        
        if let data = UserDefaults.standard.data(forKey: defaultSettingsKey),
           let decoded = try? JSONDecoder().decode(DefaultSongSettings.self, from: data) {
            defaultSettings = decoded
        }
    }
    
    // MARK: - Migration for existing data
    
    private func migrateDataIfNeeded() {
        var needsSave = false
        
        // Migrate buttons that don't have the new fields
        for i in buttons.indices {
            if buttons[i].spotifyURI == nil && buttons[i].musicSource != .appleMusic {
                needsSave = true
            }
        }
        
        // Migrate buttons with nil eventID to first available event
        if let firstEventID = teamEvents.first?.id {
            for i in buttons.indices {
                if buttons[i].eventID == nil {
                    buttons[i].eventID = firstEventID
                    needsSave = true
                }
            }
        }
        
        // Migrate categories that don't have iconName
        for i in categories.indices {
            if categories[i].iconName.isEmpty {
                categories[i] = Category(
                    name: categories[i].name,
                    colorHex: categories[i].colorHex,
                    eventID: categories[i].eventID,
                    iconName: "tag.fill"
                )
                needsSave = true
            }
        }
        
        // Ensure "Lineup" category exists
        if !categories.contains(where: { $0.name == "Lineup" }) {
            categories.append(Category(name: "Lineup", colorHex: "#22c55e", iconName: "person.3.fill"))
            needsSave = true
        }
        
        if needsSave {
            saveButtons()
            saveCategories()
        }
    }
}
