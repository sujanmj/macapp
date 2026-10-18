#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
# Compile production shelf logic without its app entry point for deterministic
# tests. Persistence is disabled; tests do not read/change the user's clipboard.
sed '/^@main/,$d' macshelf/Sources/MacShelf/MacShelfApp.swift > "$scratch/Shelf.swift"
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/ModuleCache" \
  shared/UtilityKit/*.swift "$scratch/Shelf.swift" scripts/utility-smoke-tests.swift \
  -o "$scratch/check"
"$scratch/check"
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/ModuleCache" \
  shared/UtilityKit/*.swift macnotch/Sources/MacNotch/GeminiClient.swift scripts/gemini-tests.swift \
  -o "$scratch/gemini-check"
"$scratch/gemini-check"
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/ModuleCache" \
  macnotch/Sources/MacNotch/SystemSampler.swift scripts/macnotch-sampler-tests.swift \
  -o "$scratch/macnotch-sampler-check"
"$scratch/macnotch-sampler-check"
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/ModuleCache" \
  macnotch/Sources/MacNotch/LocalTextRecognizer.swift macnotch/Sources/MacNotch/CaptureMarkupRenderer.swift scripts/macnotch-capture-tests.swift \
  -o "$scratch/macnotch-capture-check"
"$scratch/macnotch-capture-check"
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/ModuleCache" \
  macnotch/Sources/MacNotch/ImageFileActions.swift scripts/macnotch-image-actions-tests.swift \
  -framework AppKit -framework ImageIO -framework UniformTypeIdentifiers -o "$scratch/macnotch-image-actions-check"
"$scratch/macnotch-image-actions-check"
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/ModuleCache" \
  macnotch/Sources/MacNotch/ClipboardPinStore.swift scripts/macnotch-clipboard-pin-tests.swift \
  -o "$scratch/macnotch-clipboard-pin-check"
"$scratch/macnotch-clipboard-pin-check"
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/ModuleCache" \
  macnotch/Sources/MacNotch/DragShakeDetector.swift scripts/macnotch-drag-shake-tests.swift \
  -o "$scratch/macnotch-drag-shake-check"
"$scratch/macnotch-drag-shake-check"
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/ModuleCache" \
  macnotch/Sources/MacNotch/TrayTransfer.swift scripts/macnotch-tray-transfer-tests.swift \
  -o "$scratch/macnotch-tray-transfer-check"
"$scratch/macnotch-tray-transfer-check"
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/ModuleCache" \
  macnotch/Sources/MacNotch/PDFFileActions.swift scripts/macnotch-pdf-actions-tests.swift \
  -framework AppKit -framework PDFKit -o "$scratch/macnotch-pdf-actions-check"
"$scratch/macnotch-pdf-actions-check"
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/ModuleCache" \
  macnotch/Sources/MacNotch/MediaArtwork.swift scripts/macnotch-media-artwork-tests.swift \
  -framework AppKit -o "$scratch/macnotch-media-artwork-check"
"$scratch/macnotch-media-artwork-check"
xcrun swiftc -swift-version 5 -module-cache-path "$scratch/ModuleCache" \
  macnotch/Sources/MacNotch/MediaPlaylist.swift scripts/macnotch-media-playlist-tests.swift \
  -framework AppKit -o "$scratch/macnotch-media-playlist-check"
"$scratch/macnotch-media-playlist-check"
