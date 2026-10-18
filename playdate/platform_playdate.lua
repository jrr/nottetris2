--Everything the game needs from the engine, on Playdate: the same functions as platform_love.lua.
--A first version with placeholders: no sound yet, the system font for text, the LÖVE art turned
--1-bit by pdc, and pieces drawn as their polygons.
local gfx = playdate.graphics

platform = {}
platform.schedulephysics = true --simulate only part of the pile (scheduler.lua)
local REFRESHRATE = 50 --frames a second we aim for (the Playdate's default is 30, its most 50)
platform.maxstep = 1/30 --the longest step the game takes a frame: the game's 1/50 is slow motion below 50 fps
platform.physicsiterations = 5 --Chipmunk's solver passes a step: fewer than the game's 10, for speed
platform.stillpreview = true --the next piece doesn't spin: turning a bitmap each frame is slow here
platform.spreadclears = true --a line clear's cutting is done while the lines blink, not in one long frame

local SCALE = 240/144 --the Game Boy's 144 lines on the Playdate's 240
local OFFSETX = math.floor((400 - 160*SCALE)/2) --centered, for now

local background = gfx.kColorWhite
local font = gfx.font.new("/System/Fonts/Roobert-10-Bold")
local whitetext = false
local color, dither = gfx.kColorWhite, nil

--the game's loop: Playdate calls playdate.update once a frame
local playing = {gameA=true, gameB=true, failingA=true, failingB=true}
local dpad = {
	left = playdate.kButtonLeft,
	right = playdate.kButtonRight,
	up = playdate.kButtonUp,
	down = playdate.kButtonDown,
}

--The game's keys from the buttons. While a piece falls, A and B turn it (the game's x and z);
--elsewhere they're enter and escape.
local function buttonkey(button)
	if button == playdate.kButtonA then
		return playing[gamestate] and "x" or "return"
	elseif button == playdate.kButtonB then
		return playing[gamestate] and "z" or "escape"
	end
	for key, b in pairs(dpad) do
		if b == button then
			return key
		end
	end
end

local buttons = {playdate.kButtonLeft, playdate.kButtonRight, playdate.kButtonUp, playdate.kButtonDown, playdate.kButtonA, playdate.kButtonB}
local held = 0 --the buttons held down this frame, as bits: read once a frame, as each call into C costs

function playdate.update()
	local dt = playdate.getElapsedTime()
	playdate.resetElapsedTime()
	local pressed
	held, pressed = playdate.getButtonState()
	for _, button in ipairs(buttons) do
		if pressed & button ~= 0 then
			game_keypressed(buttonkey(button))
		end
	end
	game_update(dt)
	gfx.clear(background)
	game_draw()
end

function platform.setupscreen(vsync) --returns the scale to draw at
	gfx.setDrawOffset(OFFSETX, 0)
	playdate.display.setRefreshRate(REFRESHRATE)
	playdate.resetElapsedTime()
	return SCALE
end

function platform.randomseed()
	math.randomseed(playdate.getSecondsSinceEpoch())
end

function platform.gettime() --seconds, for timing animations
	return playdate.getCurrentTimeMilliseconds()/1000
end

--save files, by name, in the game's save directory
function platform.exists(name)
	return playdate.file.exists(name)
end

function platform.read(name) --the whole file, as a string
	local file = playdate.file.open(name)
	local s = file:read(playdate.file.getSize(name))
	file:close()
	return s
end

function platform.write(name, s)
	local file = playdate.file.open(name, playdate.file.kFileWrite)
	file:write(s)
	file:close()
end

--sounds: none yet
function platform.newmusic(path) return {} end
function platform.newsound(path) return {} end
function platform.play(sound) end
function platform.stop(sound) end
function platform.pause(sound) end
function platform.resume(sound) end
function platform.setvolume(sound, volume) end
function platform.setlooping(sound, looping) end

--keys, by LÖVE's names: the d-pad is the arrows, A and B as above
function platform.isdown(key) --held down this frame
	if dpad[key] then
		return held & dpad[key] ~= 0
	elseif key == "x" then
		return held & playdate.kButtonA ~= 0
	elseif key == "z" or key == "y" or key == "w" then
		return held & playdate.kButtonB ~= 0
	end
	return false
