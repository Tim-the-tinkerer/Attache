import AppKit
import SwiftUI
import UniformTypeIdentifiers
import AttacheCore

struct PathWell: View {
    let title: String
    let placeholder: String
    let url: URL?
    var recents: [URL] = []
    var onChoose: () -> Void
    var onClear: (() -> Void)?
    var onPickRecent: ((URL) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                Image(systemName: url == nil ? "doc.badge.plus" : "doc")
                    .foregroundStyle(url == nil ? .secondary : Theme.accent)
                    .frame(width: 18)
                Text(url?.path ?? placeholder)
                    .foregroundStyle(url == nil ? .secondary : .primary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if url != nil, let onClear {
                    Button("Clear", action: onClear)
                        .controlSize(.small)
                }
                if !recents.isEmpty, let onPickRecent {
                    Menu("Recent") {
                        ForEach(recents, id: \.path) { recent in
                            Button(recent.lastPathComponent) {
                                onPickRecent(recent)
                            }
                        }
                    }
                    .controlSize(.small)
                }
                Button("Choose…", action: onChoose)
                    .controlSize(.small)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

struct PasswordFields: View {
    let prompt: String
    @Binding var password: String
    var confirm: Binding<String>?
    var encryptedHint: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if encryptedHint == true {
                Label("This image is encrypted", systemImage: "lock.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
            SecureField(prompt, text: $password)
                .textFieldStyle(.roundedBorder)
            if let confirm {
                SecureField("Confirm password", text: confirm)
                    .textFieldStyle(.roundedBorder)
            }
            Text("The password is sent to hdiutil on stdin (−stdinpass). It is never placed on the command line. Attaché does not retain passwords after a job ends.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct BandSizePicker: View {
    @Binding var preset: BandSizePreset
    @Binding var customMegabytes: String
    var includeSystemDefault: Bool = true
    var currentBytes: Int64?

    private var presets: [BandSizePreset] {
        includeSystemDefault ? BandSizePreset.allCases : BandSizePreset.changeCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Band size")
                    .frame(width: 110, alignment: .leading)
                Picker("Band size", selection: $preset) {
                    ForEach(presets) { item in
                        Text(item.title).tag(item)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 280)
            }
            if preset == .custom {
                HStack {
                    Text("Custom")
                        .frame(width: 110, alignment: .leading)
                    TextField("MB", text: $customMegabytes)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Text("MB (1–8192)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let currentBytes {
                Text("Current band size: \(SparseBandSize.display(bytes: currentBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Each sparse-bundle band is a file in the bundle. Larger bands mean fewer files; smaller bands compact more finely. hdiutil accepts 1 MB–8 GB (512-byte sectors).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct OperationHeader: View {
    let title: String
    let systemImage: String
    let blurb: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(blurb)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }
}

struct ActionBar<Primary: View, Secondary: View>: View {
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary

    var body: some View {
        HStack {
            secondary()
            Spacer()
            primary()
        }
        .padding(.top, 8)
    }
}

struct JobConsoleView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                statusBadge
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if case .running(_, let percent, _) = model.job {
                    if let percent {
                        ProgressView(value: percent)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 180)
                        Text("\(Int((percent * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("Cancel") { model.cancelJob() }
                        .controlSize(.small)
                }
                Spacer()
                if model.lastRevealURL != nil && !model.job.isRunning {
                    Button("Reveal") { model.revealLastOutput() }
                        .controlSize(.small)
                }
                Button("Copy") { model.copyLastCommand() }
                    .controlSize(.small)
                    .disabled(model.log.isEmpty)
                Button("Clear") { model.clearLog() }
                    .controlSize(.small)
                    .disabled(model.log.isEmpty)
            }

            ScrollView {
                Text(model.log.isEmpty ? "Command output will appear here." : model.log)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(model.log.isEmpty ? .tertiary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 96, idealHeight: 120, maxHeight: 180)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var statusBadge: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch model.job {
        case .idle: return .secondary
        case .running: return Theme.accent
        case .succeeded: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }

    private var statusText: String {
        switch model.job {
        case .idle: return "Ready"
        case .running(let verb, _, _): return "Running hdiutil \(verb)…"
        case .succeeded(let text): return text
        case .failed(let text): return text
        case .cancelled: return "Cancelled"
        }
    }
}

struct FormCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(20)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

func openPanel(
    files: Bool,
    directories: Bool,
    types: [UTType],
    title: String
) -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = files
    panel.canChooseDirectories = directories
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = types
    panel.title = title
    return panel.runModal() == .OK ? panel.url : nil
}
