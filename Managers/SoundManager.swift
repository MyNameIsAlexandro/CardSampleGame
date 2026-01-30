import AVFoundation

/// Centralized sound effect manager (UX-03)
/// Usage: SoundManager.shared.play(.cardDraw)
///
/// Sound files are loaded from the app bundle.
/// If a sound file is missing, playback is silently skipped.
final class SoundManager {
    static let shared = SoundManager()

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?
    private var isMuted = false

    private init() {
        // Configure audio session for mixing with other apps
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        preloadSounds()
    }

    // MARK: - Sound Effects

    enum SoundEffect: String, CaseIterable {
        // UI
        case buttonTap = "sfx_button_tap"
        case cardSelect = "sfx_card_select"
        case cardDraw = "sfx_card_draw"
        case cardPlay = "sfx_card_play"
        case menuOpen = "sfx_menu_open"

        // Combat
        case attackHit = "sfx_attack_hit"
        case attackBlock = "sfx_attack_block"
        case influence = "sfx_influence"
        case defend = "sfx_defend"
        case flee = "sfx_flee"
        case enemyAttack = "sfx_enemy_attack"
        case damageTaken = "sfx_damage_taken"
        case enemyDefeated = "sfx_enemy_defeated"

        // Fate
        case fateReveal = "sfx_fate_reveal"
        case fateCritical = "sfx_fate_critical"

        // Results
        case victory = "sfx_victory"
        case defeat = "sfx_defeat"
        case lootReceived = "sfx_loot_received"
        case questComplete = "sfx_quest_complete"
    }

    func play(_ effect: SoundEffect) {
        guard !isMuted else { return }
        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted {
            musicPlayer?.pause()
        } else {
            musicPlayer?.play()
        }
    }

    // MARK: - Background Music

    enum MusicTrack: String {
        case menu = "music_menu"
        case exploration = "music_exploration"
        case combat = "music_combat"
    }

    func playMusic(_ track: MusicTrack, fadeDuration: TimeInterval = 1.0) {
        guard !isMuted else { return }
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "mp3")
                ?? Bundle.main.url(forResource: track.rawValue, withExtension: "m4a") else {
            return
        }

        // Don't restart if same track
        if musicPlayer?.url == url && musicPlayer?.isPlaying == true { return }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1 // Loop forever
            newPlayer.volume = 0
            newPlayer.prepareToPlay()
            newPlayer.play()

            // Crossfade
            let oldPlayer = musicPlayer
            musicPlayer = newPlayer
            fadeIn(newPlayer, duration: fadeDuration)
            if let old = oldPlayer {
                fadeOut(old, duration: fadeDuration)
            }
        } catch {
            #if DEBUG
            print("SoundManager: Failed to load music \(track.rawValue): \(error)")
            #endif
        }
    }

    func stopMusic(fadeDuration: TimeInterval = 1.0) {
        guard let player = musicPlayer else { return }
        fadeOut(player, duration: fadeDuration)
        musicPlayer = nil
    }

    // MARK: - Private

    private func preloadSounds() {
        for effect in SoundEffect.allCases {
            if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav")
                ?? Bundle.main.url(forResource: effect.rawValue, withExtension: "mp3")
                ?? Bundle.main.url(forResource: effect.rawValue, withExtension: "m4a") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    players[effect] = player
                } catch {
                    #if DEBUG
                    print("SoundManager: Failed to preload \(effect.rawValue): \(error)")
                    #endif
                }
            }
        }
    }

    private func fadeIn(_ player: AVAudioPlayer, duration: TimeInterval) {
        player.volume = 0
        player.setVolume(0.5, fadeDuration: duration)
    }

    private func fadeOut(_ player: AVAudioPlayer, duration: TimeInterval) {
        player.setVolume(0, fadeDuration: duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            player.stop()
        }
    }
}
