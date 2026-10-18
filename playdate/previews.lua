--Pictures of the pieces as the game draws them, for judging their patterns: build.sh --previews
--builds the game with this imported last, in place of the game itself. The first screen has each
--kind at rest; then a screen for each kind, turned 0 to 86.25 degrees in 24 steps (a turn of 90
--more steps its edges the same ways). Left and right go through them. Each screen is written to
--PREVIEWSOUT (previewsout.lua, from build.sh) as a PNG.
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

--Each screen: a list of {kind, polygons}
local screens = {}
local rest = {}
for kind = 1, 7 do
	local row = kind <= 4 and 0 or 1
	local column = kind <= 4 and kind - 1 or kind - 5
	local count = row == 0 and 4 or 3
	rest[#rest+1] = {kind, placed(kind, 0, 200 + (column - (count - 1)/2)*90, 75 + row*90)}
end
screens[1] = rest
for kind = 1, 7 do
	local screen = {}
	for i = 0, COLUMNS*ROWS - 1 do
		local column, row = i % COLUMNS, i // COLUMNS
		screen[#screen+1] = {kind, placed(kind, i*STEP, 2 + (column + 0.5)*CELLW, (row + 0.5)*CELLH)}
	end
	screens[#screens+1] = screen
end

local function draw(screen)
	gfx.clear(gfx.kColorWhite)
	for _, piece in ipairs(screen) do
		platform.drawpiece(nil, piece[2], 0, 0, 0, 0, 0, piece[1])
	end
end

local shown, frame = 1, 0
function playdate.update()
	frame = frame + 1
	--the screens written one a frame: the display image is the one drawn the frame before
	local writing = frame <= #screens + 1
	if writing then
		if frame > 1 then
			local name = frame == 2 and "rest" or NAMES[frame - 2]
			local path = PREVIEWSOUT .. "/" .. (frame - 1) .. "-" .. name .. ".png"
			playdate.simulator.writeToFile(gfx.getDisplayImage(), path)
			print("wrote " .. path)
		end
		shown = math.min(frame, #screens)
	elseif playdate.buttonJustPressed(playdate.kButtonRight) then
		shown = shown % #screens + 1
	elseif playdate.buttonJustPressed(playdate.kButtonLeft) then
		shown = (shown - 2) % #screens + 1
	end
	draw(screens[shown])
end
