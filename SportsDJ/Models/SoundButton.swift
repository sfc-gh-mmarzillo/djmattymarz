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
    var voiceType: VoiceType = .elevenLabs // ElevenLabs is PRIMARY
    var voiceIdentifier: String? = nil // nil = default, or ElevenLabs/iOS voice ID
    var rate: Float = 0.5  // 0.0-1.0, AVSpeechUtterance default is ~0.5
    var pitch: Float = 1.0 // 0.5-2.0, default 1.0
    var volume: Float = 1.0 // 0.0-1.0
    var preDelay: Double = 0 // seconds before speaking
    var postDelay: Double = 0.5 // seconds after speaking before song starts
}

// MARK: - Voice Type (iOS TTS vs ElevenLabs)
enum VoiceType: String, Codable {
    case system = "system"     // iOS AVSpeechSynthesizer
    case elevenLabs = "elevenLabs"
}

// MARK: - Voice Model (reusable announcer voice configuration)
struct Voice: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String // User-friendly name like "Stadium Announcer", "Casual Voice"
    var voiceType: VoiceType = .elevenLabs // ElevenLabs is PRIMARY, iOS is fallback
    var voiceIdentifier: String? = nil // iOS voice ID or ElevenLabs voice ID
    var rate: Float = 0.5  // 0.0-1.0 (only for system voices)
    var pitch: Float = 1.0 // 0.5-2.0 (only for system voices)
    var volume: Float = 1.0 // 0.0-1.0
    var preDelay: Double = 0 // seconds before speaking
    var postDelay: Double = 0.5 // seconds after speaking
    
    init(name: String, voiceType: VoiceType = .elevenLabs, voiceIdentifier: String? = nil, rate: Float = 0.5, pitch: Float = 1.0, volume: Float = 1.0, preDelay: Double = 0, postDelay: Double = 0.5) {
        self.name = name
        self.voiceType = voiceType
        self.voiceIdentifier = voiceIdentifier
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
        self.preDelay = preDelay
        self.postDelay = postDelay
    }
    
    var isElevenLabs: Bool {
        voiceType == .elevenLabs
    }
    
    // Convert to VoiceOverSettings for use with a specific announcement text
    func toVoiceOverSettings(text: String) -> VoiceOverSettings {
        return VoiceOverSettings(
            enabled: true,
            text: text,
            voiceType: voiceType,
            voiceIdentifier: voiceIdentifier,
            rate: rate,
            pitch: pitch,
            volume: volume,
            preDelay: preDelay,
            postDelay: postDelay
        )
    }
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
    var eventID: UUID?
    var fadeOutEnabled: Bool
    var fadeOutDuration: Double
    var voiceOver: VoiceOverSettings?
    var isVoiceOnly: Bool
    var isLineupAnnouncement: Bool
    
    init(name: String, songPersistentID: UInt64 = 0, spotifyURI: String? = nil, musicSource: MusicSource = .appleMusic, startTimeSeconds: Double = 0, categoryTags: [String] = [], colorHex: String = "#007AFF", order: Int = 0, eventID: UUID? = nil, fadeOutEnabled: Bool = false, fadeOutDuration: Double = 2.0, voiceOver: VoiceOverSettings? = nil, isVoiceOnly: Bool = false, isLineupAnnouncement: Bool = false) {
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
        self.isLineupAnnouncement = isLineupAnnouncement
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
    var voiceID: UUID? // Reference to Voice object assigned to this lineup
    
    // Legacy support for migration
    var defaultVoiceSettings: VoiceOverSettings? {
        get { nil }
        set { } // Ignored - use voiceID instead
    }
    
    init(name: String, date: Date? = nil, colorHex: String = "#007AFF", iconName: String = "star.fill", order: Int = 0, voiceID: UUID? = nil) {
        self.name = name
        self.date = date
        self.colorHex = colorHex
        self.iconName = iconName
        self.order = order
        self.voiceID = voiceID
    }
    
    // Custom coding keys to handle migration from defaultVoiceSettings
    enum CodingKeys: String, CodingKey {
        case id, name, date, colorHex, iconName, order, voiceID
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
    var announcementSoundID: UUID?
    var songPersistentID: UInt64?
    var spotifyURI: String?
    var musicSource: MusicSource?
    var songStartTimeSeconds: Double = 0
    
    init(name: String, number: Int, position: String? = nil, lineupOrder: Int = 0, teamEventID: UUID, announcementSoundID: UUID? = nil, songPersistentID: UInt64? = nil, spotifyURI: String? = nil, musicSource: MusicSource? = nil, songStartTimeSeconds: Double = 0) {
        self.name = name
        self.number = number
        self.position = position
        self.lineupOrder = lineupOrder
        self.teamEventID = teamEventID
        self.announcementSoundID = announcementSoundID
        self.songPersistentID = songPersistentID
        self.spotifyURI = spotifyURI
        self.musicSource = musicSource
        self.songStartTimeSeconds = songStartTimeSeconds
    }
    
    var hasSong: Bool {
        (songPersistentID != nil && songPersistentID != 0) || (spotifyURI != nil && !spotifyURI!.isEmpty)
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
