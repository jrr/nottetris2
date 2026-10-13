table.unpack = table.unpack or unpack --Lua 5.2 moved unpack into table; LÖVE's LuaJIT only has the global
require "platform_love"
require "nt_physics_love" --Chipmunk; physics_love.lua is the same physics on Box2D
require "physics_chipmunk"

function game_load()
	--requires--
	require "gameB"
	require "gameA"
	require "menu"
	require "failed"
	require "rocket"
	require "scheduler"
	
	scheduler.enabled = platform.schedulephysics == true --simulate only part of the pile (scheduler.lua)
	
	vsync = true
	hue = 0.08 --the color the art is tinted
	
	scale = platform.setupscreen(vsync) --how many pixels to draw for each of the Game Boy's
	
	physicsscale = scale/4
	
	--pieces--
	tetriimages = {}
	tetriimagedata = {}
	
	--SOUND--
	music = {}
	
	music[1] = platform.newmusic( "sounds/themeA" )
	platform.setvolume( music[1], 0.6 )
	platform.setlooping( music[1], true )
	
	music[2] = platform.newmusic( "sounds/themeB" )
	platform.setvolume( music[2], 0.6 )
	platform.setlooping( music[2], true )
	
	music[3] = platform.newmusic( "sounds/themeC" )
	platform.setvolume( music[3], 0.6 )
	platform.setlooping( music[3], true )
	
	musictitle = platform.newmusic( "sounds/titlemusic" )
	platform.setvolume( musictitle, 0.6 )
	platform.setlooping( musictitle, true )
	
	musichighscore = platform.newmusic( "sounds/highscoremusic" )
	platform.setvolume( musichighscore, 0.6 )
	platform.setlooping( musichighscore, true )
	
	musicrocket4 = platform.newmusic( "sounds/rocket4" )
	platform.setvolume( musicrocket4, 0.6 )
	platform.setlooping( musicrocket4, false )
	
	musicrocket1to3 = platform.newmusic( "sounds/rocket1to3" )
	platform.setvolume( musicrocket1to3, 0.6 )
	platform.setlooping( musicrocket1to3, false )
	
	highscoreintro = platform.newmusic( "sounds/highscoreintro" )
	platform.setvolume( highscoreintro, 0.6 )
	platform.setlooping( highscoreintro, false )
	
	boot = platform.newsound( "sounds/boot" )
	blockfall = platform.newsound( "sounds/blockfall" )
	blockturn = platform.newsound( "sounds/turn" )
	blockmove = platform.newsound( "sounds/move" )
	lineclear = platform.newsound( "sounds/lineclear" )
	fourlineclear = platform.newsound( "sounds/4lineclear" )
	gameover1 = platform.newsound( "sounds/gameover1" )
	gameover2 = platform.newsound( "sounds/gameover2" )
	pausesound = platform.newsound( "sounds/pause" )
	highscorebeep = platform.newsound( "sounds/highscorebeep" )
	newlevel = platform.newsound( "sounds/newlevel" )
	platform.setvolume( newlevel, 0.6 )
	
	--Whitelist for highscorenames--
	whitelist = {}
	for i = 48, 57 do -- 0 - 9
		whitelist[i] = true
	end
	for i = 65, 90 do -- A - Z
		whitelist[i] = true
	end
	for i = 97, 122 do --a - z
		whitelist[i] = true
	end
	whitelist[32] = true -- space
	whitelist[44] = true -- ,
	whitelist[45] = true -- -
	whitelist[46] = true -- .
	whitelist[95] = true -- _
	
	-----------------------------
	
	platform.randomseed()
	math.random();math.random();math.random() --discarding some as they seem to tend to unrandomness.
	
	platform.setbackgroundcolor( 1, 1, 1 )

	skipupdate = true
	soundenabled = true
	startdelay = 1
	logoduration = 1.5
	logodelay = 1
	creditsdelay = 2
	selectblinkrate = 0.29
	cursorblinkrate = 0.14
	selectblink = true
	cursorblink = true
	musicno = 1 --
	gameno = 1 --
	selection = 1 --
	colorizeduration = 3 --seconds
	lineclearduration = 1.2 --seconds
	lineclearblinks = 7 --i
	linecleartreshold = 8.1 --in blocks
	densityupdateinterval = 1/30 --in seconds
	nextpiecerotspeed = platform.stillpreview and 0 or 1 --rad per seconnd
	minfps = 1/50 --dt doesn't go higher than this
	scoreaddtime = 0.5
	startdelaytime = 0
	
	blockstartY = -64 --where new blocks are created
	losingY = 0 --lose if block 1 collides above this line
	blockmass = 5 --probably obsolete because body:setMassFromShapes()
	blockrot = 10
	blockrestitution = 0.1
	minmass = 1
	
	piececenter = {}
	piececenter[1] = {17, 5}
	piececenter[2] = {13, 9}
	piececenter[3] = {13, 9}
	piececenter[4] = { 9, 9}
	piececenter[5] = {13, 9}
	piececenter[6] = {13, 9}
	piececenter[7] = {13, 9}
	
	piececenterpreview = {}
	piececenterpreview[1] = {17, 5}
	piececenterpreview[2] = {15, 7}
	piececenterpreview[3] = {11, 7}
	piececenterpreview[4] = { 9, 9}
	piececenterpreview[5] = {13, 9}
	piececenterpreview[6] = {13, 7}
	piececenterpreview[7] = {13, 9}
	
	loadhighscores()

	loadimages()
	
	--all done!
	if startdelay == 0 then
		menu_load()
	end
