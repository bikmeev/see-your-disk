import Foundation

nonisolated struct LargeFile: Sendable {
    let url: URL
    let size: Int64
}

/// Thread-safe counters shared by all scanning tasks. Everything stays local: only FileManager reads.
nonisolated final class ScanContext: @unchecked Sendable {
    private let lock = NSLock()
    private var files = 0
    private var bytes: Int64 = 0
    private var skippedDirs = 0
    private var large: [LargeFile] = []

    func add(files n: Int, bytes b: Int64) {
        lock.lock(); files += n; bytes += b; lock.unlock()
    }
    func skip() { lock.lock(); skippedDirs += 1; lock.unlock() }
    func addLarge(_ f: LargeFile) { lock.lock(); large.append(f); lock.unlock() }

    func snapshot() -> (files: Int, bytes: Int64, skipped: Int) {
        lock.lock(); defer { lock.unlock() }
        return (files, bytes, skippedDirs)
    }
    func largeFiles() -> [LargeFile] {
        lock.lock(); defer { lock.unlock() }
        return large
    }
}

nonisolated struct ScanOutput: Sendable {
    let root: FileNode
    let large: [LargeFile]
    let skipped: Int
}

nonisolated enum DiskScanner {
    static let largeFileThreshold: Int64 = 500 * 1024 * 1024
    private static let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey,
                                                 .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]

    /// Scans Home, Applications and the system folders (read-only entitlements), then adds one block
    /// for whatever on the volume no folder explains (snapshots, metadata).
    static func scan(ctx: ScanContext, volume: VolumeInfo?) async -> ScanOutput {
        let home = realHomeURL()
        func scanRoot(_ path: String, _ name: String, _ kind: NodeKind, depth: Int = 1) async -> FileNode {
            await scanAsync(URL(fileURLWithPath: path), name: name, kind: kind, home: home, ctx: ctx, parallelDepth: depth)
        }
        async let h = scanAsync(home, name: NSUserName(), kind: .other, home: home, ctx: ctx, parallelDepth: 2)
        async let a = scanRoot("/Applications", "Applications", .apps)
        async let l = scanRoot("/Library", "Library", .systemData)
        async let p = scanRoot("/private", "private", .systemData)
        async let s = scanRoot("/System", "System", .system)
        async let u = scanRoot("/usr", "usr", .system)
        async let bn = scanRoot("/bin", "bin", .system, depth: 0)
        async let sb = scanRoot("/sbin", "sbin", .system, depth: 0)
        async let cx = scanRoot("/System/Volumes/Data/System", "System (data volume)", .system)
        async let op = scanRoot("/opt", "opt", .systemData)
        async let vm = scanRoot("/System/Volumes/VM", "VM", .systemData)
        // macOS itself is its own block, separate from "System Data".
        let macKids = await [s, u, bn, sb, cx].filter { $0.size > 0 }.sorted { $0.size > $1.size }
        let macOS = FileNode(id: "#macos", name: "macOS", url: nil,
                             size: macKids.reduce(Int64(0)) { $0 + $1.size },
                             isDirectory: true, kind: .system, children: macKids)
        var children = await [h, a, l, p, op, vm].filter { $0.size > 0 } + [macOS]
        let scanned = children.reduce(Int64(0)) { $0 + $1.size }
        if let volume, volume.used > scanned {
            children.append(FileNode(id: "#system", name: "System Data", url: nil,
                                     size: volume.used - scanned, isDirectory: false,
                                     kind: .systemData, synthetic: true))
        }
        let total = children.reduce(Int64(0)) { $0 + $1.size }
        children.sort { $0.size > $1.size }
        let root = FileNode(id: "/", name: "Your laptop", url: nil, size: total,
                            isDirectory: true, kind: .other, children: children)
        return ScanOutput(root: root, large: ctx.largeFiles(), skipped: ctx.snapshot().skipped)
    }

    private struct Listing {
        var dirs: [URL] = []
        var files: [(name: String, size: Int64)] = []
        var fileURLs: [URL] = []
    }

    private static func list(_ url: URL, ctx: ScanContext) -> Listing? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys, options: []) else {
            ctx.skip()
            return nil
        }
        var l = Listing()
        var bytes: Int64 = 0
        let dev = deviceID(url.path)
        for e in entries {
            if e.path == "/System/Volumes" { continue }   // firmlinks back to the data volume
            guard let v = try? e.resourceValues(forKeys: Set(keys)) else { continue }
            if v.isSymbolicLink == true { continue }
            if v.isDirectory == true {
                // Never cross into another volume (mounted disk images, cryptexes): it would double count.
                if let dev, let d = deviceID(e.path), d != dev { continue }
                l.dirs.append(e)
            } else {
                let s = Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
                bytes += s
                l.files.append((e.lastPathComponent, s))
                l.fileURLs.append(e)
                if s >= largeFileThreshold { ctx.addLarge(LargeFile(url: e, size: s)) }
            }
        }
        ctx.add(files: l.files.count, bytes: bytes)
        return l
    }

    private static func deviceID(_ path: String) -> dev_t? {
        var st = stat()
        return lstat(path, &st) == 0 ? st.st_dev : nil
    }

    private static func classify(_ url: URL, home: URL, inherited: NodeKind) -> NodeKind {
        let p = url.path, h = home.path
        if p.hasPrefix(h + "/Library/Caches") || p == h + "/.cache" || p == h + "/.npm"
            || p == h + "/Library/Logs" { return .systemData }
        if p.hasPrefix(h + "/Library/Developer") || p == h + "/.gradle" || p == h + "/.cargo"
            || url.lastPathComponent == "node_modules" { return .developer }
        if p.hasPrefix(h + "/Library/Application Support") || p.hasPrefix(h + "/Library/Containers")
            || p.hasPrefix(h + "/Library/Group Containers") { return .appData }
        if p == h + "/Documents" || p == h + "/Desktop" || p == h + "/Downloads" { return .documents }
        if p == h + "/Movies" || p == h + "/Music" || p == h + "/Pictures" { return .media }
        if p == "/Applications" { return .apps }
        if p == "/System" || p == "/usr" || p == "/bin" || p == "/sbin" { return .system }
        if p == "/Library" || p == "/private" { return .systemData }
        return inherited
    }

    private static func assemble(_ url: URL, name: String, kind: NodeKind, listing: Listing?,
                                 dirNodes: [FileNode]) -> FileNode {
        let fileTotal = listing?.files.reduce(Int64(0)) { $0 + $1.size } ?? 0
        let total = fileTotal + dirNodes.reduce(Int64(0)) { $0 + $1.size }
        let threshold = max(Int64(256 * 1024), total / 200)

        var kept = dirNodes.filter { $0.size >= threshold }
        var foldedSize = dirNodes.filter { $0.size < threshold }.reduce(Int64(0)) { $0 + $1.size }
        var foldedCount = dirNodes.count - kept.count
        var foldedList: [(name: String, size: Int64)] = dirNodes.filter { $0.size < threshold }.map { ($0.name, $0.size) }
        if let listing {
            for (i, f) in listing.files.enumerated() {
                if f.size >= threshold {
                    kept.append(FileNode(id: listing.fileURLs[i].path, name: f.name, url: listing.fileURLs[i],
                                         size: f.size, isDirectory: false, kind: kind))
                } else {
                    foldedSize += f.size; foldedCount += 1
                    foldedList.append((f.name, f.size))
                }
            }
        }
        kept.sort { $0.size > $1.size }
        if foldedSize > 0 {
            let rest = FileNode(id: url.path + "#rest", name: "\(foldedCount)", url: nil, size: foldedSize,
                                isDirectory: false, kind: kind, synthetic: true)
            rest.folded = Array(foldedList.sorted { $0.size > $1.size }.prefix(30))
            kept.append(rest)
        }
        return FileNode(id: url.path, name: name, url: url, size: total, isDirectory: true,
                        kind: kind, children: kept)
    }

    private static func scanSync(_ url: URL, name: String, kind inherited: NodeKind, home: URL,
                                 ctx: ScanContext) -> FileNode {
        let kind = classify(url, home: home, inherited: inherited)
        return autoreleasepool {
            let listing = Task.isCancelled ? nil : list(url, ctx: ctx)
            let nodes = (listing?.dirs ?? []).map {
                scanSync($0, name: $0.lastPathComponent, kind: kind, home: home, ctx: ctx)
            }
            return assemble(url, name: name, kind: kind, listing: listing, dirNodes: nodes)
        }
    }

    private static func scanAsync(_ url: URL, name: String, kind inherited: NodeKind, home: URL,
                                  ctx: ScanContext, parallelDepth: Int) async -> FileNode {
        if parallelDepth == 0 { return scanSync(url, name: name, kind: inherited, home: home, ctx: ctx) }
        let kind = classify(url, home: home, inherited: inherited)
        let listing = list(url, ctx: ctx)
        let nodes = await withTaskGroup(of: FileNode.self) { group in
            for d in listing?.dirs ?? [] {
                group.addTask {
                    await scanAsync(d, name: d.lastPathComponent, kind: kind, home: home,
                                    ctx: ctx, parallelDepth: parallelDepth - 1)
                }
            }
            var out: [FileNode] = []
            for await n in group { out.append(n) }
            return out
        }
        return assemble(url, name: name, kind: kind, listing: listing, dirNodes: nodes)
    }
}
