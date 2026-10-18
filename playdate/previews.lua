--Pictures of the pieces as the game draws them, for judging their patterns: build.sh --previews
--builds the game with this imported last, in place of the game itself. The first screen has each
--kind at rest; then a screen for each kind, turned 0 to 86.25 degrees in 24 steps (a turn of 90
--more steps its edges the same ways). Left and right go through them; up and down switch between
--the pieces as the game draws them and a trial of the Game Boy's designs (DESIGNS). Each screen is
--written to PREVIEWSOUT (previewsout.lua, from build.sh) as a PNG, both ways.
local gfx = playdate.graphics

local NAMES = {"I", "J", "L", "O", "S", "T", "Z"}
local COLUMNS, ROWS, CELLW, CELLH = 6, 4, 66, 60
local STEP = 90/(COLUMNS*ROWS)
local OFFSETX = math.floor((400 - 160*240/144)/2) --where the game's field is (platform_playdate.lua)

world = physics.newworld(0, 0)
tetribodies, tetrishapes, tetrikind = {}, {}, {}

--A piece of a kind, turned angle degrees and centred on cx, cy on the screen: its polygons there,
--as the game finds them (piecepolygons), which drawpiece draws
local function polygonsat(kind, angle, x, y)
	createtetriA(kind, 1, x, y)
	tetribodies[1]:setAngle(math.rad(angle))
	local polygons = piecepolygons(tetrishapes[1])
	tetribodies[1]:destroy()
	return polygons
end

local function placed(kind, angle, cx, cy)
	local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
	for _, points in ipairs(polygonsat(kind, angle, 0, 0)) do
		for i = 1, #points, 2 do
			x1, x2 = math.min(x1, points[i]), math.max(x2, points[i])
			y1, y2 = math.min(y1, points[i+1]), math.max(y2, points[i+1])
		end
	end
	return polygonsat(kind, angle, (cx - OFFSETX - (x1 + x2)/2)/physicsscale, (cy - (y1 + y2)/2)/physicsscale)
end