end

function start()
	menu_load()
end

function loadimages()
	--IMAGES--
	--menu--
	stabyourselflogo = platform.newimage("graphics/stabyourselflogo")
	logo = platform.newimage("graphics/logo")
	title = platform.newimage("graphics/title")
	gametype = platform.newimage("graphics/gametype")
	--game--
	gamebackground = platform.newimage("graphics/gamebackground")
	gamebackgroundcutoff = platform.newimage("graphics/gamebackgroundgamea")
	gameover = platform.newimage("graphics/gameover")
	gameovercutoff = platform.newimage("graphics/gameovercutoff")
	pausegraphic = platform.newimage("graphics/pause")
	pausegraphiccutoff = platform.newimage("graphics/pausecutoff")
	
	--rockets--
	rocket1 = platform.newimage("graphics/rocket1")
	rocket2 = platform.newimage("graphics/rocket2")
	rocket3 = platform.newimage("graphics/rocket3")
	spaceshuttle = platform.newimage("graphics/spaceshuttle")
	
	rocketbackground = platform.newimage("graphics/rocketbackground")
	bigrocketbackground = platform.newimage("graphics/bigrocketbackground")
	bigrockettakeoffbackground = platform.newimage("graphics/bigrockettakeoffbackground")
	
	
	smoke1left = platform.newimage("graphics/smoke1left")
	smoke1right = platform.newimage("graphics/smoke1right")
	smoke2left = platform.newimage("graphics/smoke2left")
	smoke2right = platform.newimage("graphics/smoke2right")
	
	fire1 = platform.newimage("graphics/fire1")
	fire2 = platform.newimage("graphics/fire2")
	firebig1 = platform.newimage("graphics/firebig1")
	firebig2 = platform.newimage("graphics/firebig2")
	
	congratsline = platform.newimage("graphics/congratsline")
	
	--nextpiece
	nextpieceimg = {}
	for i = 1, 7 do
		nextpieceimg[i] = platform.newpieceimage( "graphics/pieces/"..i, scale )
	end
	
	--font--
	tetrisfont = platform.newfont("graphics/font", "0123456789abcdefghijklmnopqrstTuvwxyz.,'C-#_>:<! ")
	whitefont = platform.newfont("graphics/fontwhite", "0123456789abcdefghijklmnopqrstTuvwxyz.,'C-#_>:<!+ ")
	platform.setfont(tetrisfont)
