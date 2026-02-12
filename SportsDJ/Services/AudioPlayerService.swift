import Foundation
import AVFoundation
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
    private var timer: Timer?
    private var fadeTimer: Timer?
    private var targetStartTime: Double = 0
    private var hasSetStartTime: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
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
        
        // Check if this is a voice-only button (lineup announcement without song)
        if button.isVoiceOnly && !button.isLineupAnnouncement {
            playVoiceOnly(button: button)
            return
        }
        
        // Check if this is a lineup announcement with song (overlapping playback)
        if button.isLineupAnnouncement, let voiceOver = button.voiceOver, voiceOver.enabled {
            playLineupAnnouncement(button: button, voiceOver: voiceOver)
            return
        }
        
        // Check if there's a voice over to play first (sequential)
        if let voiceOver = button.voiceOver, voiceOver.enabled, !voiceOver.text.isEmpty {
            playWithVoiceOver(button: button, voiceOver: voiceOver)
            return
        }
        
        // No voice over, play directly
        playMusic(button: button)
    }
    
    private func captureInitialVolume() {
        let audioSession = AVAudioSession.sharedInstance()
        initialVolume = audioSession.outputVolume
        print("Initial volume captured: \(initialVolume)")
    }
    
    // MARK: - Voice Only Playback (for lineup announcements without song)
    
    private func playVoiceOnly(button: SoundButton) {
        guard let voiceOver = button.voiceOver, voiceOver.enabled else {
            stopImmediately()
            return
        }
        
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
    
    // MARK: - Lineup Announcement Playback (voice + song overlap)
    
    private func playLineupAnnouncement(button: SoundButton, voiceOver: VoiceOverSettings) {
        isSpeakingVoiceOver = true
        isPlaying = true
        
        speakWithBestVoice(text: voiceOver.text, settings: voiceOver, completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.playMusicWithFadeIn(button: button, fadeInDuration: 1.0)
        }
    }
    
    // MARK: - Intelligent Voice Selection (ElevenLabs or iOS)
    
    private func speakWithBestVoice(text: String, settings: VoiceOverSettings, completion: (() -> Void)?) {
        // Check if ElevenLabs is configured and we should use it
        // For now, we use iOS voices for regular VoiceOverSettings
        // ElevenLabs is used when Voice model specifies it
        speechService.speak(settings: settings, completion: completion)
    }
    
    func playElevenLabsAnnouncement(text: String, voiceId: String, completion: (() -> Void)?) {
        isSpeakingVoiceOver = true
        
        elevenLabsService.generateSpeech(text: text, voiceId: voiceId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let audioURL):
                    self?.playElevenLabsAudio(url: audioURL, completion: completion)
                case .failure(let error):
                    print("ElevenLabs error, falling back to iOS: \(error)")
                    // Fallback to iOS TTS
                    let settings = VoiceOverSettings(enabled: true, text: text)
                    self?.speechService.speak(settings: settings, completion: completion)
                }
            }
        }
    }
    
    private func playElevenLabsAudio(url: URL, completion: (() -> Void)?) {
        do {
            elevenLabsPlayer = try AVAudioPlayer(contentsOf: url)
            elevenLabsPlayer?.volume = 1.0
            elevenLabsPlayer?.play()
            
            // Monitor for completion
            let duration = elevenLabsPlayer?.duration ?? 3.0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) { [weak self] in
                self?.isSpeakingVoiceOver = false
                completion?()
            }
        } catch {
            print("Error playing ElevenLabs audio: \(error)")
            isSpeakingVoiceOver = false
            completion?()
        }
    }
    
    func stopElevenLabsAudio() {
        elevenLabsPlayer?.stop()
        elevenLabsPlayer = nil
    }
    
    // MARK: - Music with Fade In
    
    private func playMusicWithFadeIn(button: SoundButton, fadeInDuration: Double) {
        switch button.musicSource {
        case .appleMusic:
            playAppleMusicWithFadeIn(button: button, fadeInDuration: fadeInDuration)
        case .spotify:
            playSpotify(button: button)
        }
    }
    
    private func playAppleMusicWithFadeIn(button: SoundButton, fadeInDuration: Double) {
        guard let song = fetchSong(persistentID: button.songPersistentID) else {
            print("Could not find song for lineup")
            return
        }
        
        currentArtwork = song.artwork?.image(at: CGSize(width: 100, height: 100))
        
        let collection = MPMediaItemCollection(items: [song])
        musicPlayer.setQueue(with: collection)
        
        targetStartTime = button.startTimeSeconds
        hasSetStartTime = false
        
        setSystemVolume(0)
        
        musicPlayer.prepareToPlay { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Error preparing to play: \(error)")
                    self.restoreVolume()
                    return
                }
                
                self.musicPlayer.currentPlaybackTime = button.startTimeSeconds
                self.hasSetStartTime = true
                self.musicPlayer.play()
                
                self.duration = song.playbackDuration
                self.startTimer()
                
                self.fadeInMusic(duration: fadeInDuration)
            }
        }
    }
    
    private func fadeInMusic(duration: Double) {
        let fadeSteps = 20
        let stepDuration = duration / Double(fadeSteps)
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let progress = Double(currentStep) / Double(fadeSteps)
            let newVolume = self.initialVolume * Float(progress)
            
            self.setSystemVolume(newVolume)
            
            if currentStep >= fadeSteps {
                timer.invalidate()
                self.isSpeakingVoiceOver = false
            }
        }
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
        // Cancel any ongoing fade
        cancelFade()
        
        // Restore volume if it was changed
        restoreVolume()
        
        // Stop speech service and ElevenLabs
        speechService.stop()
        stopElevenLabsAudio()
        
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
