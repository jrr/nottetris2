#!/usr/bin/env bash
# Builds the game for Playdate into playdate/build/nottetris2.pdx, which runs in the Simulator
# and on the device. Needs the SDK and Arm's toolchain: `mise install` here, once (mise.toml).
#
#   playdate/build.sh          # build
#   playdate/build.sh --sim    # build and run it in the Simulator
#
# Source/ is put together here each time: this directory's Lua, the game's (its main.lua as
# game.lua, since Playdate's own entry point is main.lua) and its art. The C builds then add
# pdex.dylib (Simulator) and pdex.elf (device) to it, and pdc makes the pdx.
set -euo pipefail
cd "$(dirname "$0")"
eval "$(mise env -s bash)"

quiet() { # the SDK's cmake echoes every command: show the output only when a step fails
	local log
	log=$(mktemp)
	"$@" > "$log" 2>&1 || { cat "$log"; rm "$log"; return 1; }
	rm "$log"
}

rm -rf Source
mkdir -p Source build
cp main.lua platform_playdate.lua pdxinfo Source/
cp ../main.lua Source/game.lua
for f in gameA gameB menu failed rocket physics_chipmunk; do
	cp ../$f.lua Source/
done
cp -R ../graphics Source/

quiet cmake -S . -B build/sim -DPRODUCT_DIR="$PWD/build/sim"
quiet cmake --build build/sim -j
quiet cmake -S . -B build/device -DPRODUCT_DIR="$PWD/build/device" -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_TOOLCHAIN_FILE="$PLAYDATE_SDK_PATH/C_API/buildsupport/arm.cmake"
quiet cmake --build build/device -j

rm -rf build/nottetris2.pdx
pdc Source build/nottetris2.pdx
echo "built playdate/build/nottetris2.pdx"

if [ "${1:-}" = --sim ]; then
	exec "$PLAYDATE_SDK_PATH/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" "$PWD/build/nottetris2.pdx"
fi