end

function game_update(dt)
	if gamestate == nil then
		startdelaytime = startdelaytime + dt
		if startdelaytime >= startdelay then
			start()
		end
	end

	if skipupdate then
		skipupdate = false
		return
	end
	
	if cuttingtimer ~= 0 then
		dt = math.min(dt, minfps)
	end
	
	if gamestate == "logo" or gamestate == "credits" or gamestate == "title" or gamestate == "menu" or gamestate == "highscoreentry" then
		menu_update(dt)
	elseif gamestate == "gameA" or gamestate == "failingA" then
		if pause == false then
			gameA_update(dt)
		end
	elseif gamestate == "gameB" or gamestate == "failingB" then
		if pause == false then
			gameB_update(dt)
		end
	elseif gamestate == "rocket1" or gamestate == "rocket2" or gamestate == "rocket3" or gamestate == "rocket4" then
		rocket_update()
	end
end

function game_draw()
	if gamestate == "logo" or gamestate == "credits" or gamestate == "title" or gamestate == "menu" or gamestate == "highscoreentry" then
		menu_draw()
	elseif gamestate == "gameA" or gamestate == "failingA" then
		gameA_draw()
	elseif gamestate == "gameB" or gamestate == "failingB" then
		gameB_draw()
	elseif gamestate == "failed" then
		failed_draw()
	elseif gamestate == "rocket1" or gamestate == "rocket2" or gamestate == "rocket3" or gamestate == "rocket4" then
		rocket_draw()
	end
end

function loadhighscores()
	if gameno == 1 then
		fileloc = "highscoresA.txt"
	else
		fileloc = "highscoresB.txt"
	end
	
	if platform.exists( fileloc ) then
		
		highdata = platform.read( fileloc )
		highdata = highdata:split(";")
		highscore = {}
		highscorename = {}
		for i = 1, 3 do
			highscore[i] = tonumber(highdata[i*2])
			highscorename[i] = string.lower(highdata[i*2-1])
		end
	else
		highscore = {}
		highscorename = {}
		highscore[1] = 0
		highscorename[1] = ""
		highscore[2] = 0
		highscorename[2] = ""
		highscore[3] = 0
		highscorename[3] = ""
		savehighscores()
	end
end

function newhighscores()
	highscore = {}
	highscorename = {}
	highscore[1] = 0
	highscorename[1] = ""
	highscore[2] = 0
	highscorename[2] = ""
	highscore[3] = 0
	highscorename[3] = ""
	savehighscores()
end

function savehighscores()
	if gameno == 1 then
		fileloc = "highscoresA.txt"
	else
		fileloc = "highscoresB.txt"
	end
	
	highdata = ""
	for i = 1, 3 do
		highdata = highdata..highscorename[i]..";"..highscore[i]..";"
	end
	platform.write( fileloc, highdata.."\n" )
end

function string:split(delimiter)
	local result = {}
	local from  = 1
	local delim_from, delim_to = string.find( self, delimiter, from  )
	while delim_from do
		table.insert( result, string.sub( self, from , delim_from-1 ) )
		from  = delim_to + 1
		delim_from, delim_to = string.find( self, delimiter, from  )
	end
	table.insert( result, string.sub( self, from  ) )
	return result
end

function pythagoras(a, b)
	c = math.sqrt(a^2 + b^2)
	if a < 0 or b < 0 then
		c = -c
	end
	return c
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function table2string(mytable)
	output = {}
	for i, v in pairs (mytable) do
		output[i] = mytable[i]
	end
	return output
end

