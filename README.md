# SloopStudio (`sloop-ios-8trk`)

A native iOS/iPadOS 8-track workstation and companion app for the **M-VAVE FM-1** running [SLOOP](https://github.com/isod89/sloop-fm1) firmware.

Built with **100% Native Swift, SwiftUI, CoreMIDI, and AVAudioEngine**.

---

## Architecture

* **Tracks 1–4 (Hardware FM-1):** 
  - Monitored and synchronized via **Apple CoreMIDI**.
  - Direct hardware control via standard MIDI messages and Felucca/SLOOP SysEx protocol.
* **Tracks 5–8 (Native Apple DSP Engines):**
  - Generated in real time via native `AVAudioSourceNode` DSP callbacks running on `AVAudioEngine`.
  - **Track 5 (Purple):** Polyphonic Sawtooth Synth (Keys & Chords)
  - **Track 6 (Cyan):** Analog Sub/Acid Bass (Square wave with resonance)
  - **Track 7 (Pink):** 2-Operator FM Bell & Lead
  - **Track 8 (Lime):** Percussive Pluck & Arp
* **Clock & Transport Synchronization:**
  - Synchronizes to the hardware FM-1's transport (`PLAY`, `REC`) and real-time clock (`0xF8`, `0xFA`, `0xFC`) via low-latency CoreMIDI.
  - Can also run standalone using the built-in transport bar.
* **Integrated 8-Track Mixer Desk:**
  - Real-time touch sliders for level, panning, and muting across all 8 tracks.

---

## Opening and Running the Project

1. Open the project in **Xcode**:
   - Double-click `Package.swift` or open the `sloop-ios-8trk` directory in Xcode.
2. Select your target device (iPad, iPhone, or Simulator).
3. Connect your M-VAVE FM-1 via USB-C (or Lightning-to-USB Adapter).
4. Press **Run (Cmd+R)** to launch SloopStudio.
