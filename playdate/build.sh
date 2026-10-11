#!/usr/bin/env bash
# Builds the game for Playdate into playdate/build/nottetris2.pdx, which runs in the Simulator
# and on the device. Needs the SDK and Arm's toolchain: `mise install` here, once (mise.toml).
#
#   playdate/build.sh           # build
#   playdate/build.sh --sim     # build and run it in the Simulator
#   playdate/build.sh --device  # build, copy it to a USB-connected Playdate, run it there and
#                               # show its console output (until Ctrl-C)
#
# Source/ is put together here each time: this directory's Lua, the game's (its main.lua as
# game.lua, since Playdate's own entry point is main.lua) and its art, and the C built for the
# Simulator (pdex.dylib) and the device (pdex.elf); pdc makes the pdx from it.
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
cp main.lua platform_playdate.lua perf.lua pdxinfo Source/
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
# The SDK's cmake copies the binaries into Source/ only when it relinks them, and Source/ is new
# each time, so copy them here: pdex.dylib for the Simulator, pdex.elf (stripped) for the device.
cp build/sim/libnottetris2.dylib Source/pdex.dylib
arm-none-eabi-strip --strip-unneeded -R .comment -g build/device/nottetris2_DEVICE.elf -o Source/pdex.elf

rm -rf build/nottetris2.pdx
pdc Source build/nottetris2.pdx
echo "built playdate/build/nottetris2.pdx"

if [ "${1:-}" = --sim ]; then
	exec "$PLAYDATE_SDK_PATH/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator" "$PWD/build/nottetris2.pdx"
fi

if [ "${1:-}" = --device ]; then
	waitfor() { # up to a minute for a path to exist, or with !, not to
		for _ in $(seq 120); do
			if [ "$1" = "!" ]; then [ ! -e "$2" ] && return; else [ -e "$1" ] && return; fi
			sleep 0.5
		done
		echo "timed out waiting for $*" >&2
		exit 1
	}
	findport() { ls /dev/cu.usbmodemPD* 2> /dev/null | head -1; }
	volume=/Volumes/PLAYDATE
	# the mount point shows up before the disk is mounted on it, so wait for a folder inside
	if [ ! -d "$volume/Games" ]; then
		port=${PLAYDATE_PORT:-$(findport)}
		[ -n "$port" ] || { echo "No Playdate found. Connect it by USB and unlock it (or set PLAYDATE_PORT)." >&2; exit 1; }
		pdutil "$port" datadisk
		waitfor "$volume/Games"
	fi
	rm -rf "$volume/Games/nottetris2.pdx" "$volume/Games/._nottetris2.pdx"
	cp -RX build/nottetris2.pdx "$volume/Games/" # -X: no ._ files for macOS's extended attributes
	diff -rq build/nottetris2.pdx "$volume/Games/nottetris2.pdx" || { echo "the copy on the Playdate doesn't match" >&2; exit 1; }
	diskutil eject "$volume" > /dev/null
	waitfor ! "$volume"
	# the serial port goes away while the disk is mounted and comes back once it's ejected
	for _ in $(seq 60); do
		port=${PLAYDATE_PORT:-$(findport)}
		[ -n "$port" ] && [ -e "$port" ] && break
		sleep 0.5
	done
	[ -n "$port" ] || { echo "timed out waiting for the Playdate's serial port; the game is in /Games on it" >&2; exit 1; }
	sleep 1
	pdutil "$port" run /Games/nottetris2.pdx
	exec ./console.py
fi
