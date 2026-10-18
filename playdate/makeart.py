#!/usr/bin/env python3
"""The Playdate's own drawing of game A's background and the title, made from the Game Boy art
(graphics/gamebackgroundgamea.png, title.png), which scaled by 240/144 has its pixels unevenly one
or two wide. Writes art/gamebackgroundgamea.png and art/title.png, which platform_playdate.lua
draws instead; panel.lua, where the panel's rows are; and art/fonts/, the SDK's Nontendo Bold with
the characters it hasn't that the art needs (GLYPHS). All are committed: run this (with Pillow,
under this directory's `mise env`, for the SDK's fonts) only to change them.

    cd playdate && eval "$(mise env -s bash)" && python3 makeart.py

The field keeps the game's 240/144 (the pieces are drawn there at it), with its walls redrawn
in whole pixels: a row of bricks is 5 pixels, the Game Boy's 3. The panel beside it is drawn
twice as wide and, down the screen, with each thin line two rows and the rest sharing what's
left, so that its lines are all two pixels and it fits the 240 rows. The Game Boy's colors
become black, white and dithers: its dark brown a checkerboard, its light brown one pixel in
four. The field is plain white, without the Game Boy's grey stripes. Its labels are drawn in
Nontendo Bold, as are the numbers (platform.drawhud). The title is traced and drawn again
(maketitle)."""
import math
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

COLORS = {(0, 0, 0): "#", (116, 92, 73): "d", (209, 174, 145): "l", (232, 232, 232): "g", (255, 255, 255): ".",
          (112, 88, 72): "d", (208, 168, 144): "l"}  # (the title's browns are a little different)


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


def loadfont(name, fonts=None):
    """A Playdate font: {char: rows of 0/1}, its tracking, and its cells' height (from the SDK's
    fonts, or another folder)"""
    fonts = fonts or os.path.join(os.environ["PLAYDATE_SDK_PATH"], "Resources", "Fonts")
    fnt = os.path.join(fonts, name + ".fnt")
    folder = os.path.dirname(fnt)
    table = next(f for f in os.listdir(folder) if f.startswith(os.path.basename(name) + "-table-"))
    cw, ch = map(int, re.findall(r"-table-(\d+)-(\d+)", table)[0])
    image = Image.open(os.path.join(folder, table)).convert("RGBA")
    columns = image.width // cw
    tracking, chars = 0, []
    for line in open(fnt, encoding="utf-8"):
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


# characters the font hasn't, in its style (strokes two pixels, capitals and digits ten rows): the +
# of the score just added, and the title's > and (c)
GLYPHS = {
    "+": ["......",
          "......",
          "..##..",
          "..##..",
          "######",
          "######",
          "..##..",
          "..##..",
          "......",
          "......"],
    ">": ["......",
          "##....",
          "###...",
          ".###..",
          "..####",
          "..####",
          ".###..",
          "###...",
          "##....",
          "......"],
    "\u00a9": ["..######..",
               ".##....##.",
               "##..###..#",
               "#..##..#.#",
               "#..##....#",
               "#..##....#",
               "#..##..#.#",
               "##..###..#",
               ".##....##.",
               "..######.."],
}


