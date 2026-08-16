import SwiftUI
import AttacheCore

struct ConvertView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        FormCard {
            OperationHeader(
                title: "Convert",
                systemImage: "arrow.triangle.2.circlepath",
                blurb: "Rewrite a disk image in another UDIF format. Wraps hdiutil convert."
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
                        ForEach(ImageFormat.convertCases) { format in
                            Text("\(format.rawValue) — \(format.title)").tag(format)
                        }
                    }
                    .labelsHidden()
                    Text(model.convertForm.format.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if model.convertForm.format == .udsb {
                        Divider()
                        BandSizePicker(
                            preset: $model.convertForm.bandPreset,
                            customMegabytes: $model.convertForm.bandCustomMB,
                            currentBytes: model.convertForm.sourceBandBytes
                        )
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
                        ForEach(EncryptionChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .labelsHidden()
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
    }

    private func setSource(_ url: URL) {
        model.convertForm.source = url
        model.convertForm.sourceBandBytes = SparseBundleInfo.isSparseBundle(url)
            ? SparseBundleInfo.readBandSizeBytes(at: url)
            : nil
    }
}
