import SwiftUI
import AppKit

/// The real home folder (same as the current user's home when not sandboxed).
nonisolated func realHomeURL() -> URL {
    if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
        return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
}

enum DiskAccess {
    /// Full Disk Access probe: the TCC database is readable only with FDA, and opening it shows no prompt.
    static func isGranted() -> Bool {
        let fd = open("/Library/Application Support/com.apple.TCC/TCC.db", O_RDONLY)
        if fd >= 0 { close(fd); return true }
        return false
    }

    static func relaunch() {
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: cfg) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

struct AccessView: View {
    let onSkip: () -> Void
    let onGranted: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "externaldrive.badge.checkmark").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Allow access to your disk").font(.largeTitle.bold())
            Text("macOS asks for permission separately for Downloads, Music, Photos and other folders. Allow Full Disk Access once and those prompts never appear. The access is used only to measure and clean files on this Mac.")
                .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 540)
            VStack(alignment: .leading, spacing: 8) {
                Label("Open System Settings → Privacy & Security → Full Disk Access", systemImage: "1.circle")
                Label("Turn on See Your Disk (use + to add it if it is not in the list)", systemImage: "2.circle")
                Label("Come back and press “Restart app”", systemImage: "3.circle")
            }.font(.callout)
            HStack {
                Button("Open Settings") {
                    if let u = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles") {
                        NSWorkspace.shared.open(u)
                    }
                }.buttonStyle(.borderedProminent).controlSize(.large)
                Button("Restart app") { DiskAccess.relaunch() }.controlSize(.large)
                Button("Continue without access") { onSkip() }.controlSize(.large)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            while !Task.isCancelled {
                if DiskAccess.isGranted() { onGranted(); return }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
