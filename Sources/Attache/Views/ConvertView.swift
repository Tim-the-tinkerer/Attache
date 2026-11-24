import SwiftUI
import AttacheCore

struct ConvertView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        FormCard {
            OperationHeader(
                title: "Convert",
                systemImage: "arrow.triangle.2.circlepath",
                blurb: "Rewrite a disk image in another format. Wraps hdiutil convert, or diskutil image create when the source or destination is Apple Sparse Image."
            )

            PathWell(
                title: "Source image",
                placeholder: "Choose the image to convert",
                url: model.convertForm.source,
                recents: model.recents.filter(DiskImagePath.isDiskImage),
                onChoose: {
                    if let url = openPanel(files: true, directories: true, types: AppModel.imageTypes, title: "Choose Image") {
                        setSource(url)
                    }
                },
                onClear: {
                    model.convertForm.source = nil
                    model.convertForm.sourceBandBytes = nil
                },
                onPickRecent: { setSource($0) }
            )

            GroupBox("Format") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Format", selection: $model.convertForm.format) {
                        ForEach(convertFormats) { format in
                            Text("\(format.rawValue) — \(format.title)").tag(format)
                        }
                    }
                    .labelsHidden()
                    Text(model.convertForm.format.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if model.convertForm.format == .udsb {
                        Divider()
                        if sourceIsASIF {
                            Text("Band size cannot be set when the source is an Apple Sparse Image. diskutil image uses the system default.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            BandSizePicker(
                                preset: $model.convertForm.bandPreset,
                                customMegabytes: $model.convertForm.bandCustomMB,
                                currentBytes: model.convertForm.sourceBandBytes
                            )
                        }
                    }
                }
            }

            GroupBox("Output") {
                VStack(alignment: .leading, spacing: 10) {
                    PathWell(
                        title: "Save as",
                        placeholder: "Choose a destination…",
                        url: model.convertForm.output,
                        onChoose: { model.convertForm.output = model.resolvedConvertOutput() },
                        onClear: { model.convertForm.output = nil }
                    )
                    Text("If the destination already exists, Attaché will ask before replacing it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("Encryption") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Encryption", selection: $model.convertForm.encryption) {
                        ForEach(encryptionChoices) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .labelsHidden()
                    if sourceIsASIF || model.convertForm.format == .asif {
                        Text("Apple Sparse Image encryption is AES-256. One passphrase unlocks the source and, when set, encrypts the destination.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    SecureField("Source or destination password (if needed)", text: $model.convertForm.password)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                }
            }

            ActionBar {
                Button {
                    model.runConvert()
                } label: {
                    Label("Convert Image", systemImage: "arrow.triangle.2.circlepath")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRun || model.convertForm.source == nil)
            } secondary: {
                Text("Output extension .\(model.convertForm.format.fileExtension)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: model.convertForm.format) { _ in model.normalizeASIFConvert() }
    }

    private var sourceIsASIF: Bool {
        model.convertForm.source.map(DiskImagePath.isASIF) ?? false
    }

    private var convertFormats: [ImageFormat] {
        if sourceIsASIF {
            return ImageFormat.convertCases.filter { $0.diskutilFormat != nil }
        }
        return ImageFormat.convertCases
    }

    private var encryptionChoices: [EncryptionChoice] {
        sourceIsASIF || model.convertForm.format == .asif ? [.none, .aes256] : EncryptionChoice.allCases
    }

    private func setSource(_ url: URL) {
        model.convertForm.source = url
        model.convertForm.sourceBandBytes = SparseBundleInfo.isSparseBundle(url)
            ? SparseBundleInfo.readBandSizeBytes(at: url)
            : nil
        model.normalizeASIFConvert()
    }
}
