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
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func play(button: SoundButton) {
        stop()
        
        guard let song = fetchSong(persistentID: button.songPersistentID),
              let assetURL = song.assetURL else {
            print("Could not find song or asset URL")
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: assetURL)
            player?.prepareToPlay()
            player?.currentTime = button.startTimeSeconds
            player?.play()
            
            isPlaying = true
            currentButtonID = button.id
            duration = player?.duration ?? 0
            nowPlayingTitle = button.name
            
            startTimer()
        } catch {
            print("Error playing audio: \(error)")
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentButtonID = nil
        currentTime = 0
        nowPlayingTitle = ""
        stopTimer()
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.currentTime = self?.player?.currentTime ?? 0
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
}
