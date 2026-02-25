import AVFoundation
import Foundation

// MARK: - SFX Types
enum SFXType {
    case jump, attack, dash, hit, kill
    case bossWarning, bossDeath, dropThrough
    case skillFire, skillWhirlwind, skillShield, skillLightning, skillGhost
    case uiClick
}

class AudioManager {
    
    // MARK: - Audio Engine
    private let engine = AVAudioEngine()
    private var isRunning = false
    private var outputFormat: AVAudioFormat!
    
    // MARK: - BGM State
    private var bgmTimer: Timer?
    private var bgmBpm: Float = 100
    private var bgmSongId: Int = 0
    private var bgmBeat: Int = 0
    private var bgmBar: Int = 0
    
    // Pentatonic Scale (G Major): G A B D E across octaves
    private let scale: [String: Float] = [
        "G3": 196, "A3": 220, "B3": 247, "D4": 293, "E4": 330,
        "G4": 392, "A4": 440, "B4": 494, "D5": 587, "E5": 659,
        "G5": 784, "A5": 880, "B5": 988, "D6": 1175, "E6": 1318
    ]
    
    // MARK: - Song Data (melody only — no drums/backing)
    // Each song is an array of [noteName, duration] pairs
    private let songs: [[(String, Int)]] = [
        // Lv1: Cang Hai Yi Sheng Xiao (Heroic) — 沧海一声笑
        [("E5", 2), ("D5", 2), ("B4", 2), ("A4", 2), ("G4", 4), ("rest", 2),
         ("B4", 2), ("A4", 2), ("G4", 2), ("E4", 2), ("D4", 4), ("rest", 2),
         ("G4", 2), ("A4", 2), ("B4", 4), ("D5", 4), ("E5", 8),
         ("D5", 2), ("B4", 2), ("A4", 4), ("G4", 4), ("rest", 2),
         ("E4", 2), ("G4", 2), ("A4", 2), ("B4", 4), ("D5", 4),
         ("E5", 2), ("D5", 2), ("B4", 2), ("G4", 2), ("A4", 8),
         ("G4", 2), ("A4", 2), ("B4", 2), ("D5", 2), ("E5", 4), ("G5", 4),
         ("E5", 2), ("D5", 2), ("B4", 4), ("A4", 2), ("G4", 2), ("E4", 4),
         ("D4", 2), ("E4", 2), ("G4", 4), ("A4", 4), ("B4", 8),
         ("D5", 2), ("E5", 2), ("G5", 4), ("E5", 2), ("D5", 2), ("B4", 4),
         ("A4", 2), ("G4", 2), ("E4", 2), ("D4", 2), ("G4", 8)],

        // Lv2: Xiao Ao Jiang Hu (Carefree) — 笑傲江湖
        [("G4", 2), ("A4", 2), ("B4", 4), ("D5", 2), ("E5", 2), ("G5", 4),
         ("E5", 2), ("D5", 2), ("B4", 4), ("rest", 2),
         ("A4", 2), ("B4", 2), ("D5", 4), ("G4", 4), ("rest", 2),
         ("G4", 2), ("B4", 2), ("D5", 2), ("E5", 4), ("D5", 2), ("B4", 2),
         ("A4", 4), ("G4", 4), ("rest", 2),
         ("E5", 2), ("D5", 2), ("B4", 2), ("A4", 2), ("G4", 4), ("rest", 2),
         ("D5", 2), ("E5", 2), ("G5", 4), ("E5", 2), ("D5", 2), ("B4", 8),
         ("G4", 2), ("A4", 2), ("B4", 2), ("D5", 2), ("E5", 4), ("G5", 4),
         ("A5", 2), ("G5", 2), ("E5", 4), ("D5", 2), ("B4", 2), ("A4", 4),
         ("G4", 2), ("A4", 2), ("B4", 4), ("D5", 8),
         ("B4", 2), ("A4", 2), ("G4", 4), ("E4", 2), ("G4", 2), ("A4", 8)],

        // Lv3: Quan Jiao Xiang Jia (Martial) — 拳脚相加
        [("D5", 1), ("E5", 1), ("G5", 2), ("E5", 1), ("D5", 1), ("B4", 2),
         ("A4", 1), ("B4", 1), ("D5", 2), ("G4", 4),
         ("B4", 2), ("A4", 2), ("G4", 4), ("D4", 2), ("E4", 2),
         ("G4", 1), ("A4", 1), ("B4", 2), ("D5", 1), ("E5", 1), ("G5", 2),
         ("E5", 1), ("D5", 1), ("B4", 2), ("A4", 4), ("rest", 2),
         ("G5", 1), ("E5", 1), ("D5", 1), ("B4", 1), ("A4", 2), ("G4", 2),
         ("B4", 1), ("D5", 1), ("E5", 2), ("G5", 4), ("rest", 2),
         ("A4", 1), ("B4", 1), ("D5", 1), ("E5", 1), ("G5", 2), ("A5", 2),
         ("G5", 1), ("E5", 1), ("D5", 2), ("B4", 4), ("G4", 4),
         ("D5", 1), ("E5", 1), ("D5", 1), ("B4", 1), ("A4", 2), ("G4", 2),
         ("E4", 2), ("D4", 2), ("G4", 8)],

        // Lv4: Shi Mian Mai Fu (Ambush) — 十面埋伏
        [("G5", 1), ("E5", 1), ("D5", 1), ("B4", 1), ("A4", 2), ("G4", 2),
         ("E4", 1), ("D4", 1), ("G3", 2), ("A3", 4), ("rest", 2),
         ("D5", 2), ("E5", 2), ("G5", 4), ("rest", 2),
         ("A5", 1), ("G5", 1), ("E5", 1), ("D5", 1), ("B4", 2), ("A4", 2),
         ("G4", 1), ("A4", 1), ("B4", 2), ("D5", 4), ("rest", 2),
         ("G5", 1), ("E5", 1), ("G5", 1), ("A5", 1), ("G5", 2), ("E5", 2),
         ("D5", 1), ("B4", 1), ("A4", 2), ("G4", 4), ("rest", 2),
         ("E4", 1), ("G4", 1), ("A4", 1), ("B4", 1), ("D5", 2), ("E5", 2),
         ("G5", 1), ("A5", 1), ("G5", 2), ("E5", 4), ("D5", 4),
         ("B4", 1), ("A4", 1), ("G4", 2), ("E4", 2), ("D4", 2), ("G3", 4),
         ("A3", 2), ("D4", 2), ("E4", 2), ("G4", 2), ("A4", 8)],

        // Lv5: Bai Bu Chuan Yang (Archery) — 百步穿杨
        [("E5", 2), ("G5", 2), ("A5", 4), ("G5", 2), ("E5", 2), ("D5", 4),
         ("B4", 2), ("D5", 2), ("E5", 4), ("rest", 2),
         ("G4", 4), ("A4", 4), ("B4", 4), ("rest", 2),
         ("D5", 2), ("E5", 2), ("G5", 2), ("A5", 2), ("G5", 4), ("E5", 4),
         ("D5", 2), ("B4", 2), ("A4", 4), ("G4", 4), ("rest", 2),
         ("B4", 2), ("D5", 2), ("E5", 4), ("G5", 2), ("A5", 2), ("B5", 4),
         ("A5", 2), ("G5", 2), ("E5", 4), ("D5", 2), ("B4", 2), ("A4", 4),
         ("G4", 2), ("A4", 2), ("B4", 2), ("D5", 2), ("E5", 8),
         ("G5", 2), ("E5", 2), ("D5", 4), ("B4", 2), ("A4", 2), ("G4", 4),
         ("E4", 2), ("G4", 2), ("A4", 4), ("B4", 8)],

        // Lv6: Dao Guang Jian Ying (Blades) — 刀光剑影
        [("G5", 1), ("rest", 1), ("G5", 1), ("E5", 1), ("D5", 2), ("B4", 2),
         ("G4", 1), ("rest", 1), ("G4", 1), ("A4", 1), ("B4", 4),
         ("D5", 2), ("E5", 2), ("G5", 2), ("rest", 2),
         ("A5", 1), ("G5", 1), ("E5", 1), ("D5", 1), ("B4", 2), ("rest", 2),
         ("G4", 1), ("A4", 1), ("B4", 1), ("D5", 1), ("E5", 2), ("G5", 2),
         ("E5", 1), ("rest", 1), ("E5", 1), ("D5", 1), ("B4", 2), ("A4", 2),
         ("G4", 1), ("A4", 1), ("B4", 2), ("D5", 4), ("rest", 2),
         ("G5", 1), ("A5", 1), ("G5", 1), ("E5", 1), ("D5", 2), ("B4", 2),
         ("A4", 1), ("B4", 1), ("D5", 1), ("E5", 1), ("G5", 4), ("rest", 2),
         ("D5", 1), ("E5", 1), ("D5", 1), ("B4", 1), ("A4", 2), ("G4", 2),
         ("E4", 1), ("G4", 1), ("A4", 2), ("B4", 4), ("D5", 8)],

        // Lv7: Long Zheng Hu Dou (Dragon Tiger) — 龙争虎斗
        [("B4", 1), ("D5", 1), ("E5", 1), ("G5", 1), ("A5", 2), ("G5", 2),
         ("E5", 1), ("D5", 1), ("B4", 2), ("G4", 4),
         ("A4", 2), ("B4", 2), ("D5", 2), ("E5", 2), ("G5", 4), ("rest", 2),
         ("A5", 1), ("G5", 1), ("E5", 2), ("D5", 1), ("B4", 1), ("A4", 2),
         ("G4", 2), ("A4", 2), ("B4", 4), ("D5", 4), ("rest", 2),
         ("E5", 1), ("G5", 1), ("A5", 2), ("G5", 1), ("E5", 1), ("D5", 2),
         ("B4", 1), ("A4", 1), ("G4", 2), ("E4", 4), ("rest", 2),
         ("G4", 1), ("A4", 1), ("B4", 1), ("D5", 1), ("E5", 2), ("G5", 2),
         ("A5", 2), ("G5", 2), ("E5", 4), ("D5", 2), ("B4", 2),
         ("A4", 1), ("B4", 1), ("D5", 2), ("E5", 4), ("G5", 8),
         ("E5", 2), ("D5", 2), ("B4", 4), ("A4", 2), ("G4", 2), ("E4", 8)],

        // Lv8: Chun Jiang Hua Yue Ye (Moon Reflected) — 春江花月夜
        [("G5", 3), ("E5", 1), ("D5", 2), ("B4", 2), ("A4", 4),
         ("G4", 2), ("A4", 1), ("B4", 1), ("D5", 4), ("rest", 2),
         ("B4", 2), ("A4", 2), ("G4", 4), ("E4", 2), ("D4", 2), ("G3", 4),
         ("rest", 2), ("A3", 2), ("D4", 2), ("E4", 2), ("G4", 4),
         ("A4", 3), ("G4", 1), ("E4", 2), ("D4", 2), ("G4", 4), ("rest", 2),
         ("B4", 2), ("D5", 2), ("E5", 3), ("D5", 1), ("B4", 2), ("A4", 2),
         ("G4", 4), ("A4", 2), ("B4", 2), ("D5", 4), ("rest", 2),
         ("E5", 3), ("D5", 1), ("B4", 2), ("A4", 2), ("G4", 4),
         ("E4", 2), ("G4", 2), ("A4", 3), ("G4", 1), ("E4", 4), ("D4", 4),
         ("G3", 2), ("A3", 2), ("D4", 4), ("E4", 2), ("G4", 2), ("A4", 8)],

        // Lv9: Gao Shan Liu Shui (Ethereal) — 高山流水
        [("G5", 4), ("E5", 4), ("D5", 4), ("B4", 4),
         ("G4", 4), ("A4", 4), ("B4", 8),
         ("D5", 4), ("E5", 4), ("G5", 8), ("rest", 4),
         ("A5", 4), ("G5", 4), ("E5", 4), ("D5", 4),
         ("B4", 4), ("A4", 4), ("G4", 8), ("rest", 4),
         ("E4", 4), ("G4", 4), ("A4", 4), ("B4", 4),
         ("D5", 4), ("E5", 4), ("G5", 4), ("A5", 4),
         ("G5", 4), ("E5", 4), ("D5", 8),
         ("B4", 4), ("D5", 4), ("E5", 4), ("G5", 4),
         ("A5", 4), ("G5", 4), ("E5", 4), ("D5", 4), ("B4", 8)],

        // Lv10: Mei Hua San Nong (Plum Blossom) — 梅花三弄
        [("E6", 2), ("D6", 2), ("B5", 4), ("A5", 2), ("G5", 2), ("E5", 4),
         ("G5", 2), ("A5", 2), ("B5", 8), ("rest", 2),
         ("E5", 2), ("D5", 2), ("G4", 4), ("A4", 2), ("B4", 2), ("D5", 4),
         ("E5", 2), ("G5", 2), ("A5", 4), ("G5", 2), ("E5", 2), ("D5", 4),
         ("B4", 2), ("A4", 2), ("G4", 4), ("rest", 2),
         ("D6", 2), ("B5", 2), ("A5", 4), ("G5", 2), ("E5", 2), ("D5", 4),
         ("E5", 2), ("G5", 2), ("A5", 2), ("B5", 2), ("D6", 4), ("rest", 2),
         ("E6", 2), ("D6", 2), ("B5", 2), ("A5", 2), ("G5", 4), ("E5", 4),
         ("D5", 2), ("E5", 2), ("G5", 4), ("A5", 2), ("G5", 2), ("E5", 4),
         ("D5", 2), ("B4", 2), ("A4", 4), ("G4", 2), ("A4", 2), ("B4", 8)],

        // Boss Battle: Intense, fast-paced combat melody (index 10, BPM 160)
        [("G5", 1), ("E5", 1), ("G5", 1), ("A5", 1), ("G5", 2), ("E5", 1), ("D5", 1),
         ("B4", 2), ("D5", 1), ("E5", 1), ("G5", 2), ("rest", 1),
         ("A5", 1), ("G5", 1), ("E5", 1), ("D5", 1), ("B4", 1), ("A4", 2), ("G4", 2),
         ("rest", 1), ("B4", 1), ("D5", 1), ("E5", 1), ("G5", 2), ("A5", 2),
         ("G5", 1), ("E5", 1), ("D5", 2), ("B4", 1), ("A4", 1), ("G4", 2),
         ("A4", 1), ("B4", 1), ("D5", 2), ("E5", 2), ("G5", 4),
         ("A5", 1), ("G5", 1), ("E5", 1), ("D5", 1), ("B4", 2), ("A4", 1), ("B4", 1),
         ("D5", 2), ("E5", 1), ("G5", 1), ("A5", 2), ("G5", 2),
         ("E5", 1), ("D5", 1), ("B4", 2), ("A4", 2), ("G4", 4),
         ("D5", 1), ("E5", 1), ("G5", 1), ("A5", 1), ("G5", 1), ("E5", 1), ("D5", 1), ("B4", 1),
         ("A4", 2), ("B4", 2), ("D5", 2), ("E5", 2), ("G5", 8)]
    ]
    
