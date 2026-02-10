import Foundation
import MediaPlayer

// MARK: - Music Source Enum
enum MusicSource: String, Codable {
    case appleMusic = "appleMusic"
    case spotify = "spotify"
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
    
    init(name: String, songPersistentID: UInt64, spotifyURI: String? = nil, musicSource: MusicSource = .appleMusic, startTimeSeconds: Double = 0, categoryTags: [String] = [], colorHex: String = "#007AFF", order: Int = 0, eventID: UUID? = nil) {
        self.name = name
        self.songPersistentID = songPersistentID
        self.spotifyURI = spotifyURI
        self.musicSource = musicSource
        self.startTimeSeconds = startTimeSeconds
        self.categoryTags = categoryTags
        self.colorHex = colorHex
        self.order = order
        self.eventID = eventID
    }
}

// MARK: - Event Model
struct Event: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var date: Date
    var colorHex: String
    var iconName: String
    
    init(name: String, date: Date = Date(), colorHex: String = "#007AFF", iconName: String = "star.fill") {
        self.name = name
        self.date = date
        self.colorHex = colorHex
        self.iconName = iconName
    }
}

// MARK: - Category Model
struct Category: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var eventID: UUID? // nil means global category (available in all events)
    var iconName: String
    
    init(name: String, colorHex: String = "#007AFF", eventID: UUID? = nil, iconName: String = "tag.fill") {
        self.name = name
        self.colorHex = colorHex
        self.eventID = eventID
        self.iconName = iconName
    }
    
    var isGlobal: Bool {
        eventID == nil
    }
}
