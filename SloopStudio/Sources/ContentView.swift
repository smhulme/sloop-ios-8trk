import SwiftUI

public struct ContentView: View {
    @StateObject private var seq = SequencerModel.shared
    @StateObject private var midi = MIDIManager.shared
    @StateObject private var audio = AudioEngine.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Top Header Transport Bar
                headerView
                
                // Track Selector Bar (8 Tracks)
                trackSelectorBar
                
                // Main Content (Selected Track Editor or 8-Channel Mixer)
                ScrollView {
                    VStack(spacing: 20) {
                        if seq.selectedTrackIndex < 4 {
                            hardwareTrackView(track: seq.tracks[seq.selectedTrackIndex])
                        } else {
                            softwareTrackView(trackIndex: seq.selectedTrackIndex)
                        }
                        
                        Divider().background(Color(white: 0.2))
                        
                        // 8-Track Mixer Desk
                        mixerDeskView
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Text("SLOOP")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            Text("STUDIO 8-TRK")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            Spacer()
            
            // Transport Controls
            Button(action: { seq.togglePlay() }) {
                HStack(spacing: 6) {
                    Image(systemName: seq.isPlaying ? "stop.fill" : "play.fill")
                    Text(seq.isPlaying ? "STOP" : "PLAY")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(seq.isPlaying ? Color.red : Color(white: 0.15))
                .foregroundColor(.white)
                .cornerRadius(4)
            }
            
            Text("\(Int(seq.bpm)) BPM")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
            
            // MIDI Status
            HStack(spacing: 4) {
                Circle()
                    .fill(midi.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(midi.isConnected ? midi.connectedDeviceName : "NO FM-1")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(midi.isConnected ? .green : .gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(white: 0.1))
            .cornerRadius(4)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Track Selector Bar
    private var trackSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<8) { idx in
                    let track = seq.tracks[idx]
                    let isSel = (seq.selectedTrackIndex == idx)
                    Button(action: { seq.selectedTrackIndex = idx }) {
                        HStack(spacing: 6) {
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(width: 20, height: 20)
                                .background(Color(hex: track.colorHex))
                                .foregroundColor(.black)
                                .cornerRadius(3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.name)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(isSel ? .white : .gray)
                                Text(track.isHardware ? "HW" : "NATIVE")
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color(hex: track.colorHex))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSel ? Color(white: 0.2) : Color(white: 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSel ? Color(hex: track.colorHex) : Color.clear, lineWidth: 1.5)
                        )
                        .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Hardware Track Info View
    private func hardwareTrackView(track: TrackModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HARDWARE TRACK \(track.id) (M-VAVE FM-1)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: track.colorHex))
            Text("This track runs directly on the M-VAVE FM-1 DSP engine. Use the physical FM-1 dials and keys or SysEx commands to control synthesis and patterns.")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.06))
        .cornerRadius(8)
    }
    
    // MARK: - Software Track Step Sequencer & Sound View
    private func softwareTrackView(trackIndex: Int) -> some View {
        let track = seq.tracks[trackIndex]
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("NATIVE SYNTH TRACK \(track.id)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: track.colorHex))
                Spacer()
                Picker("Engine", selection: Binding(
                    get: { seq.tracks[trackIndex].synthType },
                    set: { newVal in
                        seq.tracks[trackIndex].synthType = newVal
                        AudioEngine.shared.updateTrack(trackIndex: trackIndex - 4, synthType: newVal)
                    }
                )) {
                    ForEach(SynthType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // 16-Step Sequencer Grid
            VStack(alignment: .leading, spacing: 6) {
                Text("STEP SEQUENCER")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(0..<16) { stepIdx in
                        let step = track.steps[stepIdx]
                        let isCurrent = (seq.currentStepIndex == stepIdx && seq.isPlaying)
                        
                        Button(action: {
                            seq.tracks[trackIndex].steps[stepIdx].isOn.toggle()
                        }) {
                            VStack(spacing: 2) {
                                Text("\(stepIdx + 1)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                Text(step.noteName)
                                    .font(.system(size: 8, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(step.isOn ? Color(hex: track.colorHex) : Color(white: 0.12))
                            .foregroundColor(step.isOn ? .black : .gray)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isCurrent ? Color.white : Color.clear, lineWidth: 2)
                            )
                            .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(white: 0.06))
        .cornerRadius(8)
    }
    
    // MARK: - 8-Channel Mixer Desk
    private var mixerDeskView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("8-CHANNEL MIXING DESK")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<8) { idx in
                        mixerStrip(trackIndex: idx)
                    }
                }
            }
        }
    }
    
    private func mixerStrip(trackIndex: Int) -> some View {
        let track = seq.tracks[trackIndex]
        let isSel = (seq.selectedTrackIndex == trackIndex)
        
        return VStack(spacing: 8) {
            Text("\(track.id)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: track.colorHex))
            
            Text(track.name)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 60)
                .lineLimit(1)
            
            // Level Slider (Vertical representation)
            Slider(value: Binding(
                get: { seq.tracks[trackIndex].level },
                set: { val in
                    seq.tracks[trackIndex].level = val
                    if trackIndex >= 4 {
                        AudioEngine.shared.updateTrack(trackIndex: trackIndex - 4, level: Float(val / 127.0))
                    }
                }
            ), in: 0...127)
            .rotationEffect(.degrees(-90))
            .frame(width: 100, height: 100)
            
            Text("\(Int(track.level))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Button(action: {
                seq.tracks[trackIndex].isMuted.toggle()
            }) {
                Text(track.isMuted ? "MUTED" : "MUTE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(track.isMuted ? Color.red : Color(white: 0.15))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
        }
        .padding(8)
        .frame(width: 76)
        .background(Color(white: isSel ? 0.12 : 0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSel ? Color(hex: track.colorHex) : Color(white: 0.15), lineWidth: 1)
        )
        .cornerRadius(6)
    }
}

// Color hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
