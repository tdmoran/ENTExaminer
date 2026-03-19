import Accelerate
import AVFoundation

// MARK: - Energy-Based Voice Activity Detector

/// A lightweight, energy-based voice activity detector that classifies audio buffers
/// as speech or silence by computing RMS energy and tracking silence duration.
///
/// This struct is `Sendable` but uses internal mutation to track silence timing.
/// Callers must use it with `mutating` methods or wrap it appropriately.
struct EnergyVAD: VoiceActivityDetector, Sendable {
    // MARK: - Configuration

    /// How long silence must persist (in seconds) before returning `.silenceTimeout`.
    let silenceThreshold: TimeInterval

    /// RMS energy below this value is classified as silence.
    let energyThreshold: Float

    // MARK: - Internal State

    /// Timestamp when silence began, or `nil` if speech is active.
    private var silenceStartTime: Date?

    /// Whether we have detected any speech in this session.
    private var hasDetectedSpeech: Bool = false

    // MARK: - Initialization

    init(silenceThreshold: TimeInterval = 1.5, energyThreshold: Float = 0.01) {
        self.silenceThreshold = silenceThreshold
        self.energyThreshold = energyThreshold
    }

    // MARK: - VoiceActivityDetector

    mutating func processBuffer(_ buffer: AVAudioPCMBuffer) -> VADResult {
        let energy = Self.computeRMSEnergy(buffer)

        if energy >= energyThreshold {
            // Speech detected
            hasDetectedSpeech = true
            silenceStartTime = nil
            return .speech(energy: energy)
        }

        // Below threshold — silence
        let now = Date()

        guard hasDetectedSpeech else {
            // No speech yet; don't start the silence timer until after first speech
            return .silence(duration: 0)
        }

        let silenceStart: Date
        if let existing = silenceStartTime {
            silenceStart = existing
        } else {
            silenceStartTime = now
            silenceStart = now
        }

        let silenceDuration = now.timeIntervalSince(silenceStart)

        if silenceDuration >= silenceThreshold {
            return .silenceTimeout
        }

        return .silence(duration: silenceDuration)
    }

    mutating func reset() {
        silenceStartTime = nil
        hasDetectedSpeech = false
    }

    // MARK: - Audio Analysis

    /// Compute the RMS energy of a PCM buffer using vDSP for efficiency.
    static func computeRMSEnergy(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let floatData = buffer.floatChannelData?[0] else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        var rms: Float = 0
        vDSP_rmsqv(floatData, 1, &rms, vDSP_Length(frameCount))
        return rms
    }

    /// Compute per-band audio levels for waveform visualization.
    ///
    /// Divides the buffer's samples into `bands` equal segments and computes
    /// the RMS energy of each, normalized to 0.0-1.0 using logarithmic scaling.
    ///
    /// - Parameters:
    ///   - buffer: The audio buffer to analyze.
    ///   - bands: The number of frequency bands to produce (default 32).
    /// - Returns: An array of `bands` float values, each in the range 0.0-1.0.
    static func computeAudioLevels(_ buffer: AVAudioPCMBuffer, bands: Int = 32) -> [Float] {
        guard let floatData = buffer.floatChannelData?[0] else {
            return [Float](repeating: 0, count: bands)
        }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0, bands > 0 else {
            return [Float](repeating: 0, count: bands)
        }

        let samplesPerBand = max(1, frameCount / bands)
        var levels = [Float](repeating: 0, count: bands)

        for band in 0..<bands {
            let start = band * samplesPerBand
            let end = min(start + samplesPerBand, frameCount)
            let count = end - start
            guard count > 0 else { continue }

            var bandRMS: Float = 0
            vDSP_rmsqv(floatData.advanced(by: start), 1, &bandRMS, vDSP_Length(count))

            // Logarithmic scaling: map -60dB..0dB to 0.0..1.0
            let db = 20 * log10(max(bandRMS, 1e-7))
            let normalized = max(0, min(1, (db + 60) / 60))
            levels[band] = normalized
        }

        return levels
    }

    /// Compute a single normalized audio level (0.0-1.0) from a buffer's RMS energy.
    static func computeNormalizedLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        let rms = computeRMSEnergy(buffer)
        let db = 20 * log10(max(rms, 1e-7))
        return max(0, min(1, (db + 60) / 60))
    }
}
