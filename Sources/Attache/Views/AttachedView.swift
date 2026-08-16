import AppKit
import SwiftUI
import AttacheCore

struct AttachedView: View {
    @ObservedObject var model: AppModel

    private let columns = [
        GridItem(.adaptive(minimum: 176, maximum: 240), spacing: 12, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                intro
                actions
                attachedSection
            }
            .padding(20)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What do you want to do?")
                .font(.title2.weight(.semibold))
            Text("Attaché is a front end for the system hdiutil command. Pick an action, or drop a disk image onto this window.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actions")
                .font(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(SidebarItem.actions) { item in
                    ActionCard(item: item) {
                        model.selection = item
                    }
                }
            }
        }
    }

    private var attachedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Attached images")
                    .font(.headline)
                Spacer()
                Text(attachedCountLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if model.attached.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "internaldrive")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nothing is attached")
                            .font(.body.weight(.medium))
                        Text("Drop a .dmg, .iso, or sparse bundle here, or choose Attach.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Attach an Image…") {
                            model.selection = .attach
                            model.chooseImage(for: .attach)
                        }
                        .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(model.attached) { image in
                        attachedRow(image)
                        if image.id != model.attached.last?.id {
                            Divider()
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
        }
    }

    private func attachedRow(_ image: AttachedImage) -> some View {
        let selected = model.selectedAttachedID == image.id
        return HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(Theme.accent)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(image.displayName)
                    .font(.body.weight(.medium))
                Text(image.imagePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 10) {
                    if let disk = image.wholeDisk ?? image.devices.first {
                        Text(disk)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if let mount = image.primaryMount {
                        Text(mount)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Not mounted")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer(minLength: 8)
            Button("Open") { model.selectedAttachedID = image.id; model.openSelectedMount() }
                .controlSize(.small)
                .disabled(image.primaryMount == nil)
            Button("Reveal") { model.selectedAttachedID = image.id; model.revealSelectedImage() }
                .controlSize(.small)
            Button("Detach") { model.selectedAttachedID = image.id; model.detachSelected(force: false) }
                .controlSize(.small)
                .disabled(!model.canRun)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(selected ? Theme.accent.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { model.selectedAttachedID = image.id }
        .contextMenu {
            Button("Open in Finder") { model.selectedAttachedID = image.id; model.openSelectedMount() }
                .disabled(image.primaryMount == nil)
            Button("Reveal Image") { model.selectedAttachedID = image.id; model.revealSelectedImage() }
            Divider()
            Button("Detach") { model.selectedAttachedID = image.id; model.detachSelected(force: false) }
            Button("Force Detach") { model.selectedAttachedID = image.id; model.requestForceDetach() }
        }
    }

    private var attachedCountLabel: String {
        let n = model.attached.count
        return n == 1 ? "1 attached" : "\(n) attached"
    }
}

struct ActionCard: View {
    let item: SidebarItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 24)
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(item.subtitle)
    }
}
