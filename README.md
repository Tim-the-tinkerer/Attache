# Attaché

Attaché is a complete native macOS disk-image workbench, exposing the useful capabilities of Apple’s hdiutil through an approachable graphical interface.

**Version:** 1.3.1 — see [CHANGELOG.md](CHANGELOG.md).

## Features

- **Home** — overview cards for every action, plus the live attached-image list
- **Attach** — mount a `.dmg`, `.iso`, `.sparseimage`, or `.sparsebundle` with read-only, nomount, verify, and mount-point options
- **Create** — blank image, image from a folder, or clone a device (UDIF / sparse / sparse bundle, APFS / HFS+ / ExFAT / FAT). Sparse bundles can set band size (1 MB–8 GB)
- **Convert** — rewrite between UDZO, ULFO, ULMO, UDRW, sparse, DVD master, and more. UDSB output can set band size
- **Inspect** — `imageinfo` tree plus stored-checksum verify
- **Compact** — reclaim unused bands in sparse images
- **Band Size** — read or change a sparse bundle’s band size (`-imagekey` / `-tgtimagekey sparse-band-size`)
- **Resize** — query min/current/max, then grow or shrink
- **Checksum** — SHA-256, SHA-512, SHA-1, MD5, CRC-32, UDIF checksums
- **Hybrid ISO** — HFS+ / ISO9660 / Joliet / UDF via `makehybrid`
- **Console** — shows the exact `hdiutil` invocation and live progress (`-puppetstrings`)
- **Passwords** — sent on stdin with `-stdinpass`, never as a process argument
- Drag-and-drop images onto the window; Open With for disk images (does not steal the default handler)

## Requirements

- macOS 13 or later
- Swift toolchain (`xcode-select` / Command Line Tools or Xcode)
- System `hdiutil` at `/usr/bin/hdiutil`

## Build & run

```bash
cd ~/Attache
chmod +x build-app.sh
./build-app.sh
```

This builds a release binary, packages `Attaché.app`, ad-hoc signs it, and opens it.

Build without launching:

```bash
./build-app.sh --no-launch
```

SwiftPM only:

```bash
swift run AttacheCheck
swift build -c release
```

## Install (optional)

```bash
cp -R "Attaché.app" /Applications/
```

## Usage

| Sidebar        | Command              | What it does                                      |
|----------------|----------------------|---------------------------------------------------|
| Home           | `hdiutil info`       | Overview, action cards, and attached images       |
| Attach         | `hdiutil attach`     | Mount a disk image                                |
| Create         | `hdiutil create`     | Blank, from folder, or from device                |
| Convert        | `hdiutil convert`    | Change image format                               |
| Inspect        | `imageinfo` / `verify` | Metadata and checksum check                     |
| Compact        | `hdiutil compact`    | Shrink sparse images                              |
| Band Size      | `convert` + imagekey | Read or change sparse-bundle band size            |
| Resize         | `hdiutil resize`     | Change virtual size                               |
| Checksum       | `hdiutil checksum`   | Hash the image                                    |
| Hybrid ISO     | `hdiutil makehybrid` | Cross-platform ISO                                |

Shortcuts: **⌘O** open image, **⌘R** refresh attached list, **⌘.** cancel, **⌘⇧R** reveal last output.

## Notes

- This is a front end for the system `hdiutil`. It does not install a private disk-image stack.
- Creating an image of a physical disk reads every block; prefer an external disk, and use an APFS *container* rather than a single APFS volume.
- Burn, `chpass`, and `erasekeys` are not wrapped.

## License

Copyright © 2026. All rights reserved.