def addglyphs():
    """the font with GLYPHS added, in cells its table has spare"""
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
    lines = []
    for c, rows in GLYPHS.items():
        assert n < columns*(image.height // ch), "no spare cell"
        x0, y0 = (n % columns)*cw, (n // columns)*ch
        for y, row in enumerate(rows):
            for x, ink in enumerate(row):
                if ink == "#":
                    image.putpixel((x0 + x, y0 + y), (0, 0, 0, 255))
        lines.append("%s\t\t%d\n" % (c, len(rows[0])))
        n += 1
    out = os.path.join(HERE, "art", "fonts")
    os.makedirs(out, exist_ok=True)
    image.save(os.path.join(out, table))
    with open(os.path.join(out, name + ".fnt"), "w", encoding="utf-8") as f:
        f.write(fnt.rstrip("\n") + "\n" + "".join(lines))


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


# The title: traced and drawn again at the Playdate's size, rather than its pixels scaled. Each
# color, with those darker than it, is traced as outlines; the outlines' pixel staircases become
# the diagonals and curves they stand for; and they're filled at 5/3 the size, where the Game Boy's
# pixel edges are put so that its one-pixel lines all come out two pixels.
DIRS = [(1, 0), (0, 1), (-1, 0), (0, -1)]  # E S W N: clockwise, y down
LONG = 5  # a side this long (Game Boy pixels) is straight: a staircase doesn't go through it
LIGHTDOMES = True  # the light brown inside the domes white, so that they stand out from the sky


def trace(inside, w, h):
    """a mask's outlines: loops of (corner, the direction on from it), the inside on the right.
    Pixels that touch at a corner are one shape: at a corner with two ways on, the loop turns left."""
    out = {}
    def add(a, b, d):
        out.setdefault(a, []).append((b, d))
    for y in range(h):
        for x in range(w):
            if not inside(x, y):
                continue
            if not inside(x, y - 1): add((x, y), (x + 1, y), 0)
            if not inside(x + 1, y): add((x + 1, y), (x + 1, y + 1), 1)
            if not inside(x, y + 1): add((x + 1, y + 1), (x, y + 1), 2)
            if not inside(x - 1, y): add((x, y + 1), (x, y), 3)
    loops = []
    while out:
        v = next(iter(out))
        d = out[v][0][1]
        steps = []
        while out.get(v):
            ways = out[v]
            pick = min(ways, key=lambda e: [(d + 3) % 4, d, (d + 1) % 4, (d + 2) % 4].index(e[1]))
            ways.remove(pick)
            if not ways:
                del out[v]
            steps.append((v, pick[1]))
            v, d = pick
        loops.append([p for i, p in enumerate(steps) if p[1] != steps[i - 1][1]])  # its corners
    return loops


def smooth(loop):
    """a loop's points: its corners, except that three or more turns in a row alternating left and
    right (not across a long side) are a staircase, a diagonal or a curve, drawn through the middles
    of its sides (or half a pixel along, at its ends)"""
    n = len(loop)
    if n < 4:
        return [c for c, _ in loop]
    sides = []  # side k: from corner k to corner k + 1: its direction and length
    for k in range(n):
        (x0, y0), d = loop[k]
        x1, y1 = loop[(k + 1) % n][0]
        sides.append((d, abs(x1 - x0) + abs(y1 - y0)))
    turn = [(sides[k][0] - sides[k - 1][0]) % 4 for k in range(n)]  # at corner k: 1 right, 3 left
    linked = [turn[k] != turn[(k + 1) % n] and sides[k][1] < LONG for k in range(n)]  # corners k, k + 1
    instair = [False]*n
    if all(linked):
        instair = [True]*n
    else:
        k0 = linked.index(False)
        run = []
        for i in range(n):  # from just after a corner that ends a run, around to it
            k = (k0 + 1 + i) % n
            run.append(k)
            if not linked[k]:
                if len(run) >= 3:
                    for c in run:
                        instair[c] = True
                run = []
    points = []
    for k in range(n):
        (x, y), d = loop[k]
        dx, dy = DIRS[d]
        length = sides[k][1]
        a, b = instair[k], instair[(k + 1) % n]
        if not a:
            points.append((x, y))
        h = min(length, 1)/2
        if a and b:
            points.append((x + dx*length/2, y + dy*length/2))
        else:
            if a:
                points.append((x + dx*h, y + dy*h))
            if b:
                points.append((x + dx*(length - h), y + dy*(length - h)))
    return points


def axismap(weights, total):
    """where on the screen the Game Boy's pixel edges along an axis go: each pixel 1 or 2 wide, never
    more than one off in proportion, and as much weight as can be on the 2s"""
    n = len(weights)
    layers = [{0: (0, None)}]  # edge i: {screen position: (best weight, position of edge i - 1)}
    for i in range(1, n + 1):
        lo, hi = (total, total) if i == n else (round(i*total/n) - 1, round(i*total/n) + 1)
        here = {}
        for p, (score, _) in layers[-1].items():
            for step in (1, 2):
                q, s = p + step, score + (weights[i - 1] if step == 2 else 0)
                if lo <= q <= hi and (q not in here or s > here[q][0]):
                    here[q] = (s, p)
        layers.append(here)
    edges = [total]
    for i in range(n, 0, -1):
        edges.append(layers[i][edges[-1]][1])
    return edges[::-1]


def thinness(get, n, m):
    """for each of n lines, how many one-pixel-wide things cross it (of m)"""
    return [0.01 + sum(1 for j in range(m)
                       if (i == 0 or get(i - 1, j) != get(i, j)) and (i == n - 1 or get(i + 1, j) != get(i, j)))
            for i in range(n)]


def along(edges, v):
    i = min(int(v), len(edges) - 2)
    return edges[i] + (v - i)*(edges[i + 1] - edges[i])


def fill(image, loops, ink):
    """fills loops of points (even-odd), the pixels whose centers are inside, with ink(x, y)"""
    lines = [(loop[i - 1], loop[i]) for loop in loops for i in range(len(loop)) if loop[i - 1][1] != loop[i][1]]
    for y in range(image.height):
        cy = y + 0.5
        xs = sorted(x0 + (cy - y0)*(x1 - x0)/(y1 - y0) for (x0, y0), (x1, y1) in lines
                    if y0 <= cy < y1 or y1 <= cy < y0)
        for a, b in zip(xs[0::2], xs[1::2]):
            for x in range(max(0, math.floor(a)), min(image.width, math.ceil(b))):
                if a <= x + 0.5 < b:
                    image.putpixel((x, y), ink(x, y))


def regions(grid, code, y0, y1):
    """the 4-connected regions of a color, between rows y0 and y1"""
    seen, out = set(), []
    for y in range(y0, y1):
        for x in range(len(grid[0])):
            if grid[y][x] != code or (x, y) in seen:
                continue
            region, todo = [], [(x, y)]
            seen.add((x, y))
            while todo:
                px, py = todo.pop()
                region.append((px, py))
                for nx, ny in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
                    if 0 <= nx < len(grid[0]) and y0 <= ny < y1 and grid[ny][nx] == code and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        todo.append((nx, ny))
            out.append(region)
    return out


def spans(grid, code, y0, y1, gap):
    """the runs of columns with a color between rows y0 and y1, apart where there's more than gap
    without: the words of a line of text"""
    columns = [x for x in range(len(grid[0])) if any(grid[y][x] == code for y in range(y0, y1))]
    out = [[columns[0], columns[0]]]
    for x in columns[1:]:
        if x - out[-1][1] > gap:
            out.append([x, x])
        else:
            out[-1][1] = x
    return out


def maketitle(font):
    art = Image.open(os.path.join(HERE, "..", "graphics", "title.png")).convert("RGB")
    W, H = art.size
    MENU, SCENE = 123, (79, 122)  # where the menu starts (lettered, not traced); the scene's rows
    original = [[COLORS[art.getpixel((x, y))] for x in range(W)] for y in range(H)]
    grid = [row[:] if y < MENU else ["."]*W for y, row in enumerate(original)]

    stars = []  # white specks in the sky, drawn as crosses: traced, they'd be lost in its dots
    for region in regions(grid, ".", *SCENE):
        if len(region) <= 4:
            stars.append((sum(x for x, _ in region)/len(region) + 0.5, sum(y for _, y in region)/len(region) + 0.5))
            for x, y in region:
                grid[y][x] = "l"
    if LIGHTDOMES:
        for region in regions(grid, "l", *SCENE):
            if len(region) <= 50 or min(y for _, y in region) > 83:  # not the sky
                for x, y in region:
                    grid[y][x] = "."

    width, scale = round(W*SCALE), SCALE
    xs = axismap(thinness(lambda x, y: grid[y][x], W, MENU), width)
    ys = axismap(thinness(lambda y, x: grid[y][x], MENU, W), round(MENU*scale))
    image = Image.new("1", (width, 240), WHITE)
    for codes, ink in [("ld#", lambda x, y: dither("l", x, y)), ("d#", lambda x, y: dither("d", x, y)),
                       ("#", lambda x, y: BLACK)]:
        inside = lambda x, y: 0 <= x < W and 0 <= y < MENU and grid[y][x] in codes
        fill(image, [[(along(xs, x), along(ys, y)) for x, y in smooth(loop)] for loop in trace(inside, W, MENU)], ink)
    for sx, sy in stars:
        cx, cy = int(along(xs, sx)), int(along(ys, sy))
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            image.putpixel((cx + dx, cy + dy), WHITE)

    # the menu, lettered where the Game Boy's words are, with its cursor (which never moves) and its
    # light brown lines under the words dark
    def sx(x):
        return round(x*scale)
    def centered(text, x0, x1, y):
        drawtext(image, font, text, (sx(x0) + sx(x1 + 1))//2 - textwidth(font, text)//2, sx(y))
    for (x0, x1), word in zip(spans(original, "#", 125, 131, 5), ["1PLY", "2PLY", "OPTIONS"]):
        centered(word, x0, x1, 125)
    line = spans(original, "#", 135, 143, W)[0]
    centered("\u00a92011 Maurice", line[0], line[1], 136)
    for x0, x1 in spans(original, "l", 132, 133, 3):
        for x in range(sx(x0), sx(x1 + 1)):
            for y in (sx(132), sx(132) + 1):
                image.putpixel((x, y), dither("d", x, y))
    drawtext(image, font, ">", sx(1), sx(125))
    image.save(os.path.join(HERE, "art", "title.png"))


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
    addglyphs()
    maketitle(loadfont(os.path.basename(FONT), os.path.join(HERE, "art", "fonts")))
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
    print("wrote art/gamebackgroundgamea.png, art/title.png, art/fonts/ and panel.lua")


if __name__ == "__main__":
    main()
