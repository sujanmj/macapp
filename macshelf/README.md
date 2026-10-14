# MacShelf v0.1

A native macOS file shelf inspired by the collecting workflow of [Dropover](https://dropoverapp.com/). Independent code and identity, MIT licensed.

Open the floating shelf with **Control–Option–S** or the menu bar. Drop files from multiple Finder folders, use Add to select documents/photos/folders, or paste copied file references. Shake left/right while dragging to reveal the shelf without releasing your files. Select with Command-click or Select All. Drag the blue batch bar to deliver the selection in one operation, or Copy Batch and paste in Finder/a compatible app. An empty selection means the whole shelf. Outgoing drags offer copy only.

The shelf stores references, not copies of Finder files. Removing/clearing references never deletes originals. Bookmarks persist locally across launches; missing/moved/unavailable items are shown and excluded from outgoing batches. Quick Look previews the first selected file. App-exported file promises (such as compatible Photos exports) are received into `~/Library/Application Support/MacShelf/Imports`; these are new exported files, not original photo-library items. Imported files remain there even when a shelf reference is removed. No automatic deletion of imports or source files occurs.

Limits: 300 references, one shelf, file-backed content only. Destination apps must support standard file drops/paste. Browser text/links, cloud upload, batch processing, folder monitoring and multiple named shelves are not implemented. Shake detection depends on macOS delivering mouse-drag events; the shortcut/menu always remain available. Login is optional in Settings.

## Build and installation

`bash scripts/package-utility.sh MacShelf` from the repo root. Requires Xcode and XcodeGen. Produces a universal Apple Silicon/Intel DMG and SHA-256 checksum. macOS 14+.

The Desktop Utilities workflow creates build artifacts only. Verified beta installers are published in this app’s own release; see [downloads](downloads/README.md). Builds are ad-hoc signed, unnotarized; downloaded apps may need deliberate approval in Privacy & Security. No Accessibility or Photos-library permission is requested by the shelf itself.

## Device checks

Collect from three folders; copy/drag into a fourth and verify originals remain. Test duplicate inputs, partial selection, missing files, canceling a drag, Photos file promises, Quick Look, relaunch persistence, Spaces/full-screen windows, and shake during a Finder drag. Verify Clear Shelf preserves originals and exported imports.
