import SwiftUI
import AppKit

struct ScanView: View {
    @Bindable var model: AppModel
    @FocusState private var focused: Bool
    @State private var game = Tetris()
    @State private var running = false          // false = not started or paused
    @AppStorage("gameMuted") private var muted = false

    private var playing: Bool { model.gameActive && running && !game.over }

    var body: some View {
        VStack(spacing: 16) {
            progressBlock
            if model.gameActive {
                TetrisBoard(game: game, message: overlayMessage)
                    .aspectRatio(0.5, contentMode: .fit)
                    .frame(maxHeight: 520)
                    .onTapGesture { running = true }
                HStack(spacing: 16) {
                    Text("Score \(game.score)").monospacedDigit()
                    Text("Lines \(game.lines)").monospacedDigit()
                    Button { muted.toggle() } label: {
                        Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }
                    .buttonStyle(.borderless)
                    .help(muted ? "Turn sound on" : "Turn sound off")
                    if game.over { Button("Play again") { game = Tetris(); running = true } }
                }
                Text("← → move · ↑ rotate · ↓ soft drop · Space drop / pause")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ScanDie(progress: model.progress)
                    .frame(maxWidth: 420, maxHeight: 260)
            }
            if model.phase == .done {
                Button("Scan complete — show results") { model.gameActive = false }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            } else if !model.gameActive {
                Button { model.gameActive = true } label: {
                    Label("Play Tetris while you wait", systemImage: "gamecontroller")
                }
            } else {
                Button("Stop playing") { model.gameActive = false; running = false }
            }
            Text("Everything happens on this Mac. Nothing leaves it.")
                .font(.callout).foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        // Never let pieces pile up unseen: pause when the window loses focus or gets covered.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in running = false }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in running = false }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)) { n in
            if let w = n.object as? NSWindow, !w.occlusionState.contains(.visible) { running = false }
        }
        .onKeyPress(phases: [.down, .repeat]) { press in
            guard model.gameActive else { return .ignored }
            if press.key == .space, !running { running = true; return .handled }
            guard running else { return .ignored }
            switch press.key {
            case .leftArrow: game.move(-1)
            case .rightArrow: game.move(1)
            case .downArrow: game.softDrop()
            case .upArrow: game.rotate()
            case .space: game.hardDrop()
            case .escape: running = false
            default: return .ignored
            }
            return .handled
        }
        .task(id: playing) {
            guard playing else { return }
            while !Task.isCancelled {
                let delay = max(0.08, 0.6 - Double(game.lines / 5) * 0.05)
                try? await Task.sleep(for: .seconds(delay))
                game.tick()
            }
        }
        .onChange(of: playing) { _, on in Chiptune.shared.set(playing: on && !muted) }
        .onChange(of: muted) { _, m in Chiptune.shared.set(playing: playing && !m) }
        .onDisappear { Chiptune.shared.set(playing: false) }
    }

    private var overlayMessage: LocalizedStringKey? {
        if game.over { return "Game over" }
        if !running { return game.score == 0 && game.lines == 0 ? "Press Space to start" : "Paused — press Space" }
        return nil
    }

    private var progressBlock: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Scanning your disk…").font(.title2.weight(.semibold))
                Spacer()
                Text(verbatim: "≈ \(Int(model.progress * 100))%").font(.title2.monospacedDigit().weight(.bold))
            }
            ProgressView(value: model.progress)
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                HStack {
                    Text("\(model.scannedFiles.formatted()) files · \(formatBytes(model.scannedBytes))")
                    Spacer()
                    Text(verbatim: eta(now: tl.date))
                }
                .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 520)
    }

    private func eta(now: Date) -> String {
        guard model.phase == .scanning else { return "" }
        let elapsed = now.timeIntervalSince(model.scanStart)
        guard elapsed > 4, model.progress > 0.03 else { return String(localized: "Estimating time…") }
        let left = Int(elapsed * (1 - model.progress) / model.progress)
        let text = Duration.seconds(left).formatted(.units(allowed: [.hours, .minutes, .seconds],
                                                           width: .abbreviated, maximumUnitCount: 2))
        return String(localized: "About \(text) left")
    }
}

/// Blocks grow in one by one from their centre, keep gently reshuffling, and light up with progress.
struct ScanDie: View {
    let progress: Double
    @State private var start = Date()
    private let kinds: [NodeKind] = [.systemData, .apps, .documents, .developer, .appData, .media, .system, .other]
    private let base: [Double] = [22, 15, 12, 10, 8, 7, 6, 5, 4, 3.5, 3, 2.5, 2, 1.5, 1.2, 1]

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let age = tl.date.timeIntervalSince(start)
            Canvas { ctx, size in
                let area = CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6)
                // sizes breathe, so the whole layout slowly rearranges
                let values = base.enumerated().map { i, v in v * (1 + 0.4 * sin(t * 0.6 + Double(i) * 1.7)) }
                let rects = Treemap.layout(values: values, in: area)
                let lit = progress * Double(rects.count)
                for (i, r) in rects.enumerated() {
                    let appear = min(1, max(0, (age - Double(i) * 0.14) / 0.55))
                    guard appear > 0 else { continue }
                    let eased = 1 - pow(1 - appear, 3)
                    let block = r.insetBy(dx: 2, dy: 2)
                    let scaled = CGRect(x: block.midX - block.width * eased / 2, y: block.midY - block.height * eased / 2,
                                        width: block.width * eased, height: block.height * eased)
                    let color = Palette.color(kinds[i % kinds.count])
                    let on = min(1, max(0, lit - Double(i)))
                    let charging = on > 0 && on < 1
                    let pulse = charging ? 0.7 + 0.3 * sin(t * 8) : 1
                    DieStyle.block(&ctx, rect: scaled, color: color,
                                   strength: (0.25 + 0.9 * on * pulse) * eased, radius: 8)
                }
            }
        }
    }
}

