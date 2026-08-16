import SwiftUI
import UniformTypeIdentifiers
import AttacheCore

struct AttachView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        FormCard {
            OperationHeader(
                title: "Attach",
                systemImage: "externaldrive.badge.plus",
                blurb: "Attach a disk image as a device and optionally mount its volumes. Wraps hdiutil attach."
            )

            PathWell(
                title: "Disk image",
                placeholder: "Drop a .dmg, .iso, .sparseimage, or .sparsebundle",
                url: model.attachForm.source,
                recents: model.recents.filter(DiskImagePath.isDiskImage),
                onChoose: {
                    if let url = openPanel(
                        files: true,
                        directories: true,
                        types: AppModel.imageTypes,
                        title: "Choose Disk Image"
                    ) {
                        model.openImage(url, preferring: .attach)
                    }
                },
                onClear: { model.attachForm.source = nil },
                onPickRecent: { model.openImage($0, preferring: .attach) }
            )

            GroupBox("Options") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Read-only", isOn: $model.attachForm.readOnly)
                    Toggle("Do not mount volumes (−nomount)", isOn: $model.attachForm.noMount)
                    Toggle("Skip checksum verify", isOn: $model.attachForm.skipVerify)
                    Toggle("Open in Finder after attach", isOn: $model.attachForm.autoOpen)
                        .disabled(model.attachForm.noMount)
                    Toggle("Custom mount point", isOn: $model.attachForm.useCustomMount)
                        .disabled(model.attachForm.noMount)
                    if model.attachForm.useCustomMount && !model.attachForm.noMount {
                        PathWell(
                            title: "Mount point",
                            placeholder: "Choose an empty folder",
                            url: model.attachForm.mountPoint,
                            onChoose: { model.attachForm.mountPoint = model.pickMountPoint() },
                            onClear: { model.attachForm.mountPoint = nil }
                        )
                    }
                }
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.attachForm.encrypted == true || !model.attachForm.password.isEmpty {
                GroupBox("Encryption") {
                    PasswordFields(
                        prompt: "Image password",
                        password: $model.attachForm.password,
                        encryptedHint: model.attachForm.encrypted
                    )
                }
            } else if model.attachForm.source != nil {
                Text("If the image is encrypted, a password field will appear after probing — or enter one now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Password (optional)", text: $model.attachForm.password)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)
            }

            ActionBar {
                Button {
                    model.runAttach()
                } label: {
                    Label("Attach Image", systemImage: "externaldrive.badge.plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRun || model.attachForm.source == nil)
                .keyboardShortcut(.defaultAction)
            } secondary: {
                EmptyView()
            }
        }
    }
}
