import Foundation
import AVFoundation

class ElevenLabsService: ObservableObject {
    static let shared = ElevenLabsService()
    
    @Published var isConfigured: Bool = true
    @Published var isGenerating: Bool = false
    @Published var monthlyUsage: Int = 0
    @Published var availableVoices: [ElevenLabsVoice] = []
    
    private let maxMonthlyGenerations = 10000
    private let fileManager = FileManager.default
    private var audioPlayer: AVAudioPlayer?
    
    private let universalAPIKey = "sk_47a2505eb66c606b3b5f27deb6ebc7851d43cce2ce4eba20"
    
    private let defaultVoices: [ElevenLabsVoice] = [
        ElevenLabsVoice(id: "pNInz6obpgDQGcFmaJgB", name: "Adam", description: "Deep, professional - classic stadium announcer"),
        ElevenLabsVoice(id: "TxGEqnHWrfWFTfGW9XjX", name: "Josh", description: "Authoritative - ideal for sports announcing"),
        ElevenLabsVoice(id: "ODq5zmih8GrVes37Dizd", name: "Patrick", description: "Booming voice - big arena energy"),
        ElevenLabsVoice(id: "VR6AewLTigWG4xSOukaG", name: "Arnold", description: "Powerful & commanding presence"),
        ElevenLabsVoice(id: "nPczCjzI2devNBz1zQrb", name: "Brian", description: "Deep American - broadcast style"),
        ElevenLabsVoice(id: "N2lVS1w4EtoT3dr4eOWO", name: "Callum", description: "Transatlantic - premium sports feel"),
        ElevenLabsVoice(id: "ErXwobaYiN019PkySvjV", name: "Antoni", description: "Well-rounded - versatile announcer"),
        ElevenLabsVoice(id: "yoZ06aMxZJJ28mfd3POQ", name: "Sam", description: "Young & dynamic energy")
    ]
    
