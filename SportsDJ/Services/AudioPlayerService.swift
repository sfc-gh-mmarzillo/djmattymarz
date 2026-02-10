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
    
    private let musicPlayer = MPMusicPlayerController.applicationMusicPlayer
    private let spotifyService = SpotifyService.shared
    private var timer: Timer?
    private var fadeTimer: Timer?
    private var targetStartTime: Double = 0
    private var hasSetStartTime: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    // Fade out properties
    private var currentButton: SoundButton?
    private var originalVolume: Float = 1.0
    private var fadeStartVolume: Float = 1.0
    
    init() {
        setupAudioSession()
        setupNotifications()
        setupSpotifyObservers()
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
        stop()
        
        currentButton = button
        currentButtonID = button.id
        nowPlayingTitle = button.name
        currentMusicSource = button.musicSource
        
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
        
        // Stop both players to be safe
        musicPlayer.stop()
        spotifyService.stop()
        
        isPlaying = false
        isLoading = false
        isFadingOut = false
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
        
        // Get current system volume
        let audioSession = AVAudioSession.sharedInstance()
        originalVolume = audioSession.outputVolume
        fadeStartVolume = originalVolume
        
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
                    
                    // Restore original volume
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
                }
            }
        }
    }
    
    private func setSystemVolume(_ volume: Float) {
        // Use MPVolumeView to set system volume
        let volumeView = MPVolumeView()
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.async {
                slider.value = volume
            }
        }
    }
    
    private func restoreVolume() {
        if originalVolume > 0 {
            setSystemVolume(originalVolume)
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
