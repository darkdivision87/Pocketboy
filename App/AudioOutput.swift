import AVFoundation
import PocketCore

/// Feeds the chip synth to the speaker through AVAudioEngine.
final class AudioOutput {
    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?

    init(synth: ChipSynth) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            if let first = buffers.first, let data = first.mData?.assumingMemoryBound(to: Float.self) {
                synth.render(data, frames: Int(frameCount))
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        node = source
    }

    func start() {
        if engine.isRunning { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            // Audio is optional; the app keeps working without it.
        }
    }

    func stop() {
        engine.pause()
    }
}
