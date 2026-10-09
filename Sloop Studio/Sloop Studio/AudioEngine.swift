import Foundation
import AVFoundation
import Combine

public enum SynthType: String, CaseIterable, Identifiable {
    case polyKeys = "Poly Keys"
    case subBass = "Sub / Acid Bass"
    case fmLead = "FM Lead & Bell"
    case pluck = "Percussive Pluck"
    
    public var id: String { rawValue }
}

public final class AudioEngine: ObservableObject {
    public static let shared = AudioEngine()
    
    public let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    
    // Auxiliary Synths for Tracks 5-8
    public private(set) var trackNodes: [AVAudioSourceNode] = []
    
    // Real-time audio generation state per track
    private struct TrackVoice {
        var phase: Double = 0.0
        var frequency: Double = 440.0
        var active: Bool = false
        var envelope: Double = 0.0
        var decay: Double = 0.8
        var synthType: SynthType = .polyKeys
        var cutoff: Double = 3000.0
        var resonance: Double = 1.5
        var level: Float = 0.8
        var pan: Float = 0.0
    }
    
    private var voices: [TrackVoice] = [
        TrackVoice(decay: 1.2, synthType: .polyKeys, cutoff: 4000, level: 0.85),
        TrackVoice(decay: 0.5, synthType: .subBass, cutoff: 1200, level: 0.9),
        TrackVoice(decay: 1.5, synthType: .fmLead, cutoff: 5000, level: 0.75),
        TrackVoice(decay: 0.25, synthType: .pluck, cutoff: 3500, level: 0.7)
    ]
    
    @Published public var isRunning: Bool = false
    @Published public var isUSBMonitoringActive: Bool = false
    
    private init() {
        setupAudioSession()
        setupEngine()
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredSampleRate(44100)
            try session.setPreferredIOBufferDuration(128.0 / 44100.0) // ~2.9ms ultra-low latency
            try session.setActive(true)
        } catch {
            print("AVAudioSession error: \(error)")
        }
        #endif
    }
    
    private func generateSample(voice: inout TrackVoice, sampleRate: Double) -> Float {
        guard voice.active && voice.envelope > 0.001 else {
            voice.active = false
            return 0.0
        }
        
        let p = voice.phase
        var raw: Float = 0.0
        switch voice.synthType {
        case .polyKeys:
            raw = Float((p / .pi) - 1.0)
        case .subBass:
            raw = p < .pi ? 0.7 : -0.7
        case .fmLead:
            let mod = sin(p * 2.0) * 3.0
            raw = Float(sin(p + mod))
        case .pluck:
            let tri = 2.0 * abs(2.0 * (p / (2.0 * .pi) - floor(p / (2.0 * .pi) + 0.5))) - 1.0
            raw = Float(tri)
        }
        
        let sample = raw * Float(voice.envelope) * voice.level
        let phaseInc = 2.0 * .pi * voice.frequency / sampleRate
        voice.phase += phaseInc
        if voice.phase >= 2.0 * .pi { voice.phase -= 2.0 * .pi }
        voice.envelope *= (1.0 - (1.0 / (sampleRate * voice.decay)))
        return sample
    }

    private func setupEngine() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        
        let sampleRate = 44100.0
        
        // Build 4 native DSP source nodes for Tracks 5-8
        for trackIndex in 0..<4 {
            let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self = self else { return noErr }
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                var v = self.voices[trackIndex]
                
                for frame in 0..<Int(frameCount) {
                    let sample = self.generateSample(voice: &v, sampleRate: sampleRate)
                    for buffer in ablPointer {
                        if let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) {
                            ptr[frame] = sample
                        }
                    }
                }
                
                self.voices[trackIndex] = v
                return noErr
            }
            
            engine.attach(sourceNode)
            engine.connect(sourceNode, to: mixer, format: nil)
            trackNodes.append(sourceNode)
        }
        
        start()
    }
    
    public func start() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            DispatchQueue.main.async { self.isRunning = true }
        } catch {
            print("AVAudioEngine start failed: \(error)")
        }
    }
    
    public func triggerNote(trackIndex: Int, frequency: Double, velocity: Float) {
        guard trackIndex >= 0 && trackIndex < 4 else { return }
        voices[trackIndex].frequency = frequency
        voices[trackIndex].envelope = Double(velocity)
        voices[trackIndex].active = true
    }
    
    public func updateTrack(trackIndex: Int, synthType: SynthType? = nil, cutoff: Double? = nil, level: Float? = nil, pan: Float? = nil) {
        guard trackIndex >= 0 && trackIndex < 4 else { return }
        if let st = synthType { voices[trackIndex].synthType = st }
        if let co = cutoff { voices[trackIndex].cutoff = co }
        if let lv = level { voices[trackIndex].level = lv }
        if let p = pan { voices[trackIndex].pan = p }
    }
}
