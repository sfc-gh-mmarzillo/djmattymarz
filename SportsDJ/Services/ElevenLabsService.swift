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
        ElevenLabsVoice(id: "pNInz6obpgDQGcFmaJgB", name: "Adam", description: "Deep, professional male voice - great for announcements"),
        ElevenLabsVoice(id: "ErXwobaYiN019PkySvjV", name: "Antoni", description: "Well-rounded male voice"),
        ElevenLabsVoice(id: "VR6AewLTigWG4xSOukaG", name: "Arnold", description: "Deep, powerful male voice"),
        ElevenLabsVoice(id: "yoZ06aMxZJJ28mfd3POQ", name: "Sam", description: "Young, dynamic male voice"),
        ElevenLabsVoice(id: "TxGEqnHWrfWFTfGW9XjX", name: "Josh", description: "Deep, authoritative male voice - ideal for sports"),
        ElevenLabsVoice(id: "ODq5zmih8GrVes37Dizd", name: "Patrick", description: "Booming announcer voice"),
        ElevenLabsVoice(id: "nPczCjzI2devNBz1zQrb", name: "Brian", description: "Deep American male voice"),
        ElevenLabsVoice(id: "N2lVS1w4EtoT3dr4eOWO", name: "Callum", description: "Transatlantic male voice")
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
        let combined = "\(text)_\(voiceId)"
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
        print("[ElevenLabs] generateSpeech called - text: '\(text.prefix(30))...', voiceId: \(voiceId)")
        
        if let cachedURL = getCachedAudioURL(text: text, voiceId: voiceId) {
            print("[ElevenLabs] Found cached audio at: \(cachedURL)")
            completion(.success(cachedURL))
            return
        }
        
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
        
        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.75,
                "similarity_boost": 0.85,
                "style": 0.5,
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
    
    func previewVoice(voiceId: String, text: String = "Now batting, number 7, Center Field, Mickey Mantle") {
        generateSpeech(text: text, voiceId: voiceId) { [weak self] result in
            switch result {
            case .success(let url):
                self?.playAudio(url: url)
            case .failure(let error):
                print("ElevenLabs preview error: \(error)")
            }
        }
    }
    
    private func playAudio(url: URL) {
        do {
            print("[ElevenLabs] playAudio called with URL: \(url)")
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 1.0
            let success = audioPlayer?.play() ?? false
            print("[ElevenLabs] Audio playback started: \(success), duration: \(audioPlayer?.duration ?? 0)s")
        } catch {
            print("[ElevenLabs] ERROR: Audio playback error - \(error)")
        }
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
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