--LÖVE 0.7 made polygons from the convex hull of the points it was given, dropping
--collinear and inward points; 0.8 uses the points as they are. This is 0.7's Graham
--scan, so cut pieces get the same shapes. Takes and returns {x1,y1,x2,y2,...}.
function convexhull(coords)
	if #coords <= 6 then
		return coords
	end
	local points = {}
	for i = 1, #coords, 2 do
		table.insert(points, {coords[i], coords[i+1]})
	end
	local anchor = 1
	for i = 2, #points do
		if points[i][2] < points[anchor][2] or (points[i][2] == points[anchor][2] and points[i][1] < points[anchor][1]) then
			anchor = i
		end
	end
	local a = table.remove(points, anchor)
	local function cross(o, p, q)
		return (p[1]-o[1])*(q[2]-o[2]) - (q[1]-o[1])*(p[2]-o[2])
	end
	table.sort(points, function(p, q)
		local c = cross(a, p, q)
		if math.abs(c) > 1e-12 then
			return c > 0
		end
		return (p[1]-a[1])^2 + (p[2]-a[2])^2 < (q[1]-a[1])^2 + (q[2]-a[2])^2
	end)
	local hull = {a, points[1]}
	for i = 2, #points do
		while #hull > 1 and cross(hull[#hull-1], hull[#hull], points[i]) <= 1e-12 do
			table.remove(hull)
		end
		table.insert(hull, points[i])
	end
	local result = {}
	for i, p in ipairs(hull) do
		result[i*2-1], result[i*2] = p[1], p[2]
	end
	return result
end

--How much pieces bounce: they leave what they hit at this much of the speed they hit it with.
--LÖVE 0.7's 0.1 was hardly visible on Chipmunk; 0.4 reaches the physics' limit on rising when
--holding down (MAXRISE in physics_chipmunk.lua).
local bounciness = 0.25

--Shapes in LÖVE 0.7 had friction 0.5 and density 1. 0.8's fixtures have other defaults, so
--these set 0.7's values.
local function shapedefaults(shape)
	shape:setFriction(0.5)
	shape:setRestitution(bounciness)
	return shape
end

function newrectangleshape(body, x, y, width, height)
	return shapedefaults(physics.newrectangle(body, x, y, width, height))
end

function newpolygonshape(body, ...)
	return shapedefaults(physics.newpolygon(body, table.unpack(convexhull({...}))))
end

--Pieces that have stopped moving are the pile, which a platform can keep drawn (platform.keepspile)
--rather than draw each piece every frame. A piece joins it once it's been still a few frames, and
--leaves it once it's visibly moved from where it was drawn into it.
local JOINFRAMES = 3
local STILL = 0.1 --screen pixels a frame, for joining
local MOVED = 0.5 --screen pixels from where it joined, for leaving
local pile, last, pilebodies = {}, setmetatable({}, {__mode="k"}), nil

local function distance(pose, x, y, angle) --in screen pixels; turning counts at a block's half-width
	return (math.abs(x - pose[1]) + math.abs(y - pose[2]) + math.abs(angle - pose[3])*16)*physicsscale
end

local function drawpiece(i, v, x, y, angle)
	if platform.drawbody then
		platform.drawbody(v, physicsscale)
		return
	end
	platform.drawpiece( tetriimages[i], piecepolygons(tetrishapes[i]), x*physicsscale, y*physicsscale, angle, piececenter[tetrikind[i]][1]*scale, piececenter[tetrikind[i]][2]*scale)
end

