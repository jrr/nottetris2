#!/usr/bin/env python3
# Streams a USB-connected Playdate's console output (its print() and logToConsole) until Ctrl-C,
# or for --seconds. The serial console isn't documented by Panic; "echo on" makes it copy console
# output to the port.
#   playdate/console.py [--seconds N]
import glob, os, select, sys, termios, time, tty

def findport():
    if os.environ.get("PLAYDATE_PORT"):
        return os.environ["PLAYDATE_PORT"]
    ports = glob.glob("/dev/cu.usbmodemPD*")
    return ports[0] if ports else None

port = findport()
if not port:
    sys.exit("No Playdate found. Connect it by USB and unlock it (or set PLAYDATE_PORT).")

seconds = sys.argv[sys.argv.index("--seconds") + 1] if "--seconds" in sys.argv else None
end = time.time() + float(seconds) if seconds else None

fd = os.open(port, os.O_RDWR | os.O_NOCTTY)
tty.setraw(fd)
os.write(fd, b"echo on\n")
try:
    while end is None or time.time() < end:
        ready, _, _ = select.select([fd], [], [], 0.2)
        if ready:
            data = os.read(fd, 4096)
            if not data:
                break
            sys.stdout.write(data.decode(errors="replace").replace("\r\n", "\n"))
            sys.stdout.flush()
except KeyboardInterrupt:
    pass
except OSError as e:
    print(f"\nlost the connection: {e}", file=sys.stderr)
finally:
    try:
        os.write(fd, b"echo off\n")
        os.close(fd)
    except OSError:
        pass