    // MARK: - Init
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[AudioManager] Session error: \(error)")
        }
    }
    
    private func ensureEngineRunning() {
        guard !isRunning else { return }
        do {
            // Force the engine to build its internal graph by accessing mainMixerNode
            // This connects: [mainMixerNode] -> [outputNode]
            // Without this, engine.start() crashes on real devices
            let mixer = engine.mainMixerNode
            outputFormat = mixer.outputFormat(forBus: 0)
            
            // Create a standard format if the hardware format has 0 channels
            if outputFormat.channelCount == 0 {
                outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)
            }
            
            try engine.start()
            isRunning = true
        } catch {
            print("[AudioManager] Engine start error: \(error)")
        }
    }
    
    // MARK: - SFX
    
    func playTone(frequency: Float, type: String = "sine", duration: Float, volume: Float) {
        ensureEngineRunning()
        guard isRunning, let fmt = outputFormat else { return }
        
        let sampleRate = Float(fmt.sampleRate)
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt,
                                             frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { return }
        let data = channelData[0]
        
        var phase: Float = 0
        let increment = frequency / sampleRate
        
        for frame in 0..<Int(frameCount) {
            let t = Float(frame) / Float(frameCount)
            let envelope = volume * (1.0 - t) // Linear decay
            
            var sample: Float
            switch type {
            case "square":
                sample = phase < 0.5 ? 1.0 : -1.0
            case "sawtooth":
                sample = 2.0 * phase - 1.0
            case "triangle":
                sample = 4.0 * abs(phase - 0.5) - 1.0
            default: // sine
                sample = sin(phase * 2.0 * .pi)
            }
            
            data[frame] = sample * envelope
            phase += increment
            if phase >= 1.0 { phase -= 1.0 }
        }
        
        // Fill second channel if stereo
        let channelCount = Int(fmt.channelCount)
        if channelCount > 1 {
            let rightData = channelData[1]
            for frame in 0..<Int(frameCount) {
                rightData[frame] = data[frame]
            }
        }
        
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)
        playerNode.play()
        playerNode.scheduleBuffer(buffer) {
            DispatchQueue.main.async {
                self.engine.detach(playerNode)
            }
        }
    }
    
    // MARK: - Game SFX

    func playSFX(_ type: SFXType) {
        switch type {
        case .jump:
            playTone(frequency: 880, type: "sine", duration: 0.07, volume: 0.10)
        case .attack:
            playTone(frequency: 350, type: "sawtooth", duration: 0.05, volume: 0.09)
        case .dash:
            playTone(frequency: 200, type: "square", duration: 0.10, volume: 0.12)
        case .hit:
            playTone(frequency: 300, type: "triangle", duration: 0.04, volume: 0.07)
        case .kill:
            playTone(frequency: 550, type: "sine", duration: 0.12, volume: 0.14)
        case .bossWarning:
            // Deep ominous double-strike
            playTone(frequency: 110, type: "square", duration: 0.4, volume: 0.20)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.playTone(frequency: 82, type: "square", duration: 0.6, volume: 0.22)
            }
        case .bossDeath:
            playTone(frequency: 440, type: "sine", duration: 0.15, volume: 0.18)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.playTone(frequency: 660, type: "sine", duration: 0.15, volume: 0.16)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                self.playTone(frequency: 880, type: "sine", duration: 0.3, volume: 0.20)
            }
        case .dropThrough:
            playTone(frequency: 440, type: "sine", duration: 0.05, volume: 0.06)
        case .skillFire:
            playTone(frequency: 500, type: "sawtooth", duration: 0.10, volume: 0.11)
        case .skillWhirlwind:
            playTone(frequency: 400, type: "sine", duration: 0.12, volume: 0.09)
        case .skillShield:
            playTone(frequency: 180, type: "triangle", duration: 0.10, volume: 0.11)
        case .skillLightning:
            playTone(frequency: 900, type: "square", duration: 0.06, volume: 0.11)
        case .skillGhost:
            playTone(frequency: 150, type: "sine", duration: 0.15, volume: 0.09)
        case .uiClick:
            playTone(frequency: 600, type: "sine", duration: 0.025, volume: 0.05)
        }
    }

    // MARK: - Boss BGM

    private var savedSongId: Int = 0
    private var savedBpm: Float = 100

    func startBossBGM() {
        savedSongId = bgmSongId
        savedBpm = bgmBpm
        startBGM(songId: 10, bpm: 160)
    }

    func restoreLevelBGM() {
        startBGM(songId: savedSongId, bpm: savedBpm)
    }

    // MARK: - Guzheng Synthesis
    
    func playGuzheng(frequency: Float, duration: Float, volume: Float = 0.12) {
        ensureEngineRunning()
        guard isRunning, let fmt = outputFormat, frequency > 0 else { return }
        
        let sampleRate = Float(fmt.sampleRate)
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt,
                                             frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { return }
        let data = channelData[0]
        
        var phase1: Float = 0
        var phase2: Float = 0
        let inc1 = frequency / sampleRate
        let inc2 = (frequency * 2) / sampleRate
        
        for frame in 0..<Int(frameCount) {
            let t = Float(frame) / Float(frameCount)
            
            // Attack + decay envelope
            let attack: Float = min(t * 50, 1.0)
            let decay: Float = exp(-t * 4.0)
            let envelope = attack * decay * volume
            
            // Triangle + sine harmonic
            let tri = 4.0 * abs(phase1 - 0.5) - 1.0
            let harm = sin(phase2 * 2.0 * .pi) * 0.3
            
            // Slight vibrato
            let vibrato = sin(Float(frame) / sampleRate * 5.0 * 2.0 * .pi) * 0.003
            
            data[frame] = (tri + harm) * envelope
            phase1 += inc1 * (1.0 + vibrato)
            phase2 += inc2 * (1.0 + vibrato)
            if phase1 >= 1.0 { phase1 -= 1.0 }
            if phase2 >= 1.0 { phase2 -= 1.0 }
        }
        
        // Stereo
        let channelCount = Int(fmt.channelCount)
        if channelCount > 1 {
            let rightData = channelData[1]
            for frame in 0..<Int(frameCount) {
                rightData[frame] = data[frame]
            }
        }
        
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)
        playerNode.play()
        playerNode.scheduleBuffer(buffer) {
            DispatchQueue.main.async {
                self.engine.detach(playerNode)
            }
        }
    }
    
    // MARK: - BGM Control
    
    func startBGM(songId: Int, bpm: Float) {
        stopBGM()
        
        bgmSongId = max(0, min(songId, songs.count - 1))
        bgmBpm = bpm
        bgmBeat = 0
        bgmBar = 0
        
        print("[AudioManager] Starting BGM: song \(bgmSongId), bpm \(bpm), notes: \(songs[bgmSongId].count)")
        
        let interval = TimeInterval(60.0 / bpm / 4.0)  // 16th note
        bgmTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.scheduleBGMNote()
        }
    }
    
    func stopBGM() {
        bgmTimer?.invalidate()
        bgmTimer = nil
    }
    
    func changeSong(songId: Int, bpm: Float) {
        print("[AudioManager] Changing song to \(songId), bpm \(bpm)")
        startBGM(songId: songId, bpm: bpm)
    }
    
    private func scheduleBGMNote() {
        let song = songs[bgmSongId]
        
        // Find current note based on accumulated beats
        var acc = 0
        var noteIndex = 0
        for (i, note) in song.enumerated() {
            acc += note.1
            if acc > bgmBeat {
                noteIndex = i
                break
            }
            if i == song.count - 1 {
                // Loop back
                bgmBeat = 0
                noteIndex = 0
                break
            }
        }
        
        let (noteName, _) = song[noteIndex]
        
        // Check if this is the start of a new note
        var prevAcc = 0
        for i in 0..<noteIndex {
            prevAcc += song[i].1
        }
        
        if bgmBeat == prevAcc && noteName != "rest" {
            if let freq = scale[noteName] {
                let noteDur = Float(song[noteIndex].1) * 60.0 / bgmBpm / 4.0
                playGuzheng(frequency: freq, duration: noteDur * 0.9)
            }
        }
        
        bgmBeat += 1
    }
    
    // MARK: - Combat SFX

    func playHitSFX() {
        let freq = Float.random(in: 800...1200)
        playTone(frequency: freq, type: "square", duration: 0.04, volume: 0.08)
    }

    func playKillSFX() {
        playTone(frequency: 600, type: "square", duration: 0.06, volume: 0.1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            self.playTone(frequency: 900, type: "square", duration: 0.08, volume: 0.1)
        }
    }

    // MARK: - Cleanup

    deinit {
        stopBGM()
        engine.stop()
    }
}
