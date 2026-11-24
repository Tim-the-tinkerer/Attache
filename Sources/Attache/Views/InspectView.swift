import SwiftUI
import AttacheCore

struct InspectView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        FormCard {
            OperationHeader(
                title: "Inspect",
                systemImage: "magnifyingglass",
                blurb: "Read format, size, and checksum metadata. Uses hdiutil imageinfo, or diskutil image info for Apple Sparse Image. Verify stays on hdiutil."
            )

            PathWell(
                title: "Disk image",
                placeholder: "Choose an image to inspect",
                url: model.inspectForm.source,
                recents: model.recents.filter(DiskImagePath.isDiskImage),
                onChoose: {
                    if let url = openPanel(files: true, directories: true, types: AppModel.imageTypes, title: "Choose Image") {
                        model.openImage(url, preferring: .inspect)
                    }
                },
                onClear: {
                    model.inspectForm.source = nil
                    model.inspectForm.rows = []
                    model.inspectForm.summary = [:]
                },
                onPickRecent: { model.openImage($0, preferring: .inspect) }
            )

            if model.inspectForm.encrypted == true || !model.inspectForm.password.isEmpty {
                PasswordFields(
                    prompt: "Image password",
                    password: $model.inspectForm.password,
                    encryptedHint: model.inspectForm.encrypted
                )
            } else {
                SecureField("Password (if encrypted)", text: $model.inspectForm.password)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)
            }

            HStack {
                Button {
                    model.runInspect()
                } label: {
                    Label("Read Info", systemImage: "info.circle")
                }
                .disabled(!model.canRun || model.inspectForm.source == nil)

                Button {
                    model.runVerify()
                } label: {
                    Label("Verify Checksum", systemImage: "checkmark.seal")
                }
                .disabled(!model.canRun || model.inspectForm.source == nil || inspectIsASIF)
                .help(inspectIsASIF ? "Verify is not available for an Apple Sparse Image." : "Verify the stored checksum")

                if let flag = model.inspectForm.encrypted {
                    Label(
                        flag ? "Encrypted" : "Not encrypted",
                        systemImage: flag ? "lock.fill" : "lock.open"
                    )
                    .foregroundStyle(flag ? .orange : .secondary)
                    .font(.caption.weight(.medium))
                }
            }

            if !model.inspectForm.summary.isEmpty {
                GroupBox("Summary") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.inspectForm.summary.keys.sorted(), id: \.self) { key in
                            HStack(alignment: .firstTextBaseline) {
                                Text(key)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 120, alignment: .leading)
                                Text(model.inspectForm.summary[key] ?? "")
                                    .textSelection(.enabled)
                            }
                            .font(.callout)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !model.inspectForm.rows.isEmpty {
                GroupBox("Details") {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(model.inspectForm.rows) { row in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(row.key)
                                    .font(.caption.weight(row.value.isEmpty ? .semibold : .regular))
                                    .foregroundStyle(row.value.isEmpty ? .primary : .secondary)
                                if !row.value.isEmpty {
                                    Text(row.value)
                                        .font(.caption.monospaced())
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.leading, CGFloat(row.level) * 14)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var inspectIsASIF: Bool {
        model.inspectForm.source.map(DiskImagePath.isASIF) ?? false
    }
}
