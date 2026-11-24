import AppKit
import SwiftUI
import AttacheCore

struct CompactView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        FormCard {
            OperationHeader(
                title: "Compact",
                systemImage: "arrow.down.right.and.arrow.up.left",
                blurb: "Reclaim unused bands from a sparse image or sparse bundle. Wraps hdiutil compact."
            )

            PathWell(
                title: "Sparse image",
                placeholder: "Choose a .sparseimage or .sparsebundle",
                url: model.compactForm.source,
                recents: model.recents.filter(Self.isSparse),
                onChoose: {
                    if let url = openPanel(files: true, directories: true, types: AppModel.imageTypes, title: "Choose Sparse Image") {
                        model.compactForm.source = url
                    }
                },
                onClear: { model.compactForm.source = nil },
                onPickRecent: { model.compactForm.source = $0 }
            )

            if let source = model.compactForm.source,
               SparseBundleInfo.isSparseBundle(source),
               let bytes = SparseBundleInfo.readBandSizeBytes(at: source) {
                Text("Current band size: \(SparseBandSize.display(bytes: bytes)). Change it in Band Size.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Allow compacting on battery", isOn: $model.compactForm.batteryAllowed)
                .toggleStyle(.checkbox)
            SecureField("Password (if encrypted)", text: $model.compactForm.password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)

            if model.compactForm.source.map(DiskImagePath.isASIF) == true {
                Text("Compact is not available for an Apple Sparse Image. diskutil image has no compact command.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Compact only works on SPARSE / SPARSEBUNDLE images that contain an APFS or HFS+ filesystem. The image should not be attached.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ActionBar {
                Button {
                    model.runCompact()
                } label: {
                    Label("Compact Image", systemImage: "arrow.down.right.and.arrow.up.left")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRun || model.compactForm.source == nil || model.compactForm.source.map(DiskImagePath.isASIF) == true)
            } secondary: {
                EmptyView()
            }
        }
    }

    private static func isSparse(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "sparseimage" || ext == "sparsebundle" || url.lastPathComponent.lowercased().hasSuffix(".sparsebundle")
    }
}

struct ResizeView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        FormCard {
            OperationHeader(
                title: "Resize",
                systemImage: "arrow.left.and.right.square",
                blurb: "Change the virtual size of a writable image or its partition. Query Limits first. Attaché is not a backup — keep a copy of important images."
            )

            PathWell(
                title: "Disk image",
                placeholder: "Choose a writable image",
                url: model.resizeForm.source,
                recents: model.recents.filter(DiskImagePath.isDiskImage),
                onChoose: {
                    if let url = openPanel(files: true, directories: true, types: AppModel.imageTypes, title: "Choose Image") {
                        model.setResizeSource(url)
                    }
                },
                onClear: {
                    model.setResizeSource(nil)
                },
                onPickRecent: {
                    model.setResizeSource($0)
                }
            )

