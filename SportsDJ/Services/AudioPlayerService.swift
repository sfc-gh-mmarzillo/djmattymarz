import Foundation
import AVFoundation
import CoreMedia
import MediaPlayer
import Combine

class AudioPlayerService: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentButtonID: UUID?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var nowPlayingTitle: String = ""
    @Published var isPreviewing: Bool = false
    @Published var currentArtwork: UIImage?
    @Published var isLoading: Bool = false
    @Published var currentMusicSource: MusicSource = .appleMusic
    @Published var isFadingOut: Bool = false
    @Published var isSpeakingVoiceOver: Bool = false
    
    private let musicPlayer = MPMusicPlayerController.applicationMusicPlayer
    private let spotifyService = SpotifyService.shared
    private let speechService = SpeechService.shared
    private let elevenLabsService = ElevenLabsService.shared
    private var elevenLabsPlayer: AVAudioPlayer?
    private var crossfadeMusicPlayer: AVAudioPlayer?  // For lineup crossfade only
    private var musicFadeTimer: Timer?
    private var timer: Timer?
    private var fadeTimer: Timer?
    private var targetStartTime: Double = 0
    private var hasSetStartTime: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    // Reference to data store for dynamic voice lookup
    weak var dataStore: DataStore?
    
    // Fade out properties
    private var currentButton: SoundButton?
    private var initialVolume: Float = 1.0  // Volume when song started
    private var fadeStartVolume: Float = 1.0
    
    // Pending next button (for smooth transitions)
    private var pendingButton: SoundButton?
    
    // Volume control - must be retained and added to view hierarchy
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    
    init() {
        setupAudioSession()
        setupNotifications()
        setupSpotifyObservers()
        setupVolumeControl()
    }
    
    private func setupVolumeControl() {
        // Create an MPVolumeView and find its slider
        // This needs to be attached to the view hierarchy to work
        DispatchQueue.main.async { [weak self] in
            let volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 0, height: 0))
            volumeView.isHidden = true
            
            // Add to key window
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(volumeView)
            }
            
            // Find the volume slider
            for subview in volumeView.subviews {
                if let slider = subview as? UISlider {
                    self?.volumeSlider = slider
                    break
                }
            }
            
            self?.volumeView = volumeView
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateDidChange),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )
        musicPlayer.beginGeneratingPlaybackNotifications()
    }
    
    private func setupSpotifyObservers() {
        // Observe Spotify playback state
        spotifyService.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                guard let self = self, self.currentMusicSource == .spotify else { return }
                self.isPlaying = playing
            }
            .store(in: &cancellables)
        
        spotifyService.$playbackPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] position in
                guard let self = self, self.currentMusicSource == .spotify else { return }
                self.currentTime = position
            }
            .store(in: &cancellables)
        
        spotifyService.$currentArtwork
            .receive(on: DispatchQueue.main)
            .sink { [weak self] artwork in
                guard let self = self, self.currentMusicSource == .spotify else { return }
                self.currentArtwork = artwork
            }
            .store(in: &cancellables)
    }
    
    @objc private func playbackStateDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.currentMusicSource == .appleMusic else { return }
            
            let state = self.musicPlayer.playbackState
            self.isPlaying = (state == .playing)
            
            // Set start time after playback begins
            if state == .playing && !self.hasSetStartTime && self.targetStartTime > 0 {
                self.musicPlayer.currentPlaybackTime = self.targetStartTime
                self.hasSetStartTime = true
            }
            
            if state == .stopped || state == .paused {
                if !self.isPreviewing {
                    // Don't clear everything on pause
                }
            }
        }
    }
    
    // MARK: - Play Button (Auto-detects source)
    
    func play(button: SoundButton) {
        // If currently playing a song with fade out enabled, fade it out first then play new song
        if let current = currentButton, current.fadeOutEnabled, isPlaying, !isFadingOut {
            pendingButton = button
            fadeOutAndStop(duration: current.fadeOutDuration)
            return
        }
        
        // If already fading, queue this button
        if isFadingOut {
            pendingButton = button
            return
        }
        
        stopImmediately()
        
        // Capture the initial system volume before playing
        captureInitialVolume()
        
        currentButton = button
        currentButtonID = button.id
        nowPlayingTitle = button.name
        currentMusicSource = button.musicSource
        
        // For any button with voice, ALWAYS fetch the live team voice settings
        // This ensures all batters in a lineup use the same team voice
        if let voiceOver = button.voiceOver, voiceOver.enabled {
            let liveVoiceSettings = getLiveVoiceSettings(for: button, baseSettings: voiceOver)
            
            // Voice-only button (lineup announcement without song)
            if button.isVoiceOnly && !button.isLineupAnnouncement {
                playVoiceOnly(button: button, voiceOver: liveVoiceSettings)
                return
            }
            
            // Lineup announcement with song (overlapping playback with crossfade)
            if button.isLineupAnnouncement {
                playLineupAnnouncement(button: button, voiceOver: liveVoiceSettings)
                return
            }
            
            // Regular voice over followed by music (sequential)
            if !voiceOver.text.isEmpty {
                playWithVoiceOver(button: button, voiceOver: liveVoiceSettings)
                return
            }
        }
        
        // No voice over, play directly
        playMusic(button: button)
    }
    
    private func captureInitialVolume() {
        let audioSession = AVAudioSession.sharedInstance()
        initialVolume = audioSession.outputVolume
        print("Initial volume captured: \(initialVolume)")
    }
    
    // MARK: - Dynamic Voice Lookup
    
    /// Fetches the current team voice settings at playback time
    /// This ensures players always use the team's assigned voice, even if changed after player creation
    private func getLiveVoiceSettings(for button: SoundButton, baseSettings: VoiceOverSettings) -> VoiceOverSettings {
        // If no data store reference or no event ID, use stored settings
        guard let dataStore = dataStore,
              let eventID = button.eventID,
              let teamVoice = dataStore.voiceForTeam(eventID) else {
            print("[AudioPlayer] Using stored voice settings (no team voice found)")
            return baseSettings
        }
        
        // Build new voice settings from team's current voice
        var liveSettings = teamVoice.toVoiceOverSettings(text: baseSettings.text)
        liveSettings.enabled = baseSettings.enabled
        liveSettings.preDelay = baseSettings.preDelay
        liveSettings.postDelay = baseSettings.postDelay
        
        print("[AudioPlayer] Using live team voice: \(teamVoice.name), type: \(liveSettings.voiceType), id: \(liveSettings.voiceIdentifier ?? "nil")")
        return liveSettings
    }
    
    // MARK: - Voice Only Playback (for lineup announcements without song)
    
    private func playVoiceOnly(button: SoundButton, voiceOver: VoiceOverSettings) {
        isSpeakingVoiceOver = true
        isPlaying = true
        
        speakWithBestVoice(text: voiceOver.text, settings: voiceOver) { [weak self] in
            DispatchQueue.main.async {
                self?.isSpeakingVoiceOver = false
                self?.isPlaying = false
                self?.currentButtonID = nil
                self?.nowPlayingTitle = ""
            }
        }
    }
    
    // MARK: - Lineup Announcement Playback (voice + song with professional crossfade)
    
    /// Professional stadium-style crossfade:
    /// 1. Voice plays at full volume through AVAudioPlayer
    /// 2. Music starts ~1s in at LOW volume (ducked under voice)
    /// 3. Music gradually rises as voice continues
    /// 4. By end of announcement, music is at full volume
    /// Key: Voice and music use SEPARATE audio players with independent volume control
    private func playLineupAnnouncement(button: SoundButton, voiceOver: VoiceOverSettings) {
        isSpeakingVoiceOver = true
        isPlaying = true
        
        print("[AudioPlayer] === LINEUP ANNOUNCEMENT START ===")
        print("[AudioPlayer] Voice type: \(voiceOver.voiceType), identifier: \(voiceOver.voiceIdentifier ?? "nil")")
        print("[AudioPlayer] Text: \(voiceOver.text)")
        
        let isElevenLabs = voiceOver.voiceType == .elevenLabs && voiceOver.voiceIdentifier != nil
        
        if isElevenLabs {
            playElevenLabsWithMusicCrossfade(button: button, voiceOver: voiceOver)
        } else {
            // iOS TTS: Use system TTS with MPMusicPlayerController
            // TTS uses speech synthesizer, music uses media player - they don't conflict
            speakWithBestVoice(text: voiceOver.text, settings: voiceOver, completion: nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.playMusicForLineupWithDucking(button: button)
            }
        }
    }
    
    /// ElevenLabs crossfade: Both voice and music through AVAudioPlayer for true independent volume
    private func playElevenLabsWithMusicCrossfade(button: SoundButton, voiceOver: VoiceOverSettings) {
        guard let voiceId = voiceOver.voiceIdentifier else {
            print("[AudioPlayer] ERROR: No voice ID for ElevenLabs")
            return
        }
        
        print("[AudioPlayer] Loading ElevenLabs audio...")
        
        elevenLabsService.generateSpeech(text: voiceOver.text, voiceId: voiceId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let audioURL):
                    print("[AudioPlayer] ElevenLabs audio ready: \(audioURL)")
                    
                    // Get voice duration for adaptive timing
                    let voiceDuration = self.getAudioDuration(url: audioURL) ?? 4.0
                    print("[AudioPlayer] Voice duration: \(voiceDuration)s")
                    
                    // Start voice at full volume
                    self.playElevenLabsAudioForCrossfade(url: audioURL)
                    
                    // Start music shortly after "Now batting..." (~1.0s into announcement)
                    // Music starts ducked, rises over the remaining announcement
                    let musicStartDelay = min(1.0, voiceDuration * 0.25)
                    let fadeInDuration = max(2.0, voiceDuration - musicStartDelay)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + musicStartDelay) {
                        print("[AudioPlayer] === STARTING DUCKED MUSIC ===")
                        self.playMusicForLineupWithDucking(button: button, fadeInDuration: fadeInDuration)
                    }
                    
                case .failure(let error):
                    print("[AudioPlayer] ElevenLabs FAILED: \(error), falling back to iOS")
                    let settings = VoiceOverSettings(enabled: true, text: voiceOver.text)
                    self.speechService.speak(settings: settings, completion: nil)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.playMusicForLineupWithDucking(button: button)
                    }
                }
            }
        }
    }
    
    /// Get audio file duration
    private func getAudioDuration(url: URL) -> Double? {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
    
    /// Play ElevenLabs voice audio at full volume
    private func playElevenLabsAudioForCrossfade(url: URL) {
        do {
            elevenLabsPlayer = try AVAudioPlayer(contentsOf: url)
            elevenLabsPlayer?.volume = 1.0
            elevenLabsPlayer?.prepareToPlay()
            let success = elevenLabsPlayer?.play() ?? false
            print("[AudioPlayer] Voice playback started: \(success), duration: \(elevenLabsPlayer?.duration ?? 0)s")
        } catch {
            print("[AudioPlayer] ERROR playing voice: \(error)")
        }
    }
    
    /// Play music with professional ducking - starts quiet, rises smoothly
    /// Uses MPMusicPlayerController but with carefully timed volume changes
    private func playMusicForLineupWithDucking(button: SoundButton, fadeInDuration: Double = 3.0) {
        switch button.musicSource {
        case .appleMusic:
            playAppleMusicWithDucking(button: button, fadeInDuration: fadeInDuration)
        case .spotify:
            playSpotify(button: button)
        }
    }
    
    /// Apple Music with smooth ducking fade-in
    /// Music starts at 15% volume and rises to 100% over fadeInDuration
    private func playAppleMusicWithDucking(button: SoundButton, fadeInDuration: Double) {
        guard let song = fetchSong(persistentID: button.songPersistentID) else {
            print("[AudioPlayer] ERROR: Could not find song")
            return
        }
        
        print("[AudioPlayer] Found song: \(song.title ?? "Unknown")")
        currentArtwork = song.artwork?.image(at: CGSize(width: 100, height: 100))
        
        let collection = MPMediaItemCollection(items: [song])
        musicPlayer.setQueue(with: collection)
        
        targetStartTime = button.startTimeSeconds
        hasSetStartTime = false
        
        // Capture current volume, then set initial ducked volume
        let audioSession = AVAudioSession.sharedInstance()
        let targetVolume = audioSession.outputVolume
        let startVolume: Float = targetVolume * 0.15  // Start at 15% of user's volume
        
        print("[AudioPlayer] Ducking: start=\(startVolume), target=\(targetVolume), duration=\(fadeInDuration)s")
        
        // Set initial low volume
        setSystemVolume(startVolume)
        
        musicPlayer.prepareToPlay { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("[AudioPlayer] ERROR preparing: \(error)")
                    self.setSystemVolume(targetVolume)
                    return
                }
                
                self.musicPlayer.currentPlaybackTime = button.startTimeSeconds
                self.hasSetStartTime = true
                self.musicPlayer.play()
                
                print("[AudioPlayer] Music playing at \(button.startTimeSeconds)s")
                
                self.duration = song.playbackDuration
                self.startTimer()
                
                // Smooth fade from ducked to full volume
                self.fadeInMusicSmooth(from: startVolume, to: targetVolume, duration: fadeInDuration)
            }
        }
    }
    
    /// Ultra-smooth volume fade using high-frequency timer and easing curve
    private func fadeInMusicSmooth(from startVolume: Float, to targetVolume: Float, duration: Double) {
        musicFadeTimer?.invalidate()
        
        let startTime = CACurrentMediaTime()
        let volumeRange = targetVolume - startVolume
        
        // 60fps for buttery smooth fade
        musicFadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(1.0, elapsed / duration)
            
            // S-curve easing: slow start, fast middle, slow end
            // Formula: 3t² - 2t³ (smoothstep)
            let eased = Float(progress * progress * (3.0 - 2.0 * progress))
            
            let newVolume = startVolume + (volumeRange * eased)
            self.setSystemVolume(newVolume)
            
            if progress >= 1.0 {
                timer.invalidate()
                self.musicFadeTimer = nil
                self.isSpeakingVoiceOver = false
                print("[AudioPlayer] Fade complete - volume at \(targetVolume)")
            }
        }
    }
    
    // MARK: - Intelligent Voice Selection (ElevenLabs or iOS)
    
    private func speakWithBestVoice(text: String, settings: VoiceOverSettings, completion: (() -> Void)?) {
        print("[AudioPlayer] speakWithBestVoice - voiceType: \(settings.voiceType), voiceIdentifier: \(settings.voiceIdentifier ?? "nil")")
        if settings.voiceType == .elevenLabs, let voiceId = settings.voiceIdentifier {
            print("[AudioPlayer] Routing to ElevenLabs with voiceId: \(voiceId)")
            playElevenLabsAnnouncement(text: text, voiceId: voiceId, completion: completion)
        } else {
            print("[AudioPlayer] Routing to iOS TTS")
            speechService.speak(settings: settings, completion: completion)
        }
    }
    
    func playElevenLabsAnnouncement(text: String, voiceId: String, completion: (() -> Void)?) {
        print("[AudioPlayer] playElevenLabsAnnouncement - text: '\(text.prefix(30))...', voiceId: \(voiceId)")
        isSpeakingVoiceOver = true
        
        elevenLabsService.generateSpeech(text: text, voiceId: voiceId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let audioURL):
                    print("[AudioPlayer] ElevenLabs audio ready, playing: \(audioURL)")
                    self?.playElevenLabsAudio(url: audioURL, completion: completion)
                case .failure(let error):
                    print("[AudioPlayer] ElevenLabs error, falling back to iOS: \(error)")
                    // Fallback to iOS TTS
                    let settings = VoiceOverSettings(enabled: true, text: text)
                    self?.speechService.speak(settings: settings, completion: completion)
                }
            }
        }
    }
    
    private func playElevenLabsAudio(url: URL, completion: (() -> Void)?) {
        do {
            print("[AudioPlayer] playElevenLabsAudio - URL: \(url)")
            elevenLabsPlayer = try AVAudioPlayer(contentsOf: url)
            elevenLabsPlayer?.volume = 1.0
            let success = elevenLabsPlayer?.play() ?? false
            print("[AudioPlayer] ElevenLabs audio playback started: \(success), duration: \(elevenLabsPlayer?.duration ?? 0)s")
            
            // Monitor for completion
            let duration = elevenLabsPlayer?.duration ?? 3.0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) { [weak self] in
                self?.isSpeakingVoiceOver = false
                completion?()
            }
        } catch {
            print("[AudioPlayer] ERROR: Error playing ElevenLabs audio - \(error)")
            isSpeakingVoiceOver = false
            completion?()
        }
    }
    
    func stopElevenLabsAudio() {
        elevenLabsPlayer?.stop()
        elevenLabsPlayer = nil
    }
    

    
    // MARK: - Voice Over + Music Playback (sequential)
    
    private func playWithVoiceOver(button: SoundButton, voiceOver: VoiceOverSettings) {
        isSpeakingVoiceOver = true
        isLoading = true
        
        speechService.speak(settings: voiceOver) { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isSpeakingVoiceOver = false
                
                // Apply post-delay before starting music
                let postDelay = voiceOver.postDelay
                if postDelay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + postDelay) {
                        self.playMusic(button: button)
                    }
                } else {
                    self.playMusic(button: button)
                }
            }
        }
    }
    
    // MARK: - Music Playback (internal)
    
    private func playMusic(button: SoundButton) {
        switch button.musicSource {
        case .appleMusic:
            playAppleMusic(button: button)
        case .spotify:
            playSpotify(button: button)
        }
    }
    
    // MARK: - Apple Music Playback
    
    private func playAppleMusic(button: SoundButton) {
        guard let song = fetchSong(persistentID: button.songPersistentID) else {
            print("Could not find song")
            currentButtonID = nil
            nowPlayingTitle = ""
            return
        }
        
        isLoading = true
        currentArtwork = song.artwork?.image(at: CGSize(width: 100, height: 100))
        
        let collection = MPMediaItemCollection(items: [song])
        musicPlayer.setQueue(with: collection)
        
        targetStartTime = button.startTimeSeconds
        hasSetStartTime = false
        
        musicPlayer.prepareToPlay { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("Error preparing to play: \(error)")
                    self?.currentButtonID = nil
                    self?.nowPlayingTitle = ""
                    self?.currentArtwork = nil
                    return
                }
                
                self?.musicPlayer.currentPlaybackTime = button.startTimeSeconds
                self?.hasSetStartTime = true
                self?.musicPlayer.play()
                
                self?.isPlaying = true
                self?.duration = song.playbackDuration
                
                self?.startTimer()
            }
        }
    }
    
    // MARK: - Spotify Playback
    
    private func playSpotify(button: SoundButton) {
        guard let uri = button.spotifyURI else {
            print("No Spotify URI for this button")
            currentButtonID = nil
            nowPlayingTitle = ""
            return
        }
        
        guard spotifyService.isConnected else {
            // Try to connect first
            isLoading = true
            spotifyService.connect()
            
            // Check connection after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                if self?.spotifyService.isConnected == true {
                    self?.spotifyService.play(uri: uri, position: button.startTimeSeconds)
                } else {
                    self?.isLoading = false
                    self?.currentButtonID = nil
                    self?.nowPlayingTitle = ""
                    print("Could not connect to Spotify")
                }
            }
            return
        }
        
        isLoading = true
        spotifyService.play(uri: uri, position: button.startTimeSeconds)
        
        // Spotify will update via observers
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLoading = false
        }
    }
    
    // MARK: - Stop (with optional fade)
    
    func stop() {
        // Check if we should fade out
        if let button = currentButton, button.fadeOutEnabled, isPlaying, !isFadingOut {
            fadeOutAndStop(duration: button.fadeOutDuration)
            return
        }
        
        // Immediate stop
        stopImmediately()
    }
    
    func stopImmediately() {
        // Cancel any ongoing fades
        cancelFade()
        musicFadeTimer?.invalidate()
        musicFadeTimer = nil
        
        // Restore volume if it was changed
        restoreVolume()
        
        // Stop speech service and ElevenLabs
        speechService.stop()
        stopElevenLabsAudio()
        
        // Stop crossfade music player if active
        crossfadeMusicPlayer?.stop()
        crossfadeMusicPlayer = nil
        
        // Stop both players to be safe
        musicPlayer.stop()
        spotifyService.stop()
        
        isPlaying = false
        isLoading = false
        isFadingOut = false
        isSpeakingVoiceOver = false
        currentButtonID = nil
        currentButton = nil
        currentTime = 0
        nowPlayingTitle = ""
        currentArtwork = nil
        targetStartTime = 0
        hasSetStartTime = false
        stopTimer()
    }
    
    // MARK: - Fade Out
    
    func fadeOutAndStop(duration: Double) {
        guard !isFadingOut else { return }
        
        isFadingOut = true
        
        // Start fading from current system volume
        let audioSession = AVAudioSession.sharedInstance()
        fadeStartVolume = audioSession.outputVolume
        
        let fadeSteps = 20
        let stepDuration = duration / Double(fadeSteps)
        var currentStep = 0
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let progress = Double(currentStep) / Double(fadeSteps)
            let newVolume = self.fadeStartVolume * Float(1.0 - progress)
            
            // Set volume using MPVolumeView (system volume)
            self.setSystemVolume(newVolume)
            
            if currentStep >= fadeSteps {
                timer.invalidate()
                self.fadeTimer = nil
                
                // Final stop
                DispatchQueue.main.async {
                    self.musicPlayer.stop()
                    self.spotifyService.stop()
                    
                    // Restore to initial volume (from when song started)
                    self.restoreVolume()
                    
                    self.isPlaying = false
                    self.isLoading = false
                    self.isFadingOut = false
                    self.currentButtonID = nil
                    self.currentButton = nil
                    self.currentTime = 0
                    self.nowPlayingTitle = ""
                    self.currentArtwork = nil
                    self.targetStartTime = 0
                    self.hasSetStartTime = false
                    self.stopTimer()
                    
                    // Check if there's a pending button to play
                    if let pending = self.pendingButton {
                        self.pendingButton = nil
                        // Small delay to ensure volume is restored before next song
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            self.play(button: pending)
                        }
                    }
                }
            }
        }
    }
    
    private func setSystemVolume(_ volume: Float) {
        // Use the retained volume slider
        DispatchQueue.main.async { [weak self] in
            self?.volumeSlider?.value = volume
        }
    }
    
    private func restoreVolume() {
        // Small delay to ensure music has stopped before restoring volume
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.initialVolume > 0 else { return }
            self.setSystemVolume(self.initialVolume)
            print("Volume restored to: \(self.initialVolume)")
        }
    }
    
    private func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        isFadingOut = false
    }
    
    // MARK: - Toggle Play/Pause
    
    func togglePlayPause() {
        switch currentMusicSource {
        case .appleMusic:
            if musicPlayer.playbackState == .playing {
                musicPlayer.pause()
                isPlaying = false
            } else {
                musicPlayer.play()
                isPlaying = true
            }
        case .spotify:
            if spotifyService.isPlaying {
                spotifyService.pause()
            } else {
                spotifyService.resume()
            }
        }
    }
    
    // MARK: - Fetch Song (Apple Music)
    
    private func fetchSong(persistentID: UInt64) -> MPMediaItem? {
        let predicate = MPMediaPropertyPredicate(
            value: persistentID,
            forProperty: MPMediaItemPropertyPersistentID
        )
        let query = MPMediaQuery()
        query.addFilterPredicate(predicate)
        return query.items?.first
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.currentMusicSource == .appleMusic {
                    self.currentTime = self.musicPlayer.currentPlaybackTime
                }
                // Spotify updates via observer
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Utilities
    
    func getSongDuration(persistentID: UInt64) -> Double? {
        guard let song = fetchSong(persistentID: persistentID) else { return nil }
        return song.playbackDuration
    }
    
    // MARK: - Preview Playback (for configuring start time)
    
    func playPreview(song: MPMediaItem, startTime: Double) {
        stopPreview()
        
        currentMusicSource = .appleMusic
        isLoading = true
        
        let collection = MPMediaItemCollection(items: [song])
        musicPlayer.setQueue(with: collection)
        
        targetStartTime = startTime
        hasSetStartTime = false
        
        musicPlayer.prepareToPlay { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("Error preparing preview: \(error)")
                    return
                }
                
                self?.musicPlayer.currentPlaybackTime = startTime
                self?.hasSetStartTime = true
                self?.musicPlayer.play()
                
                self?.isPreviewing = true
                self?.duration = song.playbackDuration
                
                self?.startTimer()
            }
        }
    }
    
    func playSpotifyPreview(track: SpotifyTrack, startTime: Double) {
        stopPreview()
        
        guard spotifyService.isConnected else {
            spotifyService.connect()
            return
        }
        
        currentMusicSource = .spotify
        isLoading = true
        
        spotifyService.play(uri: track.uri, position: startTime)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLoading = false
            self?.isPreviewing = true
            self?.duration = track.duration
        }
    }
    
    func stopPreview() {
        cancelFade()
        musicPlayer.stop()
        spotifyService.stop()
        isPreviewing = false
        isLoading = false
        targetStartTime = 0
        hasSetStartTime = false
        stopTimer()
    }
    
    func seekPreview(to time: Double) {
        switch currentMusicSource {
        case .appleMusic:
            musicPlayer.currentPlaybackTime = time
        case .spotify:
            spotifyService.seek(to: time)
        }
    }
    
    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
    }
}
