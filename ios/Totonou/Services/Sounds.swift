import AVFoundation

/// The three sounds the app makes. The files are in Totonou/Sounds.
enum Sound: String {
    case complete, levelUp = "levelup", hit
}

@MainActor
enum Sounds {
    private static var players: [Sound: AVAudioPlayer] = [:]
    private static var isReady = false

    /// Off when the user switched sounds off on the Status screen.
    static var isOn: Bool { UserDefaults.standard.object(forKey: "soundsOn") as? Bool ?? true }

    static func play(_ sound: Sound) {
        guard isOn else { return }
        if !isReady {
            // .ambient: obeys the silent switch and does not stop the user's music.
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            isReady = true
        }
        if players[sound] == nil, let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") {
            players[sound] = try? AVAudioPlayer(contentsOf: url)
        }
        players[sound]?.currentTime = 0
        players[sound]?.play()
    }
}
