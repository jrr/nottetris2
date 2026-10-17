#!/usr/bin/env python3
"""The Playdate's own drawing of game A's background, made from the Game Boy art
(graphics/gamebackgroundgamea.png), which scaled by 240/144 has its pixels unevenly one or two
wide. Writes art/gamebackgroundgamea.png, which platform_playdate.lua draws instead; panel.lua,
where its panel's rows are; and art/fonts/, the SDK's Nontendo Bold with a + added (for the score
just added), which it has none of. All are committed: run this (with Pillow, under this directory's
`mise env`, for the SDK's fonts) only to change them.

    cd playdate && eval "$(mise env -s bash)" && python3 makeart.py

The field keeps the game's 240/144 (the pieces are drawn there at it), with its walls redrawn
in whole pixels: a row of bricks is 5 pixels, the Game Boy's 3. The panel beside it is drawn
twice as wide and, down the screen, with each thin line two rows and the rest sharing what's
left, so that its lines are all two pixels and it fits the 240 rows. The Game Boy's colors
become black, white and dithers: its dark brown a checkerboard, its light brown one pixel in
four. The field is plain white, without the Game Boy's grey stripes. Its labels are
drawn in the SDK's Nontendo Bold, as are the numbers (platform.drawhud)."""
import os
import re
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SCALE = 5/3
WIDTH = 334  # from the game's x 0 (OFFSETX on the screen) to the screen's right edge
BLACK, WHITE = 0, 1
PANELX = 104  # Game Boy x where the panel starts: a white line, then the boxes
LABELS = [("SCORE", 8, 17), ("LEVEL", 47, 56), ("LINES", 71, 80)]  # label, Game Boy rows of its box's inside
FONT = "Nontendo/Nontendo-Bold"

COLORS = {(0, 0, 0): "#", (116, 92, 73): "d", (209, 174, 145): "l", (232, 232, 232): "g", (255, 255, 255): "."}


def dither(code, x, y):
    if code == "#":
        return BLACK
    if code == ".":
        return WHITE
    if code == "d":
        return BLACK if (x + y) % 2 == 0 else WHITE
    if code == "l":
        return BLACK if x % 2 == 0 and y % 2 == 0 else WHITE
    if code == "g":  # only in the field, which is drawn plain
        return WHITE


