import AVFoundation

@MainActor
final class CicadaSoundEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let speedControl = AVAudioUnitVarispeed()
    private let wahFilter = AVAudioUnitEQ(numberOfBands: 1)
    private let lowFormant = AVAudioUnitEQ(numberOfBands: 1)
    private var isReady = false

    init() {
        prepare()
    }

    private func prepare() {
        let sampleRate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * 2)),
              let samples = buffer.floatChannelData?[0] else { return }

        buffer.frameLength = buffer.frameCapacity
        var smoothedSample = 0.0
        for frame in 0..<Int(buffer.frameLength) {
            let time = Double(frame) / sampleRate
            let phase = (time * 70).truncatingRemainder(dividingBy: 1)

            // The measured recording uses broadband stick-slip energy, then
            // concentrates nearly all of it into two acoustic formants.
            var stickSlip = 0.0
            for harmonic in 1...30 {
                let rolloff = pow(Double(harmonic), 1.18)
                stickSlip += sin(2 * .pi * phase * Double(harmonic)) / rolloff
            }
            stickSlip = tanh(stickSlip * 1.42)

            // There are deliberately no fixed high oscillators: they caused
            // the whistle that appeared when varispeed increased.
            let pulse = 0.68 + 0.25 * sin(2 * .pi * 30 * time)
            let rawSample = tanh(stickSlip * pulse)

            // One-pole smoothing also catches short digital spikes before
            // they reach the resonant filters.
            smoothedSample += 0.68 * (rawSample - smoothedSample)
            samples[frame] = Float(smoothedSample * 0.28)
        }

        engine.attach(player)
        engine.attach(speedControl)
        engine.attach(wahFilter)
        engine.attach(lowFormant)
        engine.connect(player, to: speedControl, format: format)
        engine.connect(speedControl, to: wahFilter, format: format)
        engine.connect(
            wahFilter,
            to: [AVAudioConnectionPoint(node: lowFormant, bus: 0)],
            fromBus: 0,
            format: format
        )
        engine.connect(lowFormant, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0

        let wahBand = wahFilter.bands[0]
        wahBand.filterType = .bandPass
        wahBand.frequency = 900
        wahBand.bandwidth = 2.35
        wahBand.bypass = false

        // One broad cavity covers both measured vocal regions without a
        // second narrow resonator ringing like a radio carrier.
        let voiceBand = lowFormant.bands[0]
        voiceBand.filterType = .bandPass
        voiceBand.frequency = 1_645
        voiceBand.bandwidth = 1.05
        voiceBand.bypass = false
        lowFormant.globalGain = 9.5

        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // The app still works visually if another audio session owns the output.
        }
        #endif

        player.scheduleBuffer(buffer, at: nil, options: .loops)
        do {
            try engine.start()
            player.play()
            isReady = true
        } catch {
            isReady = false
        }
    }

    func update(rotationsPerSecond rps: Double, phase: Double, activity: Double) {
        guard isReady else { return }
        let strength = min(max(activity, 0), 1)
        let rawOpenness = 0.5 + 0.5 * sin(phase - 0.7)
        let openness = rawOpenness * rawOpenness * (3 - 2 * rawOpenness)
        // Loudness follows energy only. The once-per-turn "wah" now comes
        // from an actual spectral sweep, not from motor-like volume pulsing.
        engine.mainMixerNode.outputVolume = Float(pow(strength, 0.48))

        let fundamental = min(max(42 + rps * 10.5, 40), 130)
        let phaseBend = 1 + 0.027 * sin(phase + 0.9) * min(strength * 1.6, 1)
        speedControl.rate = Float(min(max(fundamental / 70 * phaseBend, 0.60), 1.95))

        // One measured "wah" per physical revolution. The sweep range comes
        // from the reference implementation; the peaks come from its audio.
        let sweep = 760 + 520 * strength
            + (430 + 330 * strength) * sin(phase - 0.7)
        wahFilter.bands[0].frequency = Float(min(max(sweep, 320), 2_100))
        wahFilter.bands[0].bandwidth = Float(2.05 + 0.72 * openness)

        // The sweep changes the single cavity from "呜" into "哇/啊";
        // slightly more closed-state body keeps the sound substantial.
        lowFormant.globalGain = Float(9.0 + 1.5 * (1 - openness))

    }

    func silence() {
        engine.mainMixerNode.outputVolume = 0
    }
}
