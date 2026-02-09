import Foundation
import MediaPlayer

struct SoundButton: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var songPersistentID: UInt64
    var startTimeSeconds: Double
    var categoryTags: [String]
    var colorHex: String
    var order: Int
    
    init(name: String, songPersistentID: UInt64, startTimeSeconds: Double = 0, categoryTags: [String] = [], colorHex: String = "#007AFF", order: Int = 0) {
        self.name = name
        self.songPersistentID = songPersistentID
        self.startTimeSeconds = startTimeSeconds
        self.categoryTags = categoryTags
        self.colorHex = colorHex
        self.order = order
    }
}

struct Category: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    
    init(name: String, colorHex: String = "#007AFF") {
        self.name = name
        self.colorHex = colorHex
    }
}