def loadfont(name):
    """A Playdate font: {char: rows of 0/1}, its tracking, and its cells' height"""
    fonts = os.path.join(os.environ["PLAYDATE_SDK_PATH"], "Resources", "Fonts")
    fnt = os.path.join(fonts, name + ".fnt")
    folder = os.path.dirname(fnt)
    table = next(f for f in os.listdir(folder) if f.startswith(os.path.basename(name) + "-table-"))
    cw, ch = map(int, re.findall(r"-table-(\d+)-(\d+)", table)[0])
    image = Image.open(os.path.join(folder, table)).convert("RGBA")
    columns = image.width // cw
    tracking, chars = 0, []
    for line in open(fnt):
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("--") or re.match(r"^[a-zA-Z]{2,}=", line):
            if line.startswith("tracking="):
                tracking = int(line.split("=")[1])
            continue
        key = line.split("\t")[0]
        key = " " if key == "space" else key
        if len(key) == 1:  # not a kerning pair
            chars.append((key, int(line.split("\t")[-1])))
    glyphs = {}
    for n, (c, w) in enumerate(chars):
        x0, y0 = (n % columns)*cw, (n // columns)*ch
        glyphs[c] = [[1 if image.getpixel((x0 + x, y0 + y))[3] > 128 else 0 for x in range(w)] for y in range(ch)]
    return glyphs, tracking, ch


def textwidth(font, s):
    glyphs, tracking, _ = font
    return sum(len(glyphs[c][0]) + tracking for c in s) - tracking


def inkrows(font, chars):
    glyphs, _, height = font
    rows = [y for y in range(height) if any(any(glyphs[c][y]) for c in chars)]
    return rows[0], rows[-1]


def drawtext(image, font, s, x, y):
    glyphs, tracking, _ = font
    for c in s:
        for gy, row in enumerate(glyphs[c]):
            for gx, ink in enumerate(row):
                if ink:
                    image.putpixel((x + gx, y + gy), BLACK)
        x += len(glyphs[c][0]) + tracking


def addplus():
    """the font with a +, in a cell its table has spare: as wide as its digits, its strokes as thick"""
    fonts = os.path.join(os.environ["PLAYDATE_SDK_PATH"], "Resources", "Fonts")
    folder = os.path.join(fonts, os.path.dirname(FONT))
    name = os.path.basename(FONT)
    fnt = open(os.path.join(folder, name + ".fnt")).read()
    table = next(f for f in os.listdir(folder) if f.startswith(name + "-table-"))
    cw, ch = map(int, re.findall(r"-table-(\d+)-(\d+)", table)[0])
    image = Image.open(os.path.join(folder, table)).convert("RGBA")
    glyphs = [l for l in fnt.splitlines() if l.strip() and not re.match(r"^[a-zA-Z]{2,}=", l) and len(l.split("\t")[0]) in (1, 5)]
    n = len(glyphs)  # the next cell
    columns = image.width // cw
    assert n < columns*(image.height // ch), "no spare cell"
    x0, y0 = (n % columns)*cw, (n // columns)*ch
    for y in range(2, 8):  # the digits' ink is rows 0-9: a + across the middle
        for x in range(2, 4):
            image.putpixel((x0 + x, y0 + y), (0, 0, 0, 255))
    for y in range(4, 6):
        for x in range(0, 6):
            image.putpixel((x0 + x, y0 + y), (0, 0, 0, 255))
    out = os.path.join(HERE, "art", "fonts")
    os.makedirs(out, exist_ok=True)
    image.save(os.path.join(out, table))
    with open(os.path.join(out, name + ".fnt"), "w") as f:
        f.write(fnt.rstrip("\n") + "\n+\t\t6\n")


def bricks(image, x0, x1):
    """a wall: rows of bricks 4 pixels high with a line of mortar, 7 wide, every other row half a brick along"""
    draw = ImageDraw.Draw(image)
    draw.rectangle((x0, 0, x1 - 1, 239), fill=WHITE)
    for row, y in enumerate(range(0, 240, 5)):
        draw.line((x0, y + 4, x1 - 1, y + 4), fill=BLACK)
        for x in range(x0 - 7 + (3 if row % 2 else 0), x1, 7):
            if x0 <= x + 6 < x1:
                draw.line((x + 6, y, x + 6, y + 3), fill=BLACK)
    draw.line((x0, 0, x0, 239), fill=BLACK)
    draw.line((x1 - 1, 0, x1 - 1, 239), fill=BLACK)


def main():
    art = Image.open(os.path.join(HERE, "..", "graphics", "gamebackgroundgamea.png")).convert("RGBA")
    grid = [[COLORS[art.getpixel((x, y))[:3]] for x in range(160)] for y in range(144)]
    font = loadfont(FONT)

    # the panel's labels come out: they're drawn in the font
    for _, top, bottom in LABELS:
        for y in range(top + 1, bottom):
            for x in range(112, 153):
                if grid[y][x] == "#":
                    grid[y][x] = "."

    # the panel's rows: a thin line (a row unlike both its neighbors, across the panel) is two
    # screen rows; each run of others shares what's left so that the run ends where 240/144 says
    def panelrow(y):
        return grid[y][PANELX:]
    heights = [2 if 0 < y < 143 and panelrow(y) != panelrow(y - 1) and panelrow(y) != panelrow(y + 1) else None
               for y in range(144)]
    y = total = 0
    while y < 144:
        if heights[y] == 2:
            total += 2
            y += 1
            continue
        run = []
        while y < 144 and heights[y] != 2:
            run.append(y)
            y += 1
        twos = max(0, min(len(run), round(y*SCALE) - total - len(run)))
        for k, r in enumerate(run):
            heights[r] = 2 if k*twos // len(run) != (k + 1)*twos // len(run) else 1
        total += sum(heights[r] for r in run)
    assert total == 240, total
    rowstart = [sum(heights[:y]) for y in range(145)]

    image = Image.new("1", (WIDTH, 240), BLACK)
    draw = ImageDraw.Draw(image)

    # the field, plain white (not the Game Boy's grey stripes), and its walls; and left of them,
    # white as at the Game Boy, where game A's line meter is drawn
    draw.rectangle((24, 0, 159, 239), fill=WHITE)
    draw.rectangle((0, 0, 9, 239), fill=WHITE)
    bricks(image, 10, 24)
    bricks(image, 160, 174)

    # the panel, twice as wide, to the screen's edge (the score's band goes on as at the Game Boy's)
    panelleft = 174
    for y in range(144):
        for r in range(heights[y]):
            sy = rowstart[y] + r
            for sx in range(panelleft, WIDTH):
                x = min(PANELX + (sx - panelleft)//2, 159)
                image.putpixel((sx, sy), dither(grid[y][x], sx, sy))

    def screenx(x):
        return panelleft + (x - PANELX)*2
    inktop, inkbottom = inkrows(font, "SCORELVINS0123456789")
    for label, top, bottom in LABELS:
        x = (screenx(111) + screenx(153))//2 - textwidth(font, label)//2
        y = (rowstart[top + 1] + rowstart[bottom]) // 2 - (inktop + inkbottom + 1)//2
        drawtext(image, font, label, x, y)

    os.makedirs(os.path.join(HERE, "art"), exist_ok=True)
    addplus()
    image.save(os.path.join(HERE, "art", "gamebackgroundgamea.png"))
    with open(os.path.join(HERE, "panel.lua"), "w") as out:
        out.write("--Made by makeart.py: where game A's panel is in art/gamebackgroundgamea.png. The panel is\n"
                  "--twice as wide as at the Game Boy from PANELX on (Game Boy pixels), and ROWS[y + 1] is where its\n"
                  "--Game Boy row y starts. INKTOP and INKBOTTOM are the rows of the font's cells letters and digits\n"
                  "--fill, for centering them.\n")
        out.write("panel = {\n")
        out.write("\tPANELX = %d, LEFT = %d, FONT = %r,\n" % (PANELX, panelleft, "fonts/" + os.path.basename(FONT)))
        out.write("\tINKTOP = %d, INKBOTTOM = %d,\n" % (inktop, inkbottom))
        out.write("\tROWS = {" + ", ".join(str(r) for r in rowstart) + "},\n")
        out.write("}\n")
    print("wrote art/gamebackgroundgamea.png and panel.lua")


main()