    private var apiKey: String {
        return universalAPIKey
    }
    
    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("ElevenLabsCache")
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        return cacheDir
    }
    
    private var usageKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return "elevenlabs_usage_\(formatter.string(from: Date()))"
    }
    
    init() {
        isConfigured = true
        loadMonthlyUsage()
        availableVoices = defaultVoices
        fetchVoices()
    }
    
    var canGenerate: Bool {
        return isConfigured && monthlyUsage < maxMonthlyGenerations
    }
    
    var remainingGenerations: Int {
        return max(0, maxMonthlyGenerations - monthlyUsage)
    }
    
    private func loadMonthlyUsage() {
        monthlyUsage = UserDefaults.standard.integer(forKey: usageKey)
    }
    
    private func incrementUsage() {
        monthlyUsage += 1
        UserDefaults.standard.set(monthlyUsage, forKey: usageKey)
    }
    
    func getCacheKey(text: String, voiceId: String) -> String {
        // v2 cache key - invalidates old rushed audio
        let combined = "v2_\(text)_\(voiceId)"
        let data = Data(combined.utf8)
        return data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .prefix(50) + ".mp3"
    }
    
    func getCachedAudioURL(text: String, voiceId: String) -> URL? {
        let filename = getCacheKey(text: text, voiceId: voiceId)
        let fileURL = cacheDirectory.appendingPathComponent(String(filename))
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }
    
    func generateSpeech(text: String, voiceId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // Find voice name for logging
        let voiceName = defaultVoices.first { $0.id == voiceId }?.name ?? "Unknown"
        print("[ElevenLabs] === GENERATE SPEECH ===")
        print("[ElevenLabs] Voice: \(voiceName) (ID: \(voiceId))")
        print("[ElevenLabs] Text: '\(text.prefix(50))...'")
        print("[ElevenLabs] Cache key: \(getCacheKey(text: text, voiceId: voiceId))")
        
        if let cachedURL = getCachedAudioURL(text: text, voiceId: voiceId) {
            print("[ElevenLabs] CACHE HIT: \(cachedURL.lastPathComponent)")
            completion(.success(cachedURL))
            return
        }
        
        print("[ElevenLabs] CACHE MISS - Making API request...")
        
        let key = apiKey
        print("[ElevenLabs] API key present: \(!key.isEmpty), canGenerate: \(canGenerate)")
        
        guard canGenerate else {
            print("[ElevenLabs] ERROR: Usage limit reached")
            completion(.failure(ElevenLabsError.usageLimitReached))
            return
        }
        
        isGenerating = true
        print("[ElevenLabs] Making API request...")
        
        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(key, forHTTPHeaderField: "xi-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("audio/mpeg", forHTTPHeaderField: "Accept")
        
        // Format text for stadium announcer style - add pauses for dramatic effect
        let announcerText = formatForAnnouncer(text)
        
        let body: [String: Any] = [
            "text": announcerText,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": [
                "stability": 0.85,
                "similarity_boost": 0.90,
                "style": 0.65,
                "use_speaker_boost": true
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isGenerating = false
                
                if let error = error {
                    print("[ElevenLabs] ERROR: Network error - \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[ElevenLabs] ERROR: Invalid response type")
                    completion(.failure(ElevenLabsError.invalidResponse))
                    return
                }
                
                print("[ElevenLabs] Response status: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    if httpResponse.statusCode == 401 {
                        print("[ElevenLabs] ERROR: Invalid API key")
                        completion(.failure(ElevenLabsError.invalidAPIKey))
                    } else if httpResponse.statusCode == 429 {
                        print("[ElevenLabs] ERROR: Rate limited")
                        completion(.failure(ElevenLabsError.rateLimited))
                    } else {
                        print("[ElevenLabs] ERROR: API error \(httpResponse.statusCode)")
                        if let data = data, let errorStr = String(data: data, encoding: .utf8) {
                            print("[ElevenLabs] Error body: \(errorStr)")
                        }
                        completion(.failure(ElevenLabsError.apiError(httpResponse.statusCode)))
                    }
                    return
                }
                
                guard let audioData = data else {
                    print("[ElevenLabs] ERROR: No audio data")
                    completion(.failure(ElevenLabsError.noData))
                    return
                }
                
                print("[ElevenLabs] SUCCESS: Received \(audioData.count) bytes of audio")
                
                let filename = self?.getCacheKey(text: text, voiceId: voiceId) ?? "temp.mp3"
                let fileURL = self?.cacheDirectory.appendingPathComponent(String(filename)) ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
                
                do {
                    try audioData.write(to: fileURL)
                    print("[ElevenLabs] Saved audio to: \(fileURL)")
                    self?.incrementUsage()
                    completion(.success(fileURL))
                } catch {
                    print("[ElevenLabs] ERROR: Failed to save audio - \(error)")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // Format text with pauses for dramatic stadium announcer effect
    private func formatForAnnouncer(_ text: String) -> String {
        var result = text
        
        // Add dramatic pauses after "Now batting" or "Now on deck"
        result = result.replacingOccurrences(of: "Now batting,", with: "Now batting...")
        result = result.replacingOccurrences(of: "Now on deck,", with: "Now on deck...")
        
        // Add pause after jersey number
        let numberPattern = try? NSRegularExpression(pattern: "(number \\d+),", options: .caseInsensitive)
        if let pattern = numberPattern {
            result = pattern.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "$1...")
        }
        
        // Add pause before player name (after position)
        let positions = ["Pitcher", "Catcher", "First Base", "Second Base", "Third Base", "Shortstop", 
                        "Left Field", "Center Field", "Right Field", "Designated Hitter", "DH"]
        for position in positions {
            result = result.replacingOccurrences(of: "\(position),", with: "\(position)...")
        }
        
        return result
    }
    
    func previewVoice(voiceId: String, text: String = "Now batting... number 14... First Base... Paul Konerko!") {
        // CRITICAL: Stop any currently playing audio first
        stopAudio()
        
        print("[ElevenLabs] previewVoice called - voiceId: \(voiceId)")
        
        generateSpeech(text: text, voiceId: voiceId) { [weak self] result in
            switch result {
            case .success(let url):
                print("[ElevenLabs] Preview audio ready, playing from: \(url)")
                self?.playAudio(url: url)
            case .failure(let error):
                print("[ElevenLabs] Preview error: \(error)")
            }
        }
    }
    
    private func playAudio(url: URL) {
        // Stop any existing playback
        audioPlayer?.stop()
        audioPlayer = nil
        
        do {
            print("[ElevenLabs] playAudio - URL: \(url)")
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            let success = audioPlayer?.play() ?? false
            print("[ElevenLabs] Playback started: \(success), duration: \(audioPlayer?.duration ?? 0)s")
        } catch {
            print("[ElevenLabs] ERROR: Playback failed - \(error)")
        }
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // Pre-cache audio in background (doesn't play, just generates and caches)
    func precacheAudio(text: String, voiceId: String) {
        // Check if already cached
        if getCachedAudioURL(text: text, voiceId: voiceId) != nil {
            print("[ElevenLabs] Precache: Already cached - '\(text.prefix(30))...'")
            return
        }
        
        print("[ElevenLabs] Precache: Generating audio for '\(text.prefix(30))...'")
        
        generateSpeech(text: text, voiceId: voiceId) { result in
            switch result {
            case .success(let url):
                print("[ElevenLabs] Precache: SUCCESS - cached at \(url.lastPathComponent)")
            case .failure(let error):
                print("[ElevenLabs] Precache: FAILED - \(error.localizedDescription)")
            }
        }
    }
    
    // Pre-cache multiple announcements in background
    func precachePlayerAnnouncements(players: [(text: String, voiceId: String)]) {
        print("[ElevenLabs] Precache: Starting batch precache for \(players.count) players")
        
        for (index, player) in players.enumerated() {
            // Stagger requests slightly to avoid rate limiting
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                self.precacheAudio(text: player.text, voiceId: player.voiceId)
            }
        }
    }
    
    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getCacheSize() -> String {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 KB"
        }
        
        var totalSize: Int64 = 0
        for file in files {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        
        if totalSize < 1024 {
            return "\(totalSize) B"
        } else if totalSize < 1024 * 1024 {
            return "\(totalSize / 1024) KB"
        } else {
            return String(format: "%.1f MB", Double(totalSize) / 1024 / 1024)
        }
    }
    
    private func fetchVoices() {
        let key = apiKey
        
        let url = URL(string: "https://api.elevenlabs.io/v1/voices")!
        var request = URLRequest(url: url)
        request.addValue(key, forHTTPHeaderField: "xi-api-key")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let voices = json["voices"] as? [[String: Any]] else {
                return
            }
            
            let fetchedVoices = voices.compactMap { voice -> ElevenLabsVoice? in
                guard let id = voice["voice_id"] as? String,
                      let name = voice["name"] as? String else {
                    return nil
                }
                let description = (voice["labels"] as? [String: String])?["description"] ?? ""
                return ElevenLabsVoice(id: id, name: name, description: description)
            }
            
            DispatchQueue.main.async {
                if !fetchedVoices.isEmpty {
                    self?.availableVoices = fetchedVoices
                }
            }
        }.resume()
    }
}

struct ElevenLabsVoice: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
}

enum ElevenLabsError: LocalizedError {
    case notConfigured
    case usageLimitReached
    case invalidAPIKey
    case rateLimited
    case invalidResponse
    case noData
    case apiError(Int)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ElevenLabs API key not configured"
        case .usageLimitReached:
            return "Monthly generation limit reached (100/month)"
        case .invalidAPIKey:
            return "Invalid API key"
        case .rateLimited:
            return "Rate limited - please wait"
        case .invalidResponse:
            return "Invalid response from server"
        case .noData:
            return "No audio data received"
        case .apiError(let code):
            return "API error (code \(code))"
        }
    }
}