end

function platform.quit() --Playdate's own menu leaves games
end

--drawing. Images are scaled once when loaded; drawnscale is the scale the game draws them at,
--which then needs no more scaling.
function platform.draw(image, x, y, angle, sx, sy, originx, originy)
	if image.whole then --a drawing of the whole screen, with everything in place in it
		x, y = -OFFSETX, 0
	end
	sx = sx or 1
	local k = sx/image.drawnscale
	local width, height = image.image:getSize()
	originx, originy = (originx or 0)*sx, (originy or 0)*sx
	if (angle or 0) == 0 then
		if math.abs(k - 1) < 0.001 then
			image.image:draw(x - originx, y - originy)
		else
			image.image:drawScaled(x - originx, y - originy, k)
		end
	else
		local dx, dy = width*k/2 - originx, height*k/2 - originy
		local c, s = math.cos(angle), math.sin(angle)
		image.image:drawRotated(x + dx*c - dy*s, y + dx*s + dy*c, math.deg(angle), k)
	end
end

local function setcolor()
	gfx.setColor(color)
	if dither then
		gfx.setDitherPattern(dither, gfx.image.kDitherTypeBayer4x4)
	end
end

--Each kind of piece's fill: 8 rows of 8 pixels, # black and . white. Each block starts it at one of
--its corners (its shape's first point), so every block looks the same, and it moves with the piece
--(it doesn't turn with it); or with fixed, it's lined up with the screen instead.
local PATTERNS = {
	{ --1, I: very light, a sprinkle of dots
		"#...#...",
		"........",
		"..#...#.",
		"........",
		"#...#...",
		"........",
		"..#...#.",
		"........",
	},
	{ --2, J: dark, a fine white grid (the mirror L is light)
		"########",
		".#.#.#.#",
		"########",
		".#.#.#.#",
		"########",
		".#.#.#.#",
		"########",
		".#.#.#.#",
	},
	{ --3, L: light
		"#.#.#.#.",
		".#...#..",
		"#.#.#.#.",
		"...#...#",
		"#.#.#.#.",
		".#...#..",
		"#.#.#.#.",
		"...#...#",
	},
	{ --4, O: checks, fixed to the screen: a pixel's move would turn them over, so they'd shimmer
		fixed = true,
		"#.#.#.#.",
		".#.#.#.#",
		"#.#.#.#.",
		".#.#.#.#",
		"#.#.#.#.",
		".#.#.#.#",
		"#.#.#.#.",
		".#.#.#.#",
	},
	{ --5, S: light, with fine lines like / (the mirror Z is dark, with lines like \)
		"...#...#",
		"..#...#.",
		".#...#..",
		"#...#...",
		"...#...#",
		"..#...#.",
		".#...#..",
		"#...#...",
	},
	{ --6, T: mid-dark
		"###.###.",
		".#.#.#.#",
		"#.###.##",
		".#.#.#.#",
		"###.###.",
		".#.#.#.#",
		"#.###.##",
		".#.#.#.#",
	},
	{ --7, Z: dark, with fine white lines like \
		"#.###.##",
		"##.###.#",
		"###.###.",
		".###.###",
		"#.###.##",
		"##.###.#",
		"###.###.",
		".###.###",
	},
}
local patterns = {} --kind -> its 8 rows as numbers, for gfx.setPattern: bits set for white
for kind, rows in ipairs(PATTERNS) do
	patterns[kind] = {}
	for r, row in ipairs(rows) do
		local bits = 0
		for c = 1, 8 do
			bits = bits*2 + (row:sub(c, c) == "." and 1 or 0)
		end
		patterns[kind][r] = bits
	end
	patterns[kind].fixed = rows.fixed
	nt.setpattern(kind, rows.fixed == true, table.unpack(patterns[kind]))
end

--Polygons filled with a kind's pattern, each starting it at its first point (or lined up with the
--screen, if it's fixed), outlined in black. Patterns line up with the corner of what's drawn into:
--gridx, gridy is where that is on the screen, 0, 0 for the screen itself, and the points are drawn
--offsetx, offsety from it (by default OFFSETX, 0, as on the screen and in the pile's image).
local function drawpolygons(polygons, kind, gridx, gridy, offsetx, offsety)
	gridy, offsetx, offsety = gridy or 0, offsetx or OFFSETX, offsety or 0
	local pattern = patterns[kind]
	for _, points in ipairs(polygons) do
		if #points >= 6 then --a polygon: 3 points or more
			if pattern then
				local x, y = -gridx, -gridy --the screen's corner, in the grid
				if not pattern.fixed then
					x, y = points[1] + offsetx - gridx, points[2] + offsety - gridy
				end
				gfx.setPattern(pattern, (-x) % 8, (-y) % 8) --it turns left and up
			else
				gfx.setColor(gfx.kColorBlack)
			end
			gfx.fillPolygon(table.unpack(points))
			gfx.setColor(gfx.kColorBlack)
			gfx.drawPolygon(table.unpack(points))
		end
	end
	setcolor()
end

--The pieces, in C (pile_draw in nt_playdate.c), which keeps those that have stopped moving drawn
--in an image, the pile, rather than drawing each one every frame. Returns how many pieces joined the
--pile and how many left it.
function platform.drawpieces(world, falling, scale, newgame) --falling never joins the pile
	return nt.pile_draw(world.p, falling and falling.p, scale, OFFSETX, 0, math.ceil(160*SCALE), 240, newgame)
end

--The pieces as they are now, kept in an image (in C) to be drawn while a line clear blinks
function platform.snapshotpieces(world, scale)
	nt.pieces_snapshot(world.p, scale, OFFSETX, 0, math.ceil(160*SCALE), 240)
end

function platform.drawsnapshot()
	nt.pieces_drawsnapshot()
end

--Drawings kept in images: drawn again when their key changes, but no more than 10 times a second.
local caches = {}
local CACHEDELAY = 100 --ms

function platform.drawcached(name, width, height, key, draw)
	local c = caches[name]
	if not c then
		c = {image = gfx.image.new(math.ceil(width), math.ceil(height))}
		caches[name] = c
	end
	local now = playdate.getCurrentTimeMilliseconds()
	if c.key ~= key and (not c.time or now - c.time >= CACHEDELAY) then
		c.image:clear(gfx.kColorClear)
		gfx.pushContext(c.image)
		draw()
		gfx.popContext()
		setcolor()
		c.key, c.time = key, now
	end
	c.image:draw(0, 0)
end

function platform.drawpiece(image, polygons, x, y, angle, originx, originy, kind) --as its polygons
	drawpolygons(polygons, kind, 0)
end

--The next piece, in the box at the side: its blocks where graphics/pieces/<kind>.png has them, the
--image's top left at x, y: blocks of 8 (at scale), after a 1 pixel border, in columns and rows.
local PREVIEWBLOCKS = {
	{{0, 0}, {1, 0}, {2, 0}, {3, 0}}, --I
	{{0, 0}, {1, 0}, {2, 0}, {2, 1}}, --J
	{{0, 0}, {1, 0}, {2, 0}, {0, 1}}, --L
	{{0, 0}, {1, 0}, {0, 1}, {1, 1}}, --O
	{{1, 0}, {2, 0}, {0, 1}, {1, 1}}, --S
	{{0, 0}, {1, 0}, {2, 0}, {1, 1}}, --T
	{{0, 0}, {1, 0}, {1, 1}, {2, 1}}, --Z
}

--It's drawn into an image once for each kind, and the image drawn each frame: a call into C, not 16.
local previews = {} --kind -> {image, x, y, scale}

function platform.drawpreview(kind, x, y, scale)
	local ix, iy = math.floor(x), math.floor(y) --the image's top left, which the blocks' corners are from
	local p = previews[kind]
	if not (p and p[2] == ix and p[3] == iy and p[4] == scale) then
		local polygons = {}
		for _, b in ipairs(PREVIEWBLOCKS[kind] or {}) do
			local x1, y1 = math.floor(x + (1 + b[1]*8)*scale) - ix, math.floor(y + (1 + b[2]*8)*scale) - iy
			local x2, y2 = math.floor(x + (1 + (b[1] + 1)*8)*scale) - ix, math.floor(y + (1 + (b[2] + 1)*8)*scale) - iy
			polygons[#polygons+1] = {x1, y1, x2, y1, x2, y2, x1, y2}
		end
		p = {gfx.image.new(math.ceil((1 + 4*8)*scale) + 2, math.ceil((1 + 2*8)*scale) + 2, gfx.kColorClear), ix, iy, scale}
		gfx.pushContext(p[1])
		drawpolygons(polygons, kind, ix + OFFSETX, iy, ix + OFFSETX, iy)
		gfx.popContext()
		setcolor()
		previews[kind] = p
	end
	p[1]:draw(ix, iy)
end

function platform.print(text, x, y)
	if whitetext then
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	end
	font:drawText(tostring(text), x, y)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function platform.setfont(f)
	whitetext = f.white
end

--colors become black, white or a dither of black on white as light as the color
function platform.setcolor(r, g, b)
	local light = 0.299*r + 0.587*g + 0.114*b
	if light > 0.95 then
		color, dither = gfx.kColorWhite, nil
	elseif light < 0.05 then
		color, dither = gfx.kColorBlack, nil
	else
		color, dither = gfx.kColorBlack, light
	end
	setcolor()
end

function platform.setbackgroundcolor(r, g, b)
	background = (r + g + b)/3 < 0.5 and gfx.kColorBlack or gfx.kColorWhite
	gfx.setBackgroundColor(background)
end

function platform.rectangle(mode, x, y, width, height)
	if mode == "fill" then
		gfx.fillRect(x, y, width, height)
	else
		gfx.drawRect(x, y, width, height)
	end
end

function platform.setscissor(x, y, width, height)
	if x then
		gfx.setClipRect(x, y, width, height)
	else
		gfx.clearClipRect()
	end
end

function platform.drawnow(draw) --show a frame from the middle of an update
	gfx.clear(background)
	draw()
	playdate.display.flush()
end

--images: the LÖVE art, which pdc makes 1-bit, scaled; or the Playdate's own drawing of it, where
--there is one (graphics/playdate/, from makeart.py), already the size it's drawn at. One 400 wide is
--of the whole screen, with what's in it where it goes: it's drawn from the screen's corner, wherever
--the game draws it (game A's background, and its game over, over the field)
local function load(path, scale)
	local image = gfx.image.new(path)
	assert(image, "no image " .. path)
	return image:scaledImage(scale)
end

local own = {} --path -> the Playdate's own drawing of it

function platform.newimage(path) --path without extension
	local ownpath = path:gsub("^graphics/", "graphics/playdate/")
	if playdate.file.exists(ownpath .. ".pdi") then
		own[path] = gfx.image.new(ownpath)
		return {image=own[path], drawnscale=SCALE, whole=own[path]:getSize() == 400}
	end
	return {image=load(path, SCALE), drawnscale=SCALE}
end

--The title, with its menu and cursor lettered (makeart.py)
function platform.drawtitle()
	own["graphics/title"]:draw(0, 0)
end

--Game A's panel, beside the field, in the Playdate's own drawing of it, which is the whole screen
--(panel.lua says where things go, on the screen): its numbers, in Nontendo Bold like its labels,
--each centred across its place, drawn into the background when they change, so that a frame draws
--them with it; the next piece, centred in its box; and the score just added, rising out of sight
--under the score's band.
local hudfont = gfx.font.new(panel.FONT)
local hudshown = {}

local function centred(text, place, y) --across a place on the screen, from the left x is (screen or game)
	hudfont:drawText(text, math.floor((place.left + place.right - hudfont:getTextWidth(text))/2) - (place.offset or 0), y)
end

function platform.drawhud(next, score, level, lines, added, rising) --rising: 0-1, how far added has gone
	local background = own["graphics/gamebackgroundgamea"]
	if not background then
		return
	end
	if hudshown.score ~= score or hudshown.level ~= level or hudshown.lines ~= lines then
		hudshown = {score=score, level=level, lines=lines}
		gfx.pushContext(background) --which is the screen: no offset
		for _, number in ipairs({{panel.SCORE, score}, {panel.LEVEL, level}, {panel.LINES, lines}}) do
			local place = number[1]
			gfx.setColor(gfx.kColorWhite)
			gfx.fillRect(place.left, place.top, place.right - place.left, place.bottom - place.top)
			centred(tostring(number[2]), place, place.text)
		end
		gfx.popContext()
		setcolor()
	end
	if next and PREVIEWBLOCKS[next] then
		local columns, rows = 0, 0
		for _, b in ipairs(PREVIEWBLOCKS[next]) do
			columns, rows = math.max(columns, b[1] + 1), math.max(rows, b[2] + 1)
		end
		local cx, cy = panel.NEXT.x - OFFSETX, panel.NEXT.y
		platform.drawpreview(next, cx - (columns*8/2 + 1)*SCALE, cy - (rows*8/2 + 1)*SCALE, SCALE)
	end
	if added then
		local place = panel.ADDED
		gfx.setClipRect(place.left - OFFSETX, place.top, place.right - place.left, place.bottom - place.top)
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		centred("+" .. added, {left=place.left, right=place.right, offset=OFFSETX},
			math.floor(place.from + (place.to - place.from)*rising + 0.5))
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		gfx.clearClipRect()
	end
end

--The credits, lettered in Nontendo Bold rather than the Game Boy's font, each line centred (they're
--centred in that font with spaces), with its characters that aren't what they look: ' an opening
--quote, T in TM, C a (c), # a full stop and closing quote. And the logo below the ninth line, "(c)2010
--Maurice", lettered too. Drawn once, into an image.
local credits

function platform.drawcredits(lines)
	if not credits then
		local width = math.ceil(160*SCALE)
		credits = gfx.image.new(width, 240) --clear, on the screen's background
		gfx.pushContext(credits)
		local function centred(text, row) --on the Game Boy's row of 8
			hudfont:drawText(text, math.floor((width - hudfont:getTextWidth(text))/2), math.floor(row*8*SCALE + 0.5))
		end
		for i, line in ipairs(lines) do
			line = line:gsub("'", '"'):gsub("C", "\u{a9}"):gsub("#", '."'):upper()
			centred(line:match("^%s*(.-)%s*$"), i)
		end
		centred("\u{a9}2010 Maurice", 10)
		gfx.popContext()
	end
	credits:draw(0, 0)
end

--The menu, in the Playdate's own drawing of it, every choice grey (menuart.lua): the chosen ones
--lettered black over theirs, and the top scores over their dotted lines
function platform.drawmenu(shown, names, scores, entering, cursor)
	own["graphics/gametype"]:draw(0, 0)
	for i, choice in ipairs(menuart.CHOICES) do
		if shown[i] then
			hudfont:drawText(choice[1], choice[2], choice[3])
		end
	end
	for i = 1, 3 do
		local y = menuart.ROWS[i]
		if tonumber(scores[i]) > 0 then
			local name = string.upper(string.sub(names[i], 1, 6))
			local score = string.sub(tostring(scores[i]), 1, 6)
			local namewidth, scorewidth = hudfont:getTextWidth(name), hudfont:getTextWidth(score)
			gfx.setColor(gfx.kColorWhite) --off the dotted line
			gfx.fillRect(menuart.NAMEX - 1, y - 1, namewidth + 2, 12)
			gfx.fillRect(menuart.SCORERIGHT - scorewidth - 1, y - 1, scorewidth + 2, 12)
			hudfont:drawText(name, menuart.NAMEX, y)
			hudfont:drawText(score, menuart.SCORERIGHT - scorewidth, y)
			if entering == i and cursor then --under where the next letter goes, or the last
				local x = menuart.NAMEX + (name:len() < 6 and namewidth + 1 or hudfont:getTextWidth(name:sub(1, 5)) + 1)
				gfx.setColor(gfx.kColorBlack)
				gfx.fillRect(x, y + 11, 6, 2)
			end
			setcolor()
		end
	end
end

function platform.newfont(path, glyphs) --the system font for now: just whether it's white
	return {white=path:find("white") ~= nil}
end

--pieces are drawn as polygons, so they have no pixels to cut
function platform.newpieceimage(path, scale)
	return {image=load(path, scale), drawnscale=1}
end

function platform.newpiecepixels(path, scale) return {} end
function platform.copypixels(pixels) return {} end
function platform.getpixelsize(pixels) return 0, 0 end
function platform.erasepixel(pixels, x, y) end
function platform.imagefrompixels(pixels) return {} end