--Each screen: a list of {kind, polygons, angle}
local screens = {}
local rest = {}
for kind = 1, 7 do
	local row = kind <= 4 and 0 or 1
	local column = kind <= 4 and kind - 1 or kind - 5
	local count = row == 0 and 4 or 3
	rest[#rest+1] = {kind, placed(kind, 0, 200 + (column - (count - 1)/2)*90, 75 + row*90), 0}
end
screens[1] = rest
for kind = 1, 7 do
	local screen = {}
	for i = 0, COLUMNS*ROWS - 1 do
		local column, row = i % COLUMNS, i // COLUMNS
		screen[#screen+1] = {kind, placed(kind, i*STEP, 2 + (column + 0.5)*CELLW, (row + 0.5)*CELLH), i*STEP}
	end
	screens[#screens+1] = screen
end

--The Game Boy's pieces (graphics/pieces): each block an 8 pixel square, outlined, with a design in
--it. Here each is a list of squares inside the block, drawn in turn: how far in (Playdate pixels:
--a block is 13 or 14) and what fill. On I, the speckle reaches across to the next block, so it's
--one bar; on T, a bevel: the white square's bottom and right sides are one in further, leaving a
--line of black there, which turns with the piece.
local DESIGNS = {
	{{0, "black"}, {2, "speckle", seamless = true}}, --I
	{{0, "black"}, {2, "light"}, {4, "black"}, {5, "white"}}, --J
	{{0, "black"}, {2, "dark"}}, --L
	{{0, "black"}, {2, "white"}, {4, "black"}}, --O
	{{0, "black"}, {2, "white"}, {4, "black"}, {5, "dark"}}, --S
	{{0, "black"}, {2, "white"}, {4, "black"}, {4, "white", bevel = true}}, --T
	{{0, "black"}, {2, "light"}, {5, "black"}}, --Z
}

local function pattern(rows) --8 rows of # and ., as gfx.setPattern takes them: bits set for white
	local out = {}
	for r, row in ipairs(rows) do
		local bits = 0
		for c = 1, 8 do
			bits = bits*2 + (row:sub(c, c) == "." and 1 or 0)
		end
		out[r] = bits
	end
	return out
end

--the browns as makeart.py dithers them: light a dot in every 2 by 2, dark a checkerboard
local FILLS = {
	light = pattern({"#.#.#.#.", "........", "#.#.#.#.", "........", "#.#.#.#.", "........", "#.#.#.#.", "........"}),
	dark = pattern({"#.#.#.#.", ".#.#.#.#", "#.#.#.#.", ".#.#.#.#", "#.#.#.#.", ".#.#.#.#", "#.#.#.#.", ".#.#.#.#"}),
	speckle = pattern({"#...#...", "..#...#.", "#...#...", "..#...#.", "#...#...", "..#...#.", "#...#...", "..#...#."}),
}

--A convex polygon {x1, y1, ...} moved in by insets[i] across each side i (from point i to i+1)
local function inset(points, insets)
	local n = #points//2
	local cx, cy = 0, 0
	for i = 1, n do
		cx, cy = cx + points[2*i-1]/n, cy + points[2*i]/n
	end
	local lines = {} --each side moved in: a point on it and its direction
	for i = 1, n do
		local x1, y1 = points[2*i-1], points[2*i]
		local j = i % n + 1
		local dx, dy = points[2*j-1] - x1, points[2*j] - y1
		local length = math.sqrt(dx*dx + dy*dy)
		local nx, ny = -dy/length, dx/length
		if (cx - x1)*nx + (cy - y1)*ny < 0 then
			nx, ny = -nx, -ny
		end
		lines[i] = {x1 + nx*insets[i], y1 + ny*insets[i], dx, dy}
	end
	local out = {}
	for i = 1, n do --point i: where side i-1 meets side i
		local a, b = lines[(i - 2) % n + 1], lines[i]
		local t = ((b[1] - a[1])*b[4] - (b[2] - a[2])*b[3])/(a[3]*b[4] - a[4]*b[3])
		out[#out+1] = math.floor(a[1] + t*a[3] + 0.5)
		out[#out+1] = math.floor(a[2] + t*a[4] + 0.5)
	end
	return out
end

local function shared(polygons, points, i) --whether side i of a block is another block's side too
	local n = #points//2
	local j = i % n + 1
	local x1, y1, x2, y2 = points[2*i-1], points[2*i], points[2*j-1], points[2*j]
	for _, other in ipairs(polygons) do
		if other ~= points then
			local has1, has2 = false, false
			for k = 1, #other, 2 do
				has1 = has1 or (other[k] == x1 and other[k+1] == y1)
				has2 = has2 or (other[k] == x2 and other[k+1] == y2)
			end
			if has1 and has2 then
				return true
			end
		end
	end
	return false
end

local function drawdesign(kind, polygons, angle)
	local c, s = math.cos(math.rad(angle)), math.sin(math.rad(angle))
	for _, layer in ipairs(DESIGNS[kind]) do
		for _, points in ipairs(polygons) do
			local n = #points//2
			local insets = {}
			for i = 1, n do
				insets[i] = layer[1]
				local j = i % n + 1
				if layer.seamless and shared(polygons, points, i) then
					insets[i] = 0
				end
				if layer.bevel then --its bottom and right sides, as the piece is drawn unturned, in one more
					local dx, dy = points[2*j-1] - points[2*i-1], points[2*j] - points[2*i]
					local ux, uy = c*dx + s*dy, -s*dx + c*dy --the side, unturned
					if (uy > 0 and math.abs(uy) > math.abs(ux)) or (ux < 0 and math.abs(ux) > math.abs(uy)) then
						insets[i] = insets[i] + 1 --going down: the right side; going left: the bottom
					end
				end
			end
			local fill = layer[2]
			if fill == "black" then
				gfx.setColor(gfx.kColorBlack)
			elseif fill == "white" then
				gfx.setColor(gfx.kColorWhite)
			else
				gfx.setPattern(FILLS[fill], (-(points[1] + OFFSETX)) % 8, (-points[2]) % 8)
			end
			gfx.fillPolygon(table.unpack(layer[1] == 0 and points or inset(points, insets)))
		end
	end
	gfx.setColor(gfx.kColorBlack)
end

local style = 1 --1 as the game draws them, 2 the Game Boy's designs
local function draw(screen)
	gfx.clear(gfx.kColorWhite)
	for _, piece in ipairs(screen) do
		if style == 1 then
			platform.drawpiece(nil, piece[2], 0, 0, 0, 0, 0, piece[1])
		else
			drawdesign(piece[1], piece[2], piece[3])
		end
	end
end

local shown, frame = 1, 0
function playdate.update()
	frame = frame + 1
	--the screens written one a frame, the game's way then the Game Boy's: the display image is the
	--one drawn the frame before
	local count = #screens*2
	if frame <= count + 1 then
		if frame > 1 then
			local k = (frame - 2) % #screens + 1
			local name = (k == 1 and "rest" or NAMES[k - 1]) .. (frame - 1 > #screens and "-gameboy" or "")
			local path = PREVIEWSOUT .. "/" .. k .. "-" .. name .. ".png"
			playdate.simulator.writeToFile(gfx.getDisplayImage(), path)
			print("wrote " .. path)
		end
		local k = math.min(frame, count)
		shown, style = (k - 1) % #screens + 1, k > #screens and 2 or 1
	elseif playdate.buttonJustPressed(playdate.kButtonRight) then
		shown = shown % #screens + 1
	elseif playdate.buttonJustPressed(playdate.kButtonLeft) then
		shown = (shown - 2) % #screens + 1
	elseif playdate.buttonJustPressed(playdate.kButtonUp) or playdate.buttonJustPressed(playdate.kButtonDown) then
		style = 3 - style
	end
	draw(screens[shown])
end