function drawpieces() --tetribodies, with the pile kept drawn where the platform does that
	if pause then
		return
	end
	if not platform.keepspile then
		for i, v in pairs(tetribodies) do
			drawpiece(i, v, v:getX(), v:getY(), v:getAngle())
		end
		return
	end
	if pilebodies ~= tetribodies then --a new game
		pile, pilebodies = {}, tetribodies
		platform.clearpile()
	end
	--first what leaves the pile, so it's patched before it's drawn. A piece the scheduler has frozen
	--can't have moved: there's nothing to look up.
	local seen, poses = {}, {}
	for i, v in pairs(tetribodies) do
		seen[v] = true
		if not (pile[v] and scheduler_frozen(v)) then
			local x, y, angle = v:getX(), v:getY(), v:getAngle()
			poses[v] = {x, y, angle}
			if pile[v] and distance(pile[v], x, y, angle) > MOVED then
				pile[v] = nil
				platform.unpile(v)
			end
		end
	end
	for v in pairs(pile) do
		if not seen[v] then
			pile[v] = nil
			platform.unpile(v)
		end
	end
	platform.drawpile()
	--then what's moving, and what's joining the pile
	for i, v in pairs(tetribodies) do
		if not pile[v] then
			local x, y, angle = poses[v][1], poses[v][2], poses[v][3]
			local l = last[v]
			if l and i ~= 1 and distance(l, x, y, angle) < STILL then
				l.still = l.still + 1
			else
				last[v] = {x, y, angle, still=0}
				l = last[v]
			end
			l[1], l[2], l[3] = x, y, angle
			if l.still >= JOINFRAMES then
				pile[v] = {x, y, angle}
				platform.pilepiece(v, piecepolygons(tetrishapes[i]))
			else
				drawpiece(i, v, x, y, angle)
			end
		end
	end
end

