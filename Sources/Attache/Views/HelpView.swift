import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Attaché", systemImage: "internaldrive")
                    .font(.title2.weight(.semibold))

                Text("A native macOS front end for Apple’s /usr/bin/hdiutil. Every action runs the real command; the console at the bottom shows the exact invocation (passwords are never included).")
                    .foregroundStyle(.secondary)

                section("Home") {
                    numbered(1, "Home is the overview. Action cards jump to each hdiutil verb.")
                    numbered(2, "Attached images appear under the cards. Detach unmounts; Force is detach -force.")
                    numbered(3, "Open reveals the mount point in Finder; Reveal selects the image file.")
                }

                section("Attach / Create / Convert") {
                    bullet("Attach mounts a .dmg, .iso, sparse image, or sparse bundle.")
                    bullet("Create a blank image, an image from a folder, or a clone of a device. Sparse bundles can pick a band size (1 MB–8 GB).")
                    bullet("Convert rewrites an image into another format (UDZO, ULFO, ULMO, UDRW, sparse, …). Converting to UDSB can set the band size.")
                    bullet("Drop a file onto the window to fill the current form.")
                }

                section("Inspect & maintain") {
                    bullet("Inspect runs imageinfo and can verify the checksum stored in a read-only image.")
                    bullet("Compact reclaims unused space in sparse images and sparse bundles.")
                    bullet("Band Size reads Info.plist and rewrites a sparse bundle with a new band size via convert −tgtimagekey sparse-band-size. Detach first; this cannot be done in place.")
                    bullet("The source password unlocks an encrypted bundle. Destination encryption is a separate choice (None / AES-128 / AES-256). If the source is encrypted, that same password is reused; a different destination password would need a later chpass step, which Attaché does not wrap.")
                    bullet("Force Detach and Replace original ask for confirmation. Passwords are cleared when a job finishes.")
                    bullet("Resize changes the virtual size. Query Limits first to see min / current / max.")
                    bullet("Checksum computes SHA-256 and other hashes over the image file.")
                    bullet("Hybrid ISO builds a cross-platform HFS+ / ISO / Joliet / UDF image.")
                }

                section("Passwords") {
                    bullet("Encrypted images use AES-128 or AES-256.")
                    bullet("The passphrase is written to hdiutil’s stdin with −stdinpass. It never appears in ps output or in the console command line. Attaché does not retain passwords after a job ends; that is not a claim of secure memory erasure.")
                    bullet("Create, convert, hybrid, and band-size writes go to a temporary sibling and replace the destination only after success. Attach After Create mounts the final path, not the staging file.")
                    bullet("Failed or cancelled writes delete the hidden .partial. file. If deletion fails, the exact path is logged.")
                    bullet("Background attached-image refresh cannot interrupt a user job. Cancel applies only to that job.")
                    bullet("Quitting while a job is running requires confirmation. Resize, compact, and bundle replacement strongly discourage quitting.")
                }

                section("Tips") {
                    bullet("⌘O opens an image. ⌘R refreshes the attached list. ⌘. cancels a running job.")
                    bullet("Copy in the console copies the log, including the hdiutil command you can paste into Terminal.")
                    bullet("hdiutil appends the right extension if you omit it.")
                    bullet("This app does not wrap burn, chpass, or erasekeys.")
                }

                section("Requirements") {
                    bullet("macOS 13 or later")
                    bullet("The system hdiutil at /usr/bin/hdiutil")
                }

                Text("Attaché \(AppVersion.display)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func numbered(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n).")
                .font(.body.monospacedDigit().weight(.semibold))
                .frame(width: 20, alignment: .trailing)
            Text(text)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
        }
    }
}
