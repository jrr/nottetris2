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
BLACK, WHITE = 0, 1
PANELX = 104  # Game Boy x where the panel starts: a white line, then the boxes
BOXES = [((5, 18), (109, 154)), ((45, 90), (109, 154)), ((99, 140), (115, 156))]  # the panel's boxes:
# Game Boy rows and columns (the score's label and its joins to the band; level's and lines'; next's)
LABELS = [("SCORE", 6, 17), ("LEVEL", 47, 56), ("LINES", 71, 80)]  # label, Game Boy rows of its box's inside
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


def drawtext(image, font, s, x, y, ink=lambda x, y: BLACK):
    glyphs, tracking, _ = font
    for c in s:
        for gy, row in enumerate(glyphs[c]):
            for gx, inked in enumerate(row):
                if inked:
                    image.putpixel((x + gx, y + gy), ink(x + gx, y + gy))
        x += len(glyphs[c][0]) + tracking


# characters the font hasn't, in its style (strokes two pixels, capitals and digits ten rows): the +
# of the score just added, the game over's heart, and the title's > and (c)
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
    "\u2665": [".........",
               ".###.###.",
               "#########",
               "#########",
               "#########",
               ".#######.",
               "..#####..",
               "...###...",
               "....#....",
               "........."],
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
    """the font with GLYPHS added, in cells its table has spare (or in a row more of them)"""
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
        if n >= columns*(image.height // ch):  # another row of cells
            grown = Image.new("RGBA", (image.width, image.height + ch), (0, 0, 0, 0))
            grown.paste(image, (0, 0))
            image = grown
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
        if a and b and linked[k]:  # a side within a staircase (not a long one between two)
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


def redraw(grid, rows, width=None):
    """a Game Boy screen's rows down to rows, traced and drawn again at 5/3 the size (240 high; and
    across, that or width): the image, and where the Game Boy's pixel edges went across and down"""
    W = len(grid[0])
    xs = axismap(thinness(lambda x, y: grid[y][x], W, rows), width or round(W*SCALE))
    ys = axismap(thinness(lambda y, x: grid[y][x], rows, W), round(rows*SCALE))
    image = Image.new("1", (xs[-1], 240), WHITE)
    for codes, ink in [("ld#", lambda x, y: dither("l", x, y)), ("d#", lambda x, y: dither("d", x, y)),
                       ("#", lambda x, y: BLACK)]:
        inside = lambda x, y: 0 <= x < W and 0 <= y < rows and grid[y][x] in codes
        fill(image, [[(along(xs, x), along(ys, y)) for x, y in smooth(loop)] for loop in trace(inside, W, rows)], ink)
    return image, xs, ys


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

    image, xs, ys = redraw(grid, MENU)
    scale = SCALE
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


# The menu (game type, music type and top scores): traced as the title is, but its words are
# lettered. Its boxes' insides are emptied and the words set in them: the headings black, and every
# choice grey, as the Game Boy has them light brown; platform.drawmenu letters the chosen ones black
# over them, and the top scores (menuart.lua says where). The specks in its light brown are left out.
HEADINGS = ["GAME TYPE", "MUSIC TYPE", "TOP-SCORE"]
CHOICES = ["NORMAL", "STACK", "A-TYPE", "B-TYPE", "C-TYPE", "OFF"]


def blobs(grid, inside):
    """the 4-connected regions where inside(code) (as regions(), for more than one color)"""
    W, H = len(grid[0]), len(grid)
    seen, out = set(), []
    for y in range(H):
        for x in range(W):
            if not inside(grid[y][x]) or (x, y) in seen:
                continue
            region, todo = [], [(x, y)]
            seen.add((x, y))
            while todo:
                px, py = todo.pop()
                region.append((px, py))
                for nx, ny in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
                    if 0 <= nx < W and 0 <= ny < H and inside(grid[ny][nx]) and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        todo.append((nx, ny))
            out.append(region)
    return out


def bounds(region):
    return (min(x for x, _ in region), min(y for _, y in region), max(x for x, _ in region) + 1,
            max(y for _, y in region) + 1)


def makemenu(font):
    art = Image.open(os.path.join(HERE, "..", "graphics", "gametype.png")).convert("RGB")
    W, H = art.size
    grid = [[COLORS[art.getpixel((x, y))] for x in range(W)] for y in range(H)]

    # the boxes: white regions of some size, not the margins around everything; emptied of what's
    # inside them (what doesn't reach out of them: their own borders do)
    boxes = sorted((bounds(r) for r in blobs(grid, lambda c: c == ".") if len(r) >= 100),
                   key=lambda b: (b[1], b[0]))
    boxes = [b for b in boxes if b[2] - b[0] < 150]
    for x0, y0, x1, y1 in boxes:
        for blob in blobs([[c if x0 <= x < x1 and y0 <= y < y1 else "." for x, c in enumerate(row)]
                           for y, row in enumerate(grid)], lambda c: c != "."):
            bx0, by0, bx1, by1 = bounds(blob)
            if x0 < bx0 and bx1 < x1 and y0 < by0 and by1 < y1:
                for x, y in blob:
                    grid[y][x] = "."
    assert len(boxes) == 11, boxes  # 3 headings, 6 choices, the ranks and the scores
    specks = [(x, y) for y in range(1, H - 1) for x in range(1, W - 1) if grid[y][x] == "#" and
              [grid[y][x - 1], grid[y][x + 1], grid[y - 1][x], grid[y + 1][x]].count("#") <= 1]
    for x, y in specks:  # on its own, or on the edge of a box (a border's pixels have two or more beside them)
        grid[y][x] = "l"

    image, xs, ys = redraw(grid, H)
    inktop, inkbottom = inkrows(font, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    def screen(box):
        x0, y0, x1, y1 = box
        return xs[x0], ys[y0], xs[x1], ys[y1]
    def centered(text, box, ink=lambda x, y: BLACK):
        x0, y0, x1, y1 = screen(box)
        x = (x0 + x1)//2 - textwidth(font, text)//2
        y = (y0 + y1)//2 - (inktop + inkbottom + 1)//2
        drawtext(image, font, text, x, y, ink)
        return x, y
    headings = [boxes[0], boxes[3], boxes[8]]
    for text, box in zip(HEADINGS, headings):
        centered(text, box)
    choices = []
    for text, box in zip(CHOICES, boxes[1:3] + boxes[4:8]):
        choices.append(centered(text, box, lambda x, y: dither("d", x, y)))

    # the top scores: three rows, 8 Game Boy pixels apart from 110, with their ranks; a name from
    # x 33, a score to 145, and a dotted line along each until they're filled in
    ranks, scores = boxes[9], boxes[10]
    rows = []
    for i in range(3):
        top, bottom = ys[110 + 8*i], ys[118 + 8*i]
        y = (top + bottom)//2 - (inktop + inkbottom + 1)//2
        rows.append(y)
        centered(str(i + 1), (ranks[0], 110 + 8*i, ranks[2], 118 + 8*i))
        dots = (top + bottom)//2
        for x0, x1 in ((33, 80), (97, 144)):
            for x in range(xs[x0], xs[x1], 3):
                image.putpixel((x, dots), BLACK)
    image.save(os.path.join(HERE, "art", "gametype.png"))

    with open(os.path.join(HERE, "menuart.lua"), "w") as out:
        out.write("--Made by makeart.py: where the menu's words go in art/gametype.png. CHOICES: each choice's\n"
                  "--text and its top left; ROWS: the top scores' rows' tops, a name from NAMEX and a score to\n"
                  "--SCORERIGHT; and between, from LINEFROM to LINETO, their dotted lines.\n")
        out.write("menuart = {\n")
        out.write("\tCHOICES = {" + ", ".join('{"%s", %d, %d}' % (t, x, y) for t, (x, y) in zip(CHOICES, choices)) + "},\n")
        out.write("\tROWS = {%s},\n" % ", ".join(str(r) for r in rows))
        out.write("\tNAMEX = %d, SCORERIGHT = %d, LINEFROM = %d, LINETO = %d,\n" % (xs[33], xs[145], xs[scores[0]], xs[scores[2]]))
        out.write("}\n")


# Game A's game over, over its field: the box traced and drawn again as the title is, as wide as the
# field, its words lettered; and below it PLEASE TRY AGAIN, each word further along as at the Game Boy
# but the three centred, on dotted lines. The whole screen, clear but for the field (the game draws it
# over the background).
def makegameover(font, offset):
    art = Image.open(os.path.join(HERE, "..", "graphics", "gameovercutoff.png")).convert("RGB")
    W, H = art.size  # Game Boy x 14 on: the field (its box from 11 to 70)
    original = [[COLORS[art.getpixel((x, y))] for x in range(W)] for y in range(H)]
    grid = [row[:] if y < 70 else ["."]*W for y, row in enumerate(original)]  # the box, emptied
    for y in range(23, 65):
        for x in range(15, 67):
            grid[y][x] = "."
    field = 136  # the field's width on the screen (from the game's x 24)
    image, xs, ys = redraw(grid, H, field)
    inktop, inkbottom = inkrows(font, "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    def textat(top, bottom):  # where text goes centred on the Game Boy's rows top to bottom
        return (ys[top] + ys[bottom + 1])//2 - (inktop + inkbottom + 1)//2
    for word, top, line in (("GAME", 33, 40), ("OVER", 49, 56)):
        x = (xs[11] + xs[71])//2 - textwidth(font, word)//2
        drawtext(image, font, word, x, textat(top, top + 5))
        for y in (ys[line], ys[line] + 1):  # its light brown line, dark
            for lx in range(x - 2, x + textwidth(font, word) + 2):
                image.putpixel((lx, y), dither("d", lx, y))
    words = (("PLEASE", 97, 104), ("TRY", 113, 120), ("AGAIN\u2665", 129, 136))
    step = round(8*SCALE)  # each word a Game Boy letter on from the one above
    block = max(i*step + textwidth(font, w) for i, (w, _, _) in enumerate(words))
    left = (field - block)//2
    for i, (word, top, line) in enumerate(words):
        x = left + i*step
        drawtext(image, font, word, x, textat(top, top + 5))
        for dx in range(x - 1, x + textwidth(font, word) + 1, 3):
            image.putpixel((dx, ys[line]), BLACK)
    screen = Image.new("LA", (400, 240), (0, 0))
    screen.paste(image.convert("L").convert("LA"), (offset + 24, 0))
    screen.save(os.path.join(HERE, "art", "gameovercutoff.png"))


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

    # the whole screen: the game's x 0 is OFFSET along it, as platform_playdate.lua has it (OFFSETX)
    OFFSET = math.floor((400 - 160*SCALE)/2)
    image = Image.new("1", (400, 240), BLACK)
    draw = ImageDraw.Draw(image)

    # the field, plain white (not the Game Boy's grey stripes), and its walls; and left of them,
    # white as at the Game Boy, where game A's line meter is drawn
    draw.rectangle((OFFSET + 24, 0, OFFSET + 159, 239), fill=WHITE)
    draw.rectangle((OFFSET, 0, OFFSET + 9, 239), fill=WHITE)
    bricks(image, OFFSET + 10, OFFSET + 24)
    bricks(image, OFFSET + 160, OFFSET + 174)

    # the panel, twice as wide: its white line by the wall, then from LEFT to the screen's edge each
    # of its boxes centred, and what's either side of a box (black, or the score's band, which so goes
    # on to the wall and the edge as at the Game Boy) on out from it
    def place(a, b):  # where Game Boy columns a to b go, centred
        return LEFT + (400 - LEFT - 2*(b - a + 1))//2
    def column(sx, y):
        for (r0, r1), (a, b) in BOXES:
            if r0 <= y <= r1:
                d = sx - place(a, b)
                return a - 1 if d < 0 else b + 1 if d >= 2*(b - a + 1) else a + d//2
        return PANELX + 1  # a row the same all along
    LEFT = OFFSET + 176
    for y in range(144):
        for r in range(heights[y]):
            sy = rowstart[y] + r
            for sx in range(OFFSET + 174, 400):
                x = PANELX if sx < LEFT else column(sx, y)
                image.putpixel((sx, sy), dither(grid[y][x], sx, sy))

    def screenx(x, box):  # a Game Boy column in a box, on the screen
        (a, b) = box
        return place(a, b) + (x - a)*2
    def textrow(top):  # where text goes whose Game Boy glyphs (8 high) would start at row top
        return math.floor((rowstart[top] + rowstart[top + 8])/2 - (inktop + inkbottom + 1)/2 + 0.5)
    inktop, inkbottom = inkrows(font, "SCORELVINS0123456789")
    labelbox, nextbox = BOXES[0][1], BOXES[2][1]
    for label, top, bottom in LABELS:
        x = (screenx(111, labelbox) + screenx(153, labelbox))//2 - textwidth(font, label)//2
        y = (rowstart[top + 1] + rowstart[bottom]) // 2 - (inktop + inkbottom + 1)//2
        drawtext(image, font, label, x, y)

    # where platform.drawhud's things go, on the screen: each number centred across its place, in
    # a box below its label or along the score's band, at text's row; the next piece's middle; and
    # the score just added, rising (from and to text's rows) out of sight under the band
    def place_lua(name, left, right, top, bottom, text):
        return "\t%s = {left = %d, right = %d, top = %d, bottom = %d, text = %d},\n" % (name, left, right, top, bottom, text)
    hud = (place_lua("SCORE", LEFT, 400, rowstart[23], rowstart[33], textrow(24)) +
           place_lua("LEVEL", screenx(111, labelbox), screenx(153, labelbox), rowstart[56], rowstart[65], textrow(56)) +
           place_lua("LINES", screenx(111, labelbox), screenx(153, labelbox), rowstart[80], rowstart[89], textrow(80)) +
           "\tNEXT = {x = %g, y = %g},\n" % ((screenx(119, nextbox) + screenx(153, nextbox))/2, (rowstart[103] + rowstart[137])/2) +
           "\tADDED = {left = %d, right = 400, top = %d, bottom = %d, from = %d, to = %d},\n" % (LEFT, rowstart[35], rowstart[45], textrow(36), textrow(28)))

    os.makedirs(os.path.join(HERE, "art"), exist_ok=True)
    addglyphs()
    lettering = loadfont(os.path.basename(FONT), os.path.join(HERE, "art", "fonts"))
    maketitle(lettering)
    makemenu(lettering)
    makegameover(lettering, OFFSET)
    image.save(os.path.join(HERE, "art", "gamebackgroundgamea.png"))
    with open(os.path.join(HERE, "panel.lua"), "w") as out:
        out.write("--Made by makeart.py: where game A's panel's numbers, next piece and score just added go, on the\n"
                  "--screen (art/gamebackgroundgamea.png is all of it), and the font they're in.\n")
        out.write("panel = {\n")
        out.write("\tFONT = %r,\n" % ("fonts/" + os.path.basename(FONT)))
        out.write(hud)
        out.write("}\n")
    print("wrote art/: gamebackgroundgamea.png, gameovercutoff.png, title.png, gametype.png and fonts/; panel.lua and menuart.lua")


if __name__ == "__main__":
    main()