            HStack {
                Text("New size")
                    .frame(width: 90, alignment: .leading)
                TextField("Size", text: $model.resizeForm.amount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                Picker("Unit", selection: $model.resizeForm.unit) {
                    ForEach(SizeUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .labelsHidden()
                .frame(width: 80)
            }

            Toggle("Image only (do not resize the partition)", isOn: Binding(
                get: { model.resizeForm.imageOnly },
                set: { newValue in
                    model.resizeForm.imageOnly = newValue
                    if newValue { model.resizeForm.partitionOnly = false }
                }
            ))
            .toggleStyle(.checkbox)
            .disabled(model.resizeForm.partitionOnly)
            .help("Advanced. Changes only the image container. A mismatch with the partition can make the image unusable.")
            Toggle("Partition only (do not resize the image file)", isOn: Binding(
                get: { model.resizeForm.partitionOnly },
                set: { newValue in
                    model.resizeForm.partitionOnly = newValue
                    if newValue { model.resizeForm.imageOnly = false }
                }
            ))
            .toggleStyle(.checkbox)
            .disabled(model.resizeForm.imageOnly || resizeIsASIF)
            .help("Advanced. Changes only the partition map. A mismatch with the image file can make the image unusable.")
            if resizeIsASIF {
                Text("Apple Sparse Image resize uses diskutil image. Partition-only is not available. Limits are reported in bytes and shown here as 512-byte sectors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Image Only and Partition Only are advanced. Prefer a full resize unless you know you need them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let note = resizePreviewNote {
                Text(note)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SecureField("Password (if encrypted)", text: $model.resizeForm.password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)

            if let limits = model.resizeForm.limits {
                GroupBox("Limits") {
                    VStack(alignment: .leading, spacing: 6) {
                        limitRow("Minimum", bytes: limits.minBytes, sectors: limits.minSectors)
                        limitRow("Current", bytes: limits.currentBytes, sectors: limits.currentSectors)
                        limitRow("Maximum", bytes: limits.maxBytes, sectors: limits.maxSectors)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            ActionBar {
                Button {
                    model.runResize()
                } label: {
                    Label("Resize Image", systemImage: "arrow.left.and.right.square")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRun || model.resizeForm.source == nil || model.resizeForm.limits == nil)
                .help(model.resizeForm.limits == nil ? "Query Limits before resizing." : "Resize the image")
            } secondary: {
                Button("Query Limits") {
                    model.queryResizeLimits()
                }
                .disabled(!model.canRun || model.resizeForm.source == nil)
            }
        }
    }

    private var resizeIsASIF: Bool {
        model.resizeForm.source.map(DiskImagePath.isASIF) ?? false
    }

    private var resizePreviewNote: String? {
        guard let limits = model.resizeForm.limits,
              let bytes = SizeSpec.bytes(amount: model.resizeForm.amount, unit: model.resizeForm.unit)
        else { return nil }
        if bytes < limits.minBytes || bytes > limits.maxBytes {
            return "This size is outside the reported minimum and maximum."
        }
        if bytes < limits.currentBytes {
            return "This will shrink the image."
        }
        if bytes > limits.currentBytes {
            return "This will grow the image."
        }
        return "This is the current size."
    }

    private func limitRow(_ title: String, bytes: Int64, sectors: Int64) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                .font(.body.monospacedDigit())
            Text("\(sectors) sectors")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

struct ChecksumView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        FormCard {
            OperationHeader(
                title: "Checksum",
                systemImage: "number.square",
                blurb: "Calculate a checksum over a disk image. Wraps hdiutil checksum."
            )

            PathWell(
                title: "Disk image",
                placeholder: "Choose an image",
                url: model.checksumForm.source,
                recents: model.recents.filter(DiskImagePath.isDiskImage),
                onChoose: {
                    if let url = openPanel(files: true, directories: true, types: AppModel.imageTypes, title: "Choose Image") {
                        model.checksumForm.source = url
                        model.checksumForm.result = nil
                    }
                },
                onClear: {
                    model.checksumForm.source = nil
                    model.checksumForm.result = nil
                },
                onPickRecent: {
                    model.checksumForm.source = $0
                    model.checksumForm.result = nil
                }
            )

            Picker("Algorithm", selection: $model.checksumForm.type) {
                ForEach(ChecksumType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .frame(maxWidth: 260)

            SecureField("Password (if encrypted)", text: $model.checksumForm.password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
            if model.checksumForm.source.map(DiskImagePath.isASIF) == true {
                Text("Checksum is not available for an Apple Sparse Image. hdiutil checksum does not read this format.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let result = model.checksumForm.result, !result.isEmpty {
                GroupBox("Result") {
                    HStack {
                        Text(result)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        Spacer()
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result, forType: .string)
                        }
                        .controlSize(.small)
                    }
                }
            }

            ActionBar {
                Button {
                    model.runChecksum()
                } label: {
                    Label("Compute Checksum", systemImage: "number.square")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRun || model.checksumForm.source == nil || model.checksumForm.source.map(DiskImagePath.isASIF) == true)
            } secondary: {
                EmptyView()
            }
        }
    }
}
