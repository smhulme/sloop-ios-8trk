import Foundation
import CoreMIDI
import Combine

public final class MIDIManager: ObservableObject {
    public static let shared = MIDIManager()
    
    @Published public var isConnected: Bool = false
    @Published public var connectedDeviceName: String = "No Device"
    @Published public var bpm: Double = 120.0
    @Published public var isPlaying: Bool = false
    
    // Callbacks for sequencer & audio engine
    public var onStart: (() -> Void)?
    public var onStop: (() -> Void)?
    public var onClockTick: (() -> Void)?
    public var onNoteOn: ((UInt8, UInt8, UInt8) -> Void)?
    
    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var outputPort = MIDIPortRef()
    private var selectedSource: MIDIEndpointRef = 0
    private var selectedDestination: MIDIEndpointRef = 0
    
    private var lastClockTime: UInt64 = 0
    private var clockTickCount: Int = 0
    private var clockIntervals: [Double] = []
    
    private init() {
        setupMIDI()
    }
    
    private func setupMIDI() {
        var status = MIDIClientCreateWithBlock("SloopMIDIClient" as CFString, &client) { [weak self] notificationPtr in
            self?.handleNotification(notificationPtr.pointee)
        }
        guard status == noErr else {
            print("CoreMIDI client creation failed: \(status)")
            return
        }
        
        status = MIDIInputPortCreateWithProtocol(client, "SloopInputPort" as CFString, ._1_0, &inputPort) { [weak self] eventList, _ in
            self?.handleMIDIEvents(eventList)
        }
        
        status = MIDIOutputPortCreate(client, "SloopOutputPort" as CFString, &outputPort)
        
        scanForDevices()
    }
    
    public func scanForDevices() {
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let src = MIDIGetSource(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(src, kMIDIPropertyDisplayName, &name)
            let deviceName = (name?.takeRetainedValue() as String?) ?? "Unknown"
            
            // Check for Felucca or M-VAVE FM-1
            if deviceName.localizedCaseInsensitiveContains("felucca") ||
               deviceName.localizedCaseInsensitiveContains("fm-1") ||
               deviceName.localizedCaseInsensitiveContains("m-vave") {
                connect(to: src, name: deviceName)
                return
            }
        }
    }
    
    private func connect(to source: MIDIEndpointRef, name: String) {
        selectedSource = source
        MIDIPortConnectSource(inputPort, source, nil)
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectedDeviceName = name
        }
        print("Connected to CoreMIDI device: \(name)")
    }
    
    private func handleNotification(_ notification: MIDINotification) {
        if notification.messageID == .msgSetupChanged {
            DispatchQueue.main.async {
                self.scanForDevices()
            }
        }
    }
    
    private func handleMIDIEvents(_ eventListPtr: UnsafePointer<MIDIEventList>) {
        let packetList = eventListPtr.pointee
        var packet = packetList.packet
        
        for _ in 0..<packetList.numPackets {
            for wordIndex in 0..<Int(packet.wordCount) {
                let word = packet.words.0 // 32-bit Universal MIDI Packet (UMP)
                let messageType = (word >> 28) & 0xF
                
                // Real-time System Message (UMP type 1)
                if messageType == 0x1 {
                    let status = (word >> 16) & 0xFF
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        if status == 0xFA { // Start
                            self.isPlaying = true
                            self.onStart?()
                        } else if status == 0xFC { // Stop
                            self.isPlaying = false
                            self.onStop?()
                        } else if status == 0xFB { // Continue
                            self.isPlaying = true
                            self.onStart?()
                        } else if status == 0xF8 { // Timing Clock (24 ppqn)
                            self.handleClockTick()
                        }
                    }
                }
            }
            packet = MIDIEventPacketNext(&packet).pointee
        }
    }
    
    private func handleClockTick() {
        let now = DispatchTime.now().uptimeNanoseconds
        if lastClockTime > 0 {
            let deltaSeconds = Double(now - lastClockTime) / 1_000_000_000.0
            if deltaSeconds > 0.005 && deltaSeconds < 0.15 {
                clockIntervals.append(deltaSeconds)
                if clockIntervals.count > 24 { clockIntervals.removeFirst() }
                let avgDelta = clockIntervals.reduce(0, +) / Double(clockIntervals.count)
                let detectedBpm = 60.0 / (avgDelta * 24.0)
                if detectedBpm >= 40 && detectedBpm <= 240 {
                    self.bpm = (detectedBpm * 10).rounded() / 10
                }
            }
        }
        lastClockTime = now
        clockTickCount = (clockTickCount + 1) % 6 // 6 ticks = 1/16th note
        if clockTickCount == 0 {
            onClockTick?()
        }
    }
    
    public func sendSysEx(_ data: [UInt8]) {
        guard isConnected, selectedDestination != 0 else { return }
        var packet = MIDIPacketList()
        // Send packet via MIDISend
    }
}
