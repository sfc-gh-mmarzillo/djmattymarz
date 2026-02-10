import Foundation
import MediaPlayer

// MARK: - Music Source Enum
enum MusicSource: String, Codable {
    case appleMusic = "appleMusic"
    case spotify = "spotify"
}

// MARK: - Voice Over Settings
struct VoiceOverSettings: Codable, Equatable, Hashable {
    var enabled: Bool = false
    var text: String = ""
    var voiceIdentifier: String? = nil // nil = default system voice
    var rate: Float = 0.5  // 0.0-1.0, AVSpeechUtterance default is ~0.5
    var pitch: Float = 1.0 // 0.5-2.0, default 1.0
    var volume: Float = 1.0 // 0.0-1.0
    var preDelay: Double = 0 // seconds before speaking
    var postDelay: Double = 0.5 // seconds after speaking before song starts
}

// MARK: - Sound Button Model
struct SoundButton: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var songPersistentID: UInt64
    var spotifyURI: String?
    var musicSource: MusicSource
    var startTimeSeconds: Double
    var categoryTags: [String]
    var colorHex: String
    var order: Int
    var eventID: UUID? // Now references TeamEvent
    var fadeOutEnabled: Bool
    var fadeOutDuration: Double // in seconds
    var voiceOver: VoiceOverSettings? // Optional voice announcement before song
    var isVoiceOnly: Bool // For lineup announcements with no song
    
    init(name: String, songPersistentID: UInt64 = 0, spotifyURI: String? = nil, musicSource: MusicSource = .appleMusic, startTimeSeconds: Double = 0, categoryTags: [String] = [], colorHex: String = "#007AFF", order: Int = 0, eventID: UUID? = nil, fadeOutEnabled: Bool = false, fadeOutDuration: Double = 2.0, voiceOver: VoiceOverSettings? = nil, isVoiceOnly: Bool = false) {
        self.name = name
        self.songPersistentID = songPersistentID
        self.spotifyURI = spotifyURI
        self.musicSource = musicSource
        self.startTimeSeconds = startTimeSeconds
        self.categoryTags = categoryTags
        self.colorHex = colorHex
        self.order = order
        self.eventID = eventID
        self.fadeOutEnabled = fadeOutEnabled
        self.fadeOutDuration = fadeOutDuration
        self.voiceOver = voiceOver
        self.isVoiceOnly = isVoiceOnly
    }
}

// MARK: - Team/Event Model
struct TeamEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var date: Date?  // Optional - not all events need a date
    var colorHex: String
    var iconName: String
    var order: Int
    var defaultVoiceSettings: VoiceOverSettings? // Team-level voice settings that players inherit
    
    init(name: String, date: Date? = nil, colorHex: String = "#007AFF", iconName: String = "star.fill", order: Int = 0, defaultVoiceSettings: VoiceOverSettings? = nil) {
        self.name = name
        self.date = date
        self.colorHex = colorHex
        self.iconName = iconName
        self.order = order
        self.defaultVoiceSettings = defaultVoiceSettings
    }
}

// MARK: - Legacy Event typealias (for migration compatibility)
typealias Event = TeamEvent

// MARK: - Player Model (for Lineups)
struct Player: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var number: Int
    var position: String?
    var lineupOrder: Int
    var teamEventID: UUID
    var announcementSoundID: UUID? // Reference to auto-generated voice sound
    
    init(name: String, number: Int, position: String? = nil, lineupOrder: Int = 0, teamEventID: UUID, announcementSoundID: UUID? = nil) {
        self.name = name
        self.number = number
        self.position = position
        self.lineupOrder = lineupOrder
        self.teamEventID = teamEventID
        self.announcementSoundID = announcementSoundID
    }
    
    // Baseball/softball position abbreviation expansions for natural speech
    private static let positionExpansions: [String: String] = [
        "P": "Pitcher",
        "C": "Catcher",
        "1B": "First Base",
        "2B": "Second Base",
        "3B": "Third Base",
        "SS": "Shortstop",
        "LF": "Left Field",
        "CF": "Center Field",
        "RF": "Right Field",
        "DH": "Designated Hitter",
        "OF": "Outfield",
        "IF": "Infield",
        "UT": "Utility",
        "PH": "Pinch Hitter",
        "PR": "Pinch Runner",
        "DP": "Designated Player",
        "FLEX": "Flex"
    ]
    
    // Expand position abbreviation for natural speech
    private func expandPosition(_ pos: String) -> String {
        // Check for exact match (case-insensitive)
        let upperPos = pos.uppercased().trimmingCharacters(in: .whitespaces)
        if let expanded = Player.positionExpansions[upperPos] {
            return expanded
        }
        // Return original if no expansion found
        return pos
    }
    
    // Generate announcement text
    var announcementText: String {
        var text = "Now batting, number \(number)"
        if let pos = position, !pos.isEmpty {
            text += ", \(expandPosition(pos))"
        }
        text += ", \(name)"
        return text
    }
}

// MARK: - Category Model
struct Category: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var eventID: UUID? // nil means global category (available in all events)
    var iconName: String
    var order: Int
    
    init(name: String, colorHex: String = "#007AFF", eventID: UUID? = nil, iconName: String = "tag.fill", order: Int = 0) {
        self.name = name
        self.colorHex = colorHex
        self.eventID = eventID
        self.iconName = iconName
        self.order = order
    }
    
    var isGlobal: Bool {
        eventID == nil
    }
}
