import AVFoundation

// MARK: - VAD Result

/// The result of processing an audio buffer through voice activity detection.
enum VADResult: Sendable, Equatable {
    /// Speech was detected with the given RMS energy level.
    case speech(energy: Float)

    /// Silence was detected; includes how long silence has persisted.
    case silence(duration: TimeInterval)

    /// Silence has exceeded the configured timeout threshold.
    case silenceTimeout
}

// MARK: - Voice Activity Detector Protocol

/// A voice activity detector that classifies audio buffers as speech or silence.
protocol VoiceActivityDetector: Sendable {
    /// Process an audio buffer and return the current voice activity state.
    mutating func processBuffer(_ buffer: AVAudioPCMBuffer) -> VADResult

    /// Reset all internal tracking state.
    mutating func reset()
}
