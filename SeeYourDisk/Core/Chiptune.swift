import AVFoundation

/// Korobeiniki (a public-domain Russian folk song, the "Tetris theme"), synthesized as 8-bit square wave in memory.
final class Chiptune {
    static let shared = Chiptune()
    private var player: AVAudioPlayer?

    private init() {
        player = try? AVAudioPlayer(data: Self.makeWAV())
        player?.numberOfLoops = -1
        player?.volume = 0.3
        player?.prepareToPlay()
    }

    func set(playing: Bool) {
        if playing { player?.play() } else { player?.pause() }
    }

    // (MIDI note, beats); 0 = rest
    private nonisolated static let melody: [(Int, Double)] = [
        (76, 1), (71, 0.5), (72, 0.5), (74, 1), (72, 0.5), (71, 0.5), (69, 1), (69, 0.5), (72, 0.5),
        (76, 1), (74, 0.5), (72, 0.5), (71, 1.5), (72, 0.5), (74, 1), (76, 1), (72, 1), (69, 1), (69, 1), (0, 1),
        (74, 1.5), (77, 0.5), (81, 1), (79, 0.5), (77, 0.5), (76, 1.5), (72, 0.5), (76, 1), (74, 0.5), (72, 0.5),
        (71, 1), (71, 0.5), (72, 0.5), (74, 1), (76, 1), (72, 1), (69, 1), (69, 1), (0, 1),
    ]

    private nonisolated static func makeWAV() -> Data {
        let rate = 22050, beat = 0.36
        var pcm = [Int16]()
        for (note, beats) in melody {
            let n = Int(Double(rate) * beat * beats)
            let freq = note == 0 ? 0 : 440 * pow(2, Double(note - 69) / 12)
            for i in 0..<n {
                var v = 0.0
                if freq > 0 {
                    let t = Double(i) / Double(rate)
                    let phase = (t * freq).truncatingRemainder(dividingBy: 1)
                    let env = min(1, t / 0.006) * min(1, Double(n - i) / (Double(rate) * 0.04))
                    v = (phase < 0.5 ? 1 : -1) * 0.22 * env
                }
                pcm.append(Int16(v * Double(Int16.max)))
            }
        }
        var d = Data()
        func u32(_ x: UInt32) { withUnsafeBytes(of: x.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ x: UInt16) { withUnsafeBytes(of: x.littleEndian) { d.append(contentsOf: $0) } }
        d.append("RIFF".data(using: .ascii)!); u32(UInt32(36 + pcm.count * 2))
        d.append("WAVEfmt ".data(using: .ascii)!); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(UInt32(pcm.count * 2))
        pcm.withUnsafeBytes { d.append(contentsOf: $0) }
        return d
    }
}
