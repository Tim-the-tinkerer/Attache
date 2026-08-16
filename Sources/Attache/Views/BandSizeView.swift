import SwiftUI
import AttacheCore

struct BandSizeView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        FormCard {
            OperationHeader(
                title: "Band Size",
                systemImage: "square.grid.3x3",
                blurb: "Read or change the band size of a sparse bundle. Changing it rewrites the bundle with hdiutil convert −tgtimagekey sparse-band-size."
            )

            PathWell(
                title: "Sparse bundle",
                placeholder: "Choose a .sparsebundle",
                url: model.bandForm.source,
                recents: model.recents.filter(SparseBundleInfo.isSparseBundle),
                onChoose: {
                    if let url = openPanel(
                        files: true,
                        directories: true,
                        types: AppModel.imageTypes,
                        title: "Choose Sparse Bundle"
                    ) {
                        model.loadBandInfo(from: url)
                    }
                },
                onClear: { model.bandForm = BandForm() },
                onPickRecent: { model.loadBandInfo(from: $0) }
            )

            if let current = model.bandForm.currentBytes {
                GroupBox("Current") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Band size")
                                .foregroundStyle(.secondary)
                                .frame(width: 110, alignment: .leading)
                            Text(SparseBandSize.display(bytes: current))
                                .font(.body.monospacedDigit().weight(.medium))
                            Text("(\(current) bytes, \(current / SparseBandSize.bytesPerSector) sectors)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        if let virtual = model.bandForm.virtualSizeBytes {
                            HStack {
                                Text("Virtual size")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 110, alignment: .leading)
                                Text(ByteCountFormatter.string(fromByteCount: virtual, countStyle: .file))
                                    .font(.body.monospacedDigit())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if model.bandForm.source != nil {
                Text("Could not read Info.plist band-size. Confirm this is a sparse bundle and that it is not damaged.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            GroupBox("New band size") {
                BandSizePicker(
                    preset: $model.bandForm.preset,
                    customMegabytes: $model.bandForm.customMB,
                    includeSystemDefault: false,
                    currentBytes: model.bandForm.currentBytes
                )
            }

            GroupBox("Output") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Replace the original bundle", isOn: $model.bandForm.replaceOriginal)
                        .toggleStyle(.checkbox)
                        .help("Converts to a temporary bundle beside the original, then swaps it in. Detach the image first.")
                    if !model.bandForm.replaceOriginal {
                        PathWell(
                            title: "Save as",
                            placeholder: "Choose a destination .sparsebundle…",
                            url: model.bandForm.output,
                            onChoose: { model.bandForm.output = model.resolvedBandOutput() },
                            onClear: { model.bandForm.output = nil }
                        )
                        Text("If the destination already exists, Attaché will ask before replacing it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("The original is moved aside only after the new bundle is written. If the swap fails, the original is restored.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            GroupBox("Source password") {
                VStack(alignment: .leading, spacing: 8) {
                    if model.bandForm.sourceEncrypted == true {
                        Label("This bundle is encrypted", systemImage: "lock.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                    SecureField("Password to read the source (if it is encrypted)", text: $model.bandForm.sourcePassword)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                    Text("Unlocks the existing bundle. hdiutil accepts one passphrase (−stdinpass).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("Destination encryption") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Destination encryption", selection: $model.bandForm.destEncryption) {
                        ForEach(EncryptionChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .labelsHidden()
                    if model.bandForm.destEncryption != .none {
                        if sourceWillSupplyPassword {
                            Text("The destination will use the same password as the source. Attaché cannot send a different destination password in this step.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            PasswordFields(
                                prompt: "Password for the new encrypted bundle",
                                password: $model.bandForm.destPassword,
                                confirm: $model.bandForm.destConfirm
                            )
                            Text("The source is not encrypted, so this is the only password hdiutil will receive.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Text("Band size cannot be edited in place — existing band files keep their old length. Convert writes a new bundle. Detach the image first.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ActionBar {
                Button {
                    model.requestChangeBandSize()
                } label: {
                    Label(
                        model.bandForm.replaceOriginal ? "Rewrite Bundle" : "Write New Bundle",
                        systemImage: "square.grid.3x3"
                    )
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRun || model.bandForm.source == nil)
            } secondary: {
                EmptyView()
            }
        }
    }

    private var sourceWillSupplyPassword: Bool {
        model.bandForm.sourceEncrypted == true || !model.bandForm.sourcePassword.isEmpty
    }
}
