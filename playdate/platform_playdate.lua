--Everything the game needs from the engine, on Playdate: the same functions as platform_love.lua.
--A first version with placeholders: no sound yet, the system font for text, the LÖVE art turned
--1-bit by pdc, and pieces drawn as their polygons.
local gfx = playdate.graphics

platform = {}
platform.schedulephysics = true --simulate only part of the pile (scheduler.lua)
platform.maxstep = 1/30 --the longest step the game takes a frame: the game's 1/50 is slow motion at 30 fps
platform.physicsiterations = 5 --Chipmunk's solver passes a step: fewer than the game's 10, for speed
platform.stillpreview = true --the next piece doesn't spin: turning a bitmap each frame is slow here

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

function playdate.update()
	local dt = playdate.getElapsedTime()
	playdate.resetElapsedTime()
	for _, button in ipairs(buttons) do
		if playdate.buttonJustPressed(button) then
			game_keypressed(buttonkey(button))
		end
	end
	game_update(dt)
	gfx.clear(background)
	game_draw()
end

function platform.setupscreen(vsync) --returns the scale to draw at
	gfx.setDrawOffset(OFFSETX, 0)
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
function platform.isdown(key) --held down right now
	if dpad[key] then
		return playdate.buttonIsPressed(dpad[key])
	elseif key == "x" then
		return playdate.buttonIsPressed(playdate.kButtonA)
	elseif key == "z" or key == "y" or key == "w" then
		return playdate.buttonIsPressed(playdate.kButtonB)
	end
	return false
end

function platform.quit() --Playdate's own menu leaves games
end

--drawing. Images are scaled once when loaded; drawnscale is the scale the game draws them at,
--which then needs no more scaling.
function platform.draw(image, x, y, angle, sx, sy, originx, originy)
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

local function drawpolygons(polygons)
	for _, points in ipairs(polygons) do
		gfx.setColor(gfx.kColorBlack)
		gfx.fillPolygon(table.unpack(points))
		gfx.setColor(gfx.kColorWhite)
		gfx.drawPolygon(table.unpack(points))
	end
	setcolor()
end

--The pile: pieces that have stopped moving, kept drawn in an image the size of the game's screen.
--The game says when a piece joins it (drawn into the image) or leaves it (its area of the image
--redrawn from the pieces still there).
platform.keepspile = true
local pileimage = gfx.image.new(math.ceil(160*SCALE), 240)
local pile = {} --key -> {polygons, x1, y1, x2, y2}

function platform.clearpile()
	pile = {}
	pileimage:clear(gfx.kColorClear)
end

function platform.pilepiece(key, polygons) --into the pile, and onto the screen this frame
	local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
	for _, points in ipairs(polygons) do
		for i = 1, #points, 2 do
			x1, x2 = math.min(x1, points[i]), math.max(x2, points[i])
			y1, y2 = math.min(y1, points[i+1]), math.max(y2, points[i+1])
		end
	end
	pile[key] = {polygons, math.floor(x1) - 1, math.floor(y1) - 1, math.ceil(x2) + 1, math.ceil(y2) + 1}
	gfx.pushContext(pileimage)
	drawpolygons(polygons)
	gfx.popContext()
	drawpolygons(polygons)
end

function platform.unpile(key) --out of the pile: redraw the area it covered
	local p = pile[key]
	if not p then
		return
	end
	pile[key] = nil
	local x1, y1, x2, y2 = p[2], p[3], p[4], p[5]
	gfx.pushContext(pileimage)
	gfx.setClipRect(x1, y1, x2 - x1, y2 - y1)
	gfx.setColor(gfx.kColorClear)
	gfx.fillRect(x1, y1, x2 - x1, y2 - y1)
	for _, q in pairs(pile) do
		if q[2] < x2 and q[4] > x1 and q[3] < y2 and q[5] > y1 then
			drawpolygons(q[1])
		end
	end
	gfx.clearClipRect()
	gfx.popContext()
end

function platform.drawpile()
	pileimage:draw(0, 0)
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

function platform.drawpiece(image, polygons, x, y, angle, originx, originy) --as its polygons
	drawpolygons(polygons)
end

function platform.drawbody(body, scale) --a piece by its body's shapes, in C: no tables of points to make
	nt.body_draw(body.p, scale)
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

--images: the LÖVE art, which pdc makes 1-bit, scaled
local function load(path, scale)
	local image = gfx.image.new(path)
	assert(image, "no image " .. path)
	return image:scaledImage(scale)
end

function platform.newimage(path) --path without extension
	return {image=load(path, SCALE), drawnscale=SCALE}
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
