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
    
    private let musicPlayer = MPMusicPlayerController.applicationMusicPlayer
    private var timer: Timer?
    private var targetStartTime: Double = 0
    private var hasSetStartTime: Bool = false
    
    init() {
        setupAudioSession()
        setupNotifications()
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
    
    @objc private func playbackStateDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
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
    
    func play(button: SoundButton) {
        stop()
        
        guard let song = fetchSong(persistentID: button.songPersistentID) else {
            print("Could not find song")
            return
        }
        
        let collection = MPMediaItemCollection(items: [song])
        musicPlayer.setQueue(with: collection)
        
        targetStartTime = button.startTimeSeconds
        hasSetStartTime = false
        
        musicPlayer.prepareToPlay { [weak self] error in
            if let error = error {
                print("Error preparing to play: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self?.musicPlayer.currentPlaybackTime = button.startTimeSeconds
                self?.hasSetStartTime = true
                self?.musicPlayer.play()
                
                self?.isPlaying = true
                self?.currentButtonID = button.id
                self?.duration = song.playbackDuration
                self?.nowPlayingTitle = button.name
                
                self?.startTimer()
            }
        }
    }
    
    func stop() {
        musicPlayer.stop()
        isPlaying = false
        currentButtonID = nil
        currentTime = 0
        nowPlayingTitle = ""
        targetStartTime = 0
        hasSetStartTime = false
        stopTimer()
    }
    
    func togglePlayPause() {
        if musicPlayer.playbackState == .playing {
            musicPlayer.pause()
            isPlaying = false
        } else {
            musicPlayer.play()
            isPlaying = true
        }
    }
    
    private func fetchSong(persistentID: UInt64) -> MPMediaItem? {
        let predicate = MPMediaPropertyPredicate(
            value: persistentID,
            forProperty: MPMediaItemPropertyPersistentID
        )
        let query = MPMediaQuery()
        query.addFilterPredicate(predicate)
        return query.items?.first
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.currentTime = self.musicPlayer.currentPlaybackTime
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func getSongDuration(persistentID: UInt64) -> Double? {
        guard let song = fetchSong(persistentID: persistentID) else { return nil }
        return song.playbackDuration
    }
    
    // MARK: - Preview Playback (for configuring start time)
    
    func playPreview(song: MPMediaItem, startTime: Double) {
        stopPreview()
        
        let collection = MPMediaItemCollection(items: [song])
        musicPlayer.setQueue(with: collection)
        
        targetStartTime = startTime
        hasSetStartTime = false
        
        musicPlayer.prepareToPlay { [weak self] error in
            if let error = error {
                print("Error preparing preview: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self?.musicPlayer.currentPlaybackTime = startTime
                self?.hasSetStartTime = true
                self?.musicPlayer.play()
                
                self?.isPreviewing = true
                self?.duration = song.playbackDuration
                
                self?.startTimer()
            }
        }
    }
    
    func stopPreview() {
        musicPlayer.stop()
        isPreviewing = false
        targetStartTime = 0
        hasSetStartTime = false
        stopTimer()
    }
    
    func seekPreview(to time: Double) {
        musicPlayer.currentPlaybackTime = time
    }
    
    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
    }
}
