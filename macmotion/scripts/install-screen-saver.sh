#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-screen-saver.sh
dest="$HOME/Library/Screen Savers/MacMotion.saver"
mkdir -p "$(dirname "$dest")"
rm -rf "$dest"
ditto build/saver/MacMotion.saver "$dest"
echo "Installed: $dest"
echo "Now visit System Settings -> Wallpaper -> Screen Saver... -> Custom -> MacMotion"