// MARK: - Tetris on the die

struct Tetris {
    static let cols = 10, rows = 20
    private static let shapes: [[(Int, Int)]] = [
        [(0, 1), (1, 1), (2, 1), (3, 1)],   // I
        [(1, 0), (2, 0), (1, 1), (2, 1)],   // O
        [(1, 0), (0, 1), (1, 1), (2, 1)],   // T
        [(1, 0), (2, 0), (0, 1), (1, 1)],   // S
        [(0, 0), (1, 0), (1, 1), (2, 1)],   // Z
        [(0, 0), (0, 1), (1, 1), (2, 1)],   // J
        [(2, 0), (0, 1), (1, 1), (2, 1)],   // L
    ]
    static let kinds: [NodeKind] = [.systemData, .apps, .developer, .documents, .media, .appData, .system]

    var board = [[Int]](repeating: [Int](repeating: -1, count: cols), count: rows)
    var cells: [(Int, Int)] = []
    var type = 0
    var px = 3, py = 0
    var score = 0, lines = 0
    var over = false

    init() { spawn() }

    private func fits(_ c: [(Int, Int)], _ x: Int, _ y: Int) -> Bool {
        for (cx, cy) in c {
            let bx = cx + x, by = cy + y
            if bx < 0 || bx >= Self.cols || by >= Self.rows { return false }
            if by >= 0 && board[by][bx] >= 0 { return false }
        }
        return true
    }

    private mutating func spawn() {
        type = Int.random(in: 0..<Self.shapes.count)
        cells = Self.shapes[type]; px = 3; py = 0
        if !fits(cells, px, py) { over = true }
    }

    mutating func move(_ dx: Int) { if !over, fits(cells, px + dx, py) { px += dx } }

    mutating func rotate() {
        guard !over, type != 1 else { return }
        let n = type == 0 ? 3 : 2
        let r = cells.map { (n - $0.1, $0.0) }
        for k in [0, -1, 1, -2, 2] where fits(r, px + k, py) { cells = r; px += k; return }
    }

    mutating func softDrop() {
        guard !over else { return }
        if fits(cells, px, py + 1) { py += 1; score += 1 } else { lock() }
    }

    mutating func hardDrop() {
        guard !over else { return }
        while fits(cells, px, py + 1) { py += 1; score += 2 }
        lock()
    }

    mutating func tick() {
        guard !over else { return }
        if fits(cells, px, py + 1) { py += 1 } else { lock() }
    }

    private mutating func lock() {
        for (cx, cy) in cells where cy + py >= 0 { board[cy + py][cx + px] = type }
        let kept = board.filter { $0.contains(-1) }
        let cleared = Self.rows - kept.count
        if cleared > 0 {
            board = [[Int]](repeating: [Int](repeating: -1, count: Self.cols), count: cleared) + kept
            lines += cleared
            score += [0, 100, 300, 500, 800][cleared]
        }
        spawn()
    }

    var ghostY: Int {
        var y = py
        while fits(cells, px, y + 1) { y += 1 }
        return y
    }
}

struct TetrisBoard: View {
    let game: Tetris
    let message: LocalizedStringKey?

    var body: some View {
        Canvas { ctx, size in
            let cw = size.width / CGFloat(Tetris.cols), ch = size.height / CGFloat(Tetris.rows)
            func cell(_ x: Int, _ y: Int, _ type: Int, alpha: Double) {
                let color = Palette.color(Tetris.kinds[type])
                let r = CGRect(x: CGFloat(x) * cw + 1, y: CGFloat(y) * ch + 1, width: cw - 2, height: ch - 2)
                DieStyle.block(&ctx, rect: r, color: color, strength: 1.3 * alpha, radius: 4, horizontal: y % 2 == 0)
            }
            for y in 0..<Tetris.rows {
                for x in 0..<Tetris.cols where game.board[y][x] >= 0 { cell(x, y, game.board[y][x], alpha: 1) }
            }
            if !game.over {
                let gy = game.ghostY
                for (cx, cy) in game.cells { cell(cx + game.px, cy + gy, game.type, alpha: 0.25) }
                for (cx, cy) in game.cells { cell(cx + game.px, cy + game.py, game.type, alpha: 1) }
            }
        }
        .overlay {
            if let message {
                Text(message).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .background(DieStyle.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.10)))
    }
}
