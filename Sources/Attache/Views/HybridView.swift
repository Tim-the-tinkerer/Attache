import SwiftUI
import AttacheCore

struct HybridView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        FormCard {
            OperationHeader(
                title: "Hybrid ISO",
                systemImage: "opticaldisc",
                blurb: "Build a cross-platform hybrid image (HFS+ / ISO9660 / Joliet / UDF). Wraps hdiutil makehybrid."
            )

            PathWell(
                title: "Source",
                placeholder: "Choose a folder or an existing image",
                url: model.hybridForm.source,
                recents: model.recents,
                onChoose: {
                    if let url = openPanel(
                        files: true,
                        directories: true,
                        types: AppModel.imageTypes + [.folder],
                        title: "Choose Source"
                    ) {
                        model.hybridForm.source = url
                    }
                },
                onClear: { model.hybridForm.source = nil },
                onPickRecent: { model.hybridForm.source = $0 }
            )

            GroupBox("Filesystems") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("HFS+", isOn: $model.hybridForm.hfs)
                    Toggle("ISO9660", isOn: $model.hybridForm.iso)
                    Toggle("Joliet (long names on Windows)", isOn: $model.hybridForm.joliet)
                    Toggle("UDF", isOn: $model.hybridForm.udf)
                }
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text("Volume name")
                    .frame(width: 110, alignment: .leading)
                TextField("Volume name", text: $model.hybridForm.volumeName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
            }

            GroupBox("Output") {
                VStack(alignment: .leading, spacing: 10) {
                    PathWell(
                        title: "Save as",
                        placeholder: "Choose a .iso destination…",
                        url: model.hybridForm.output,
                        onChoose: { model.hybridForm.output = model.resolvedHybridOutput() },
                        onClear: { model.hybridForm.output = nil }
                    )
                    Text("If the destination already exists, Attaché will ask before replacing it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ActionBar {
                Button {
                    model.runHybrid()
                } label: {
                    Label("Make Hybrid", systemImage: "opticaldisc")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRun || model.hybridForm.source == nil)
            } secondary: {
                EmptyView()
            }
        }
    }
}
