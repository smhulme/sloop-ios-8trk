import Foundation
import Combine

public struct Step: Identifiable, Equatable {
    public let id: Int
    public var isOn: Bool
    public var noteName: String
    public var frequency: Double
    
    public init(id: Int, isOn: Bool, noteName: String, frequency: Double) {
        self.id = id
        self.isOn = isOn
        self.noteName = noteName
        self.frequency = frequency
    }
}

public struct TrackModel: Identifiable {
    public let id: Int // 1 to 8
    public var name: String
    public var isHardware: Bool
    public var colorHex: String
    public var level: Double = 100.0
    public var pan: Double = 0.0
    public var isMuted: Bool = false
    public var synthType: SynthType = .polyKeys
    public var steps: [Step]
    
    public init(id: Int, name: String, isHardware: Bool, colorHex: String, synthType: SynthType, steps: [Step]) {
        self.id = id
        self.name = name
        self.isHardware = isHardware
        self.colorHex = colorHex
        self.synthType = synthType
        self.steps = steps
    }
}

public final class SequencerModel: ObservableObject {
    public static let shared = SequencerModel()
    
    @Published public var tracks: [TrackModel] = []
    @Published public var selectedTrackIndex: Int = 4 // Default to Track 5 (first auxiliary synth)
    @Published public var currentStepIndex: Int = 0
    @Published public var isPlaying: Bool = false
    @Published public var bpm: Double = 120.0
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        buildDefaultTracks()
        bindMIDI()
    }
    
    private func buildDefaultTracks() {
        // Tracks 1-4 (Hardware M-VAVE FM-1)
        let hwColors = ["#287cff", "#1ecc70", "#ffc618", "#ff621a"]
        let hwNames = ["FM-1 SYNTH 1", "FM-1 SYNTH 2", "FM-1 SYNTH 3", "FM-1 DRUMS"]
        
        for i in 0..<4 {
            tracks.append(TrackModel(
                id: i + 1,
                name: hwNames[i],
                isHardware: true,
                colorHex: hwColors[i],
                synthType: .polyKeys,
                steps: []
            ))
        }
        
        // Tracks 5-8 (Native iOS DSP Synths)
        let swColors = ["#a040ff", "#00d2d2", "#ff4090", "#38b000"]
        let swNames = ["POLY KEYS", "ANALOG BASS", "FM BELL/LEAD", "PERC ARP"]
        let swSynths: [SynthType] = [.polyKeys, .subBass, .fmLead, .pluck]
        
        let scales: [[(String, Double)]] = [
            [("C4", 261.63), ("Eb4", 311.13), ("G4", 392.00), ("Bb4", 466.16)],
            [("C2", 65.41), ("Eb2", 77.78), ("F2", 87.31), ("G2", 98.00)],
            [("C5", 523.25), ("D5", 587.33), ("Eb5", 622.25), ("G5", 783.99)],
            [("C5", 523.25), ("Eb5", 622.25), ("G5", 783.99), ("Bb5", 932.33)]
        ]
        
        for i in 0..<4 {
            let scale = scales[i]
            var steps: [Step] = []
            for s in 0..<16 {
                let note = scale[s % scale.count]
                let on = (s % 2 == 0)
                steps.append(Step(id: s, isOn: on, noteName: note.0, frequency: note.1))
            }
            
            tracks.append(TrackModel(
                id: i + 5,
                name: swNames[i],
                isHardware: false,
                colorHex: swColors[i],
                synthType: swSynths[i],
                steps: steps
            ))
        }
    }
    
    private func bindMIDI() {
        let midi = MIDIManager.shared
        midi.onStart = { [weak self] in
            self?.start(externalClock: true)
        }
        midi.onStop = { [weak self] in
            self?.stop()
        }
        midi.onClockTick = { [weak self] in
            self?.tickStep()
        }
        midi.$bpm
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detectedBpm in
                self?.bpm = detectedBpm
            }
            .store(in: &cancellables)
    }
    
    public func togglePlay() {
        if isPlaying {
            stop()
        } else {
            start(externalClock: false)
        }
    }
    
    public func start(externalClock: Bool) {
        isPlaying = true
        currentStepIndex = 0
        if !externalClock {
            let interval = (60.0 / bpm) / 4.0 // 16th notes
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.tickStep()
            }
        }
    }
    
    public func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        currentStepIndex = 0
    }
    
    private func tickStep() {
        DispatchQueue.main.async {
            self.currentStepIndex = (self.currentStepIndex + 1) % 16
            let step = self.currentStepIndex
            
            // Trigger active notes on Tracks 5-8
            for tIdx in 0..<4 {
                let track = self.tracks[tIdx + 4]
                guard !track.isMuted, step < track.steps.count else { continue }
                let s = track.steps[step]
                if s.isOn {
                    AudioEngine.shared.triggerNote(
                        trackIndex: tIdx,
                        frequency: s.frequency,
                        velocity: Float(track.level / 127.0)
                    )
                }
            }
        }
    }
}
