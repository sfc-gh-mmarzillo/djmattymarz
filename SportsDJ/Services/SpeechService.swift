import Foundation
import AVFoundation

class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()
    
    @Published var isSpeaking: Bool = false
    @Published var availableVoices: [AVSpeechSynthesisVoice] = []
    
    private let synthesizer = AVSpeechSynthesizer()
    private var completionHandler: (() -> Void)?
    
    // Preferred announcer-style voices (in order of preference)
    // These are enhanced/premium US English voices that sound more natural
    private let preferredAnnouncerVoices = [
        "com.apple.voice.enhanced.en-US.Evan",      // Natural male announcer voice
        "com.apple.voice.enhanced.en-US.Aaron",     // Professional male voice
        "com.apple.voice.premium.en-US.Evan",       // Premium version
        "com.apple.voice.premium.en-US.Aaron",      // Premium version
        "com.apple.voice.enhanced.en-US.Nicky",     // Clear male voice
        "com.apple.voice.enhanced.en-US.Tom",       // Deep male voice
        "com.apple.ttsbundle.siri_male_en-US_compact" // Siri male voice
    ]
    
    // Cache the best available announcer voice
    private(set) var defaultAnnouncerVoice: AVSpeechSynthesisVoice?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        loadAvailableVoices()
        findBestAnnouncerVoice()
    }
    
    // MARK: - Available Voices
    
    private func loadAvailableVoices() {
        // Get all available voices, prioritizing English
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Sort: English first, then by quality (enhanced/premium first)
        availableVoices = allVoices
            .filter { $0.language.starts(with: "en") }
            .sorted { v1, v2 in
                // Prefer enhanced voices
                if v1.quality != v2.quality {
                    return v1.quality.rawValue > v2.quality.rawValue
                }
                return v1.name < v2.name
            }
    }
    
    private func findBestAnnouncerVoice() {
        // Try to find the best announcer voice from our preferred list
        for voiceId in preferredAnnouncerVoices {
            if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
                defaultAnnouncerVoice = voice
                return
            }
        }
        
        // Fallback: find any enhanced US English male voice
        let enhancedVoices = availableVoices.filter { 
            $0.quality == .enhanced && $0.language == "en-US" 
        }
        if let enhanced = enhancedVoices.first {
            defaultAnnouncerVoice = enhanced
            return
        }
        
        // Last resort: default US English voice
        defaultAnnouncerVoice = AVSpeechSynthesisVoice(language: "en-US")
    }
    
    func getVoice(identifier: String?) -> AVSpeechSynthesisVoice? {
        guard let id = identifier else {
            // Return best available announcer voice
            return defaultAnnouncerVoice ?? AVSpeechSynthesisVoice(language: "en-US")
        }
        return AVSpeechSynthesisVoice(identifier: id)
    }
    
    func getVoiceName(identifier: String?) -> String {
        guard let id = identifier,
              let voice = AVSpeechSynthesisVoice(identifier: id) else {
            return defaultAnnouncerVoice?.name ?? "Default"
        }
        return voice.name
    }
    
    // MARK: - Speaking
    
    func speak(settings: VoiceOverSettings, completion: (() -> Void)? = nil) {
        guard settings.enabled, !settings.text.isEmpty else {
            completion?()
            return
        }
        
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        completionHandler = completion
        
        // Apply pre-delay if set
        if settings.preDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.preDelay) { [weak self] in
                self?.performSpeak(settings: settings)
            }
        } else {
            performSpeak(settings: settings)
        }
    }
    
    private func performSpeak(settings: VoiceOverSettings) {
        let utterance = AVSpeechUtterance(string: settings.text)
        
        // Apply voice settings
        if let voiceId = settings.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            // Use best available announcer voice
            utterance.voice = defaultAnnouncerVoice ?? AVSpeechSynthesisVoice(language: "en-US")
        }
        
        // Rate: AVSpeechUtterance uses 0.0-1.0, but actual range is more like 0.0-0.75 for usable speech
        // Map our 0.0-1.0 to a reasonable range
        utterance.rate = mapRate(settings.rate)
        
        // Pitch: 0.5-2.0
        utterance.pitchMultiplier = settings.pitch
        
        // Volume: 0.0-1.0
        utterance.volume = settings.volume
        
        // Post delay handled in delegate callback
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    // Map our 0-1 rate to AVSpeechUtterance's usable range
    private func mapRate(_ rate: Float) -> Float {
        // AVSpeechUtterance rate ranges from AVSpeechUtteranceMinimumSpeechRate to AVSpeechUtteranceMaximumSpeechRate
        // But the middle values sound best. Map 0-1 to 0.3-0.6 range
        let minRate: Float = AVSpeechUtteranceMinimumSpeechRate // ~0.0
        let maxRate: Float = AVSpeechUtteranceMaximumSpeechRate // ~1.0
        let defaultRate: Float = AVSpeechUtteranceDefaultSpeechRate // ~0.5
        
        // Use a comfortable range around default
        let usableMin: Float = 0.35
        let usableMax: Float = 0.65
        
        return usableMin + (rate * (usableMax - usableMin))
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        completionHandler = nil
    }
    
    // MARK: - Preview
    
    func previewVoice(text: String, settings: VoiceOverSettings) {
        var previewSettings = settings
        previewSettings.text = text
        previewSettings.enabled = true
        previewSettings.preDelay = 0
        previewSettings.postDelay = 0
        speak(settings: previewSettings, completion: nil)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            
            // Call completion handler (post-delay handled by caller if needed)
            self?.completionHandler?()
            self?.completionHandler = nil
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.completionHandler = nil
        }
    }
}

// MARK: - Voice Info Helper

struct VoiceInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let language: String
    let quality: AVSpeechSynthesisVoiceQuality
    
    init(voice: AVSpeechSynthesisVoice) {
        self.id = voice.identifier
        self.name = voice.name
        self.language = voice.language
        self.quality = voice.quality
    }
    
    var qualityLabel: String {
        switch quality {
        case .enhanced:
            return "Enhanced"
        case .premium:
            return "Premium"
        default:
            return "Standard"
        }
    }
    
    var displayName: String {
        "\(name) (\(qualityLabel))"
    }
}