function piecepolygons(shapes) --where a piece's shapes are on the screen: {{x1, y1, x2, y2, ...}, ...}
	local polygons = {}
	for _, shape in pairs(shapes) do
		local points = physics.getworldpoints(shape)
		for j = 1, #points do
			points[j] = points[j]*physicsscale
		end
		polygons[#polygons+1] = points
	end
	return polygons
end

function getrainbowcolor(i)
	local r, g, b
	if i < 1/6 then
		r = 1
		g = i*6
		b = 0
	elseif i >= 1/6 and i < 2/6 then
		r = (1/6-(i-1/6))*6
		g = 1
		b = 0
	elseif i >= 2/6 and i < 3/6 then
		r = 0
		g = 1
		b = (i-2/6)*6
	elseif i >= 3/6 and i < 4/6 then
		r = 0
		g = (1/6-(i-3/6))*6
		b = 1
	elseif i >= 4/6 and i < 5/6 then
		r = (i-4/6)*6
		g = 0
		b = 1
	else
		r = 1
		g = 0
		b = (1/6-(i-5/6))*6
	end
	
	return {r, g, b}
end

function game_keypressed( key )
	if key == "f5" then
		scheduler_toggle()
		return
	end
	
	if gamestate == nil then
		if key == "return" then
			gamestate = "title"
			platform.setbackgroundcolor( 0, 0, 0)
			platform.play(musictitle)
		end
		
	elseif gamestate == "logo" then
		if key == "return" then
			gamestate = "title"
			platform.setbackgroundcolor( 0, 0, 0)
			platform.play(musictitle)
		end
		
	elseif gamestate == "credits" then
		if key == "return" then
			gamestate = "title"
			platform.setbackgroundcolor( 0, 0, 0)
			platform.play(musictitle)
		end
		
	elseif gamestate == "title" then
		if key == "return" then
			if soundenabled then
				platform.stop(musictitle)
				if musicno < 4 then
					platform.play(music[musicno])
				end
			end
			gamestate = "menu"
		elseif key == "escape" then
			platform.quit()
		end
		
	elseif gamestate == "menu" then	
		oldmusicno = musicno
		if key == "escape" then
			if musicno < 4 then
				platform.stop(music[musicno])
			end
			gamestate = "title"
			if soundenabled then
			platform.stop(musictitle)
			platform.play(musictitle)
			end
		elseif key == "backspace" then
			newhighscores()
		elseif key == "return" then
			if gameno == 1 then
				gameA_load()
			else
				gameB_load()
			end
		elseif key == "left" then
			if selection == 2 or selection == 4 or selection == 6 then
				selection = selection - 1
				selectblink = true
				oldtime = platform.gettime()
			end
		elseif key == "right" then
			if selection == 1 or selection == 3 or selection == 5 then
				selection = selection + 1
				selectblink = true
				oldtime = platform.gettime()
			end
		elseif key == "up" then
			if selection == 3 or selection == 4 or selection == 5 or selection == 6 then
				selection = selection - 2
				selectblink = true
				oldtime = platform.gettime()
				if selection < 3 then
					selection = gameno
					selectblink = false
					oldtime = platform.gettime()
				end
			elseif selection == 1 or selection == 2 then
				selection = musicno + 2
				selectblink = false
				oldtime = platform.gettime()
			end
		elseif key == "down" then
			if selection == 1 or selection == 2 or selection == 3 or selection == 4 then
				selection = selection + 2
				selectblink = true
				oldtime = platform.gettime()
				if selection > 2 and selection < 5 then
					selection = musicno + 2
					selectblink = false
					oldtime = platform.gettime()
				end
			elseif selection == 5 or selection == 6 then
				selection = gameno
				selectblink = false
				oldtime = platform.gettime()
			end
		end
		if selection > 2 and key ~= "escape" then
			musicno = selection - 2
			if oldmusicno ~= musicno and oldmusicno ~= 4 then
				platform.stop(music[oldmusicno])
			end
			if musicno < 4 then
				platform.play(music[musicno])
			end
		elseif key ~= "escape" then
			gameno = selection
			loadhighscores()
		end
	
	elseif gamestate == "gameA" or gamestate == "gameB" or gamestate == "failingA" or gamestate == "failingB" then

		if key == "return" then
			pause = not pause

			if pause == true then
				if musicno < 4 then
					platform.pause(music[musicno])
				end
				platform.stop(pausesound)
				platform.play(pausesound)
			else
				if musicno < 4 then
					platform.resume(music[musicno])
				end
			end
		end
		if gamestate == "gameA" or gamestate == "gameB" then
			if key == "escape" then
				oldtime = platform.gettime()
				gamestate = "menu"
			end
			
			if pause == false and (cuttingtimer == lineclearduration or gamestate == "gameB") then
				--if key == "up" then --STOP ROTATION OF BLOCK (makes it too easy..)
				--	tetribodies[counter]:setAngularVelocity(0)
				--end
				if key == "left" or key == "right" then
					platform.stop(blockmove)
					platform.play(blockmove)
				elseif key == "y" or key == "z" or key == "w" or key == "x" then
					platform.stop(blockturn)
					platform.play(blockturn)
				end
			end
		end
	elseif gamestate == "failed" then
		if key == "return" or key == "y" or key == "z" or key == "x" or key == "w" or key == "left" or key == "down" or key == "up" or key == "right" then 
			platform.stop(gameover2)
			rocket_load()
		end
	elseif gamestate == "highscoreentry" then
		if key == "return" then
			gamestate = "menu"
			savehighscores()
			if musicchanged == true then
				platform.stop(musichighscore)
			else
				platform.stop(highscoreintro)
			end
			if musicno < 4 then
				platform.play(music[musicno])
			end
		elseif key == "backspace" then
			if highscorename[highscoreno]:len() > 0 then
				cursorblink = true
				highscorename[highscoreno] = string.sub(highscorename[highscoreno], 1, highscorename[highscoreno]:len()-1)
			end
		end
	elseif string.sub(gamestate, 1, 6) == "rocket" then
		if key == "return" then
			platform.stop(musicrocket1to3)
			platform.stop(musicrocket4)
			failed_checkhighscores()
		end
	end
end

function game_textinput( text ) --typed characters, for entering a name
	if gamestate == "highscoreentry" and text:len() == 1 and whitelist[text:byte()] == true then
		if highscorename[highscoreno]:len() < 6 then
			cursorblink = true
			highscorename[highscoreno] = highscorename[highscoreno] .. text
			platform.stop(highscorebeep)
			platform.play(highscorebeep)
		end
	end
end