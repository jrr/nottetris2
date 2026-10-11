table.unpack = table.unpack or unpack --Lua 5.2 moved unpack into table; LÖVE's LuaJIT only has the global
require "platform_love"
require "nt_physics_love" --Chipmunk; physics_love.lua is the same physics on Box2D
require "physics_chipmunk"

function game_load()
	--requires--
	require "gameB"
	require "gameBmulti"
	require "gameA"
	require "menu"
	require "failed"
	require "rocket"
	
	vsync = true
	
	autosize()
	
	suggestedscale = math.min(math.floor((desktopheight-50)/144), math.floor((desktopwidth-10)/160))
	if suggestedscale > 5 then
		suggestedscale = 5
	end
	
	loadoptions()
	
	maxscale = math.min(math.floor(desktopheight/144), math.floor(desktopwidth/160)) 
	maxmpscale = math.min(math.floor(desktopheight/144), math.floor(desktopwidth/274)) 
	
	if fullscreen == false then
		if scale ~= 5 then
			platform.setmode( 160*scale, 144*scale, false, vsync, 16 )
		end
	else
		platform.setmode( desktopwidth, desktopheight, true, vsync, 16 ) --0.8 draws nothing after setMode(0, 0, true)
		platform.setmousevisible( false )
		desktopwidth, desktopheight = platform.getdimensions()
		saveoptions()
		
		suggestedscale = math.floor((desktopheight-50)/144)
		if suggestedscale > 5 then
			suggestedscale = 5
		end
		maxscale = math.min(math.floor(desktopheight/144), math.floor(desktopwidth/160))
		
		scale = maxscale
		
		fullscreenoffsetX = (desktopwidth-160*scale)/2
		fullscreenoffsetY = (desktopheight-144*scale)/2
	end
	
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
	
	musicresults = platform.newmusic( "sounds/resultsmusic" )
	platform.setvolume( musicresults, 1 )
	platform.setlooping( musicresults, false )
	
	highscoreintro = platform.newmusic( "sounds/highscoreintro" )
	platform.setvolume( highscoreintro, 0.6 )
	platform.setlooping( highscoreintro, false )
	
	musicoptions = platform.newmusic( "sounds/musicoptions" )
	platform.setvolume( musicoptions, 1 )
	platform.setlooping( musicoptions, true )
	
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
	
	changevolume(volume)
	
	--IMAGES THAT WON'T CHANGE HUE:
	rainbowgradient = platform.newimage("graphics/rainbow", false)
	
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
	
	math.randomseed( os.time() )
	math.random();math.random();math.random() --discarding some as they seem to tend to unrandomness.
	
	platform.setbackgroundcolor( 1, 1, 1 )

	p1wins = 0
	p2wins = 0

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
	playerselection = 1
	musicno = 1 --
	gameno = 1 --
	selection = 1 --
	colorizeduration = 3 --seconds
	lineclearduration = 1.2 --seconds
	lineclearblinks = 7 --i
	linecleartreshold = 8.1 --in blocks
	densityupdateinterval = 1/30 --in seconds
	nextpiecerotspeed = 1 --rad per seconnd
	minfps = 1/50 --dt doesn't go higher than this
	scoreaddtime = 0.5
	startdelaytime = 0
	
	blockstartY = -64 --where new blocks are created
	losingY = 0 --lose if block 1 collides above this line
	blockmass = 5 --probably obsolete because body:setMassFromShapes()
	blockrot = 10
	blockrestitution = 0.1
	minmass = 1
	
	optionschoices = {"volume", "color", "scale", "fullscrn"}
	
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
	stabyourselflogo = platform.newimage("graphics/stabyourselflogo", true)
	logo = platform.newimage("graphics/logo", true)
	title = platform.newimage("graphics/title", true)
	gametype = platform.newimage("graphics/gametype", true)
	mpmenu = platform.newimage("graphics/mpmenu", true)
	optionsmenu = platform.newimage("graphics/options", true)
	volumeslider = platform.newimage("graphics/volumeslider", true)
	--game--
	gamebackground = platform.newimage("graphics/gamebackground", true)
	gamebackgroundcutoff = platform.newimage("graphics/gamebackgroundgamea", true)
	gamebackgroundmulti = platform.newimage("graphics/gamebackgroundmulti", true)
	multiresults = platform.newimage("graphics/multiresults", true)
	
	number1 = platform.newimage("graphics/versus/number1", true)
	number2 = platform.newimage("graphics/versus/number2", true)
	number3 = platform.newimage("graphics/versus/number3", true)
	
	gameover = platform.newimage("graphics/gameover", true)
	gameovercutoff = platform.newimage("graphics/gameovercutoff", true)
	pausegraphic = platform.newimage("graphics/pause", true)
	pausegraphiccutoff = platform.newimage("graphics/pausecutoff", true)
	
	--figures--
	marioidle = platform.newimage("graphics/versus/marioidle", true)
	mariojump = platform.newimage("graphics/versus/mariojump", true)
	mariocry1 = platform.newimage("graphics/versus/mariocry1", true)
	mariocry2 = platform.newimage("graphics/versus/mariocry2", true)
	
	luigiidle = platform.newimage("graphics/versus/luigiidle", true)
	luigijump = platform.newimage("graphics/versus/luigijump", true)
	luigicry1 = platform.newimage("graphics/versus/luigicry1", true)
	luigicry2 = platform.newimage("graphics/versus/luigicry2", true)
	
	--rockets--
	rocket1 = platform.newimage("graphics/rocket1", true)
	rocket2 = platform.newimage("graphics/rocket2", true)
	rocket3 = platform.newimage("graphics/rocket3", true)
	spaceshuttle = platform.newimage("graphics/spaceshuttle", true)
	
	rocketbackground = platform.newimage("graphics/rocketbackground", true)
	bigrocketbackground = platform.newimage("graphics/bigrocketbackground", true)
	bigrockettakeoffbackground = platform.newimage("graphics/bigrockettakeoffbackground", true)
	
	
	smoke1left = platform.newimage("graphics/smoke1left", true)
	smoke1right = platform.newimage("graphics/smoke1right", true)
	smoke2left = platform.newimage("graphics/smoke2left", true)
	smoke2right = platform.newimage("graphics/smoke2right", true)
	
	fire1 = platform.newimage("graphics/fire1", true)
	fire2 = platform.newimage("graphics/fire2", true)
	firebig1 = platform.newimage("graphics/firebig1", true)
	firebig2 = platform.newimage("graphics/firebig2", true)
	
	congratsline = platform.newimage("graphics/congratsline", true)
	
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
	
	if gamestate == "logo" or gamestate == "credits" or gamestate == "title" or gamestate == "menu" or gamestate == "multimenu" or gamestate == "highscoreentry" or gamestate == "options" then
		menu_update(dt)
	elseif gamestate == "gameA" or gamestate == "failingA" then
		if pause == false then
			gameA_update(dt)
		end
	elseif gamestate == "gameB" or gamestate == "failingB" then
		if pause == false then
			gameB_update(dt)
		end
		elseif gamestate == "gameBmulti" or gamestate == "failingBmulti" or gamestate == "failedBmulti" or gamestate == "gameBmulti_results" then
		gameBmulti_update(dt)
	elseif gamestate == "rocket1" or gamestate == "rocket2" or gamestate == "rocket3" or gamestate == "rocket4" then
		rocket_update()
	end
end

function game_draw()
	if gamestate == "logo" or gamestate == "credits" or gamestate == "title" or gamestate == "menu" or gamestate == "multimenu" or gamestate == "highscoreentry" or gamestate == "options" then
		menu_draw()
	elseif gamestate == "gameA" or gamestate == "failingA" then
		gameA_draw()
	elseif gamestate == "gameB" or gamestate == "failingB" then
		gameB_draw()
	elseif gamestate == "gameBmulti" or gamestate == "failingBmulti" or gamestate == "failedBmulti" or gamestate == "gameBmulti_results" then
		gameBmulti_draw()
	elseif gamestate == "failed" then
		failed_draw()
	elseif gamestate == "rocket1" or gamestate == "rocket2" or gamestate == "rocket3" or gamestate == "rocket4" then
		rocket_draw()
	end
end

function changevolume(i)
	platform.setvolume( music[1], 0.6*i )
	platform.setvolume( music[2], 0.6*i )
	platform.setvolume( music[3], 0.6*i )
	platform.setvolume( musictitle, 0.6*i )
	platform.setvolume( musichighscore, 0.6*i )
	platform.setvolume( musicrocket4, 0.6*i )
	platform.setvolume( musicrocket1to3, 0.6*i )
	platform.setvolume( musicresults, i )
	platform.setvolume( highscoreintro, 0.6*i )
	platform.setvolume( musicoptions, i )
	platform.setvolume( boot, i )
	platform.setvolume( blockfall, i )
	platform.setvolume( blockturn, i )
	platform.setvolume( blockmove, i )
	platform.setvolume( lineclear, i )
	platform.setvolume( fourlineclear, i )
	platform.setvolume( gameover1, i )
	platform.setvolume( gameover2, i )
	platform.setvolume( pausesound, i )
	platform.setvolume( highscorebeep, i )
	platform.setvolume( newlevel, 0.6*i )
end

function loadoptions()
	if platform.exists("options.txt") then
		local s = platform.read("options.txt")
		local split1 = s:split("\n")
		for i = 1, #split1 do
			local split2 = split1[i]:split("=")
			if split2[1] == "volume" then
				local v = tonumber(split2[2])
				--clamp and round
				if v < 0 then
					v = 0
				elseif v > 1 then
					v = 1
				end
				v = math.floor(v*10)/10
				
				volume = v
				
			elseif split2[1] == "hue" then
				hue = tonumber(split2[2])
			
			elseif split2[1] == "scale" then
				scale = tonumber(split2[2])
			
			elseif split2[1] == "fullscreen" then
				if split2[2] == "true" then
					fullscreen = true
				else
					fullscreen = false
				end	
			end
		end
		
		if volume == nil then
			volume = 1
		end
		if hue == nil then
			hue = 0.08
		end
		if fullscreen == nil then
			fullscreen = false
		end
		
		if scale == nil then
			scale = suggestedscale
		end
		
		
	else
		volume = 1
		hue = 0.08
		autosize()
		scale = suggestedscale
		fullscreen = false
	end
	
	saveoptions()
end

function saveoptions()
	local s = ""
	
	s = s .. "volume=" .. volume .. "\n"
	s = s .. "hue=" .. hue .. "\n"
	s = s .. "scale=" .. scale .. "\n"
	s = s .. "fullscreen=" .. tostring(fullscreen) .. "\n"
	
	platform.write("options.txt", s)
end

function autosize()
	desktopwidth, desktopheight = platform.getdesktopdimensions()
end

function togglefullscreen(fullscr)
	fullscreen = fullscr
	platform.setmousevisible( not fullscreen )
	if fullscr == false then
		scale = suggestedscale
		physicsscale = scale/4
		platform.setmode( 160*scale, 144*scale, false, vsync, 16 )
	else
		platform.setmode( desktopwidth, desktopheight, true, vsync, 16 ) --0.8 draws nothing after setMode(0, 0, true)
		desktopwidth, desktopheight = platform.getdimensions()
		suggestedscale = math.min(math.floor((desktopheight-50)/144), math.floor((desktopwidth-10)/160))
		suggestedscale = math.min(math.floor((desktopheight-50)/144), math.floor((desktopwidth-10)/160))
		if suggestedscale > 5 then
			suggestedscale = 5
		end
		maxscale = math.min(math.floor(desktopheight/144), math.floor(desktopwidth/160))
		
		scale = maxscale
		physicsscale = scale/4
		
		fullscreenoffsetX = (desktopwidth-160*scale)/2
		fullscreenoffsetY = (desktopheight-144*scale)/2
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

function changescale(i)
	platform.setmode( 160*i, 144*i, false, vsync, 16 )
	nextpieceimg = {}
	for j = 1, 7 do
		nextpieceimg[j] = platform.newpieceimage( "graphics/pieces/"..j, i )
	end
	physicsscale = i/4
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
			if playerselection ~= 3 then
				if soundenabled then
					platform.stop(musictitle)
					if musicno < 4 then
						platform.play(music[musicno])
					end
				end
			end
			if playerselection == 1 then
				gamestate = "menu"
			elseif playerselection == 2 then
				gamestate = "multimenu"
			else
				gamestate = "options"
				if soundenabled then
				platform.stop(musictitle)
				platform.play(musicoptions)
				end
				optionsselection = 1
			end
		elseif key == "escape" then
			platform.quit()
		elseif key == "left" and playerselection > 1 then
			playerselection = playerselection - 1
		elseif key == "right" and playerselection < 3 then
			playerselection = playerselection + 1
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
	
	elseif gamestate == "options" then
		if key == "escape" then
			if soundenabled then
				platform.stop(musicoptions)
				platform.stop(musictitle)
				platform.play(musictitle)
			end
			saveoptions()
			loadimages()
			gamestate = "title"
		elseif key == "down" then
			optionsselection = optionsselection + 1
			if optionsselection > #optionschoices then
				optionsselection = 1
			end
			selectblink = true
			oldtime = platform.gettime()
			
		elseif key == "up" then
			optionsselection = optionsselection - 1
			if optionsselection == 0 then
				optionsselection = #optionschoices
			end
			selectblink = true
			oldtime = platform.gettime()
			
		elseif key == "left" then
			if optionsselection == 1 then
				if volume >= 0.1 then
					volume = volume - 0.1
					if volume < 0.1 then
						volume = 0
					end
					changevolume(volume)
				end
				
			elseif optionsselection == 3 then
				if fullscreen == false then
					if scale > 1 then
						scale = scale - 1
						changescale(scale)
					end
				end
				
			elseif optionsselection == 4 then
				if fullscreen == false then
					togglefullscreen(true)
				end
			
			end
			
		elseif key == "right" then
			if optionsselection == 1 then
				if volume <= 0.9 then
					volume = volume + 0.1
					changevolume(volume)
				end
				
			elseif optionsselection == 3 then
				if fullscreen == false then
					if scale < maxscale then
						scale = scale + 1
						changescale(scale)
					end
				end
				
			elseif optionsselection == 4 then
				if fullscreen == true then
					togglefullscreen(false)
				end
				
			end
			
		elseif key == "return" then
			if optionsselection == 1 then
				volume = 1
				changevolume(volume)
			elseif optionsselection == 2 then
				hue = 0.08
				optionsmenu = platform.newimage("graphics/options", true)
				volumeslider = platform.newimage("graphics/volumeslider", true)
			elseif optionsselection == 3 then
				if fullscreen == false then
					if scale ~= suggestedscale then
						scale = suggestedscale
						changescale(scale)
					end
				end
			elseif optionsselection == 4 then
				if fullscreen == true then
					togglefullscreen(false)
				end
			end
			
		end
	
	elseif gamestate == "multimenu" then	
		oldmusicno = musicno
		if key == "escape" then
			if musicno < 4 then
				platform.stop(music[musicno])
			end
			gamestate = "title"
			platform.stop(musictitle)
			platform.play(musictitle)
		elseif key == "return" then
			gameBmulti_load()
		elseif key == "left" or key == "a" then
			if selection == 2 or selection == 4 or selection == 6 then
				selection = selection - 1
				selectblink = true
				oldtime = platform.gettime()
			end
		elseif key == "right" or key == "d" then
			if selection == 1 or selection == 3 or selection == 5 then
				selection = selection + 1
				selectblink = true
				oldtime = platform.gettime()
			end
		elseif key == "up" or key == "w" then
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
		elseif key == "down" or key == "s" then
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
		if selection > 2 and key ~= "return" and key ~= "escape" then
			musicno = selection - 2
			if oldmusicno ~= musicno and oldmusicno ~= 4 then
				platform.stop(music[oldmusicno])
			end
			if musicno < 4 then
				platform.play(music[musicno])
			end
		elseif key ~= "return" and key ~= "escape" then
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
	elseif gamestate == "gameBmulti" and gamestarted == false then
		if key == "escape" then
			if not fullscreen then
				platform.setmode( 160*scale, 144*scale, false, vsync, 0 )
			end
			gamestate = "multimenu"
			if musicno < 4 then
				platform.play(music[musicno])
			end
		end
	elseif gamestate == "gameBmulti" and gamestarted == true then
		if key == "escape" then
			if not fullscreen then
				platform.setmode( 160*scale, 144*scale, false, vsync, 0 )
			end
			gamestate = "multimenu"
		end
		if key == "a" or key == "d" then
			platform.stop(blockmove)
			platform.play(blockmove)
		elseif key == "left" or key == "right" then
			platform.stop(blockmove)
			platform.play(blockmove)
		elseif key == "g" or key == "h" then
			platform.stop(blockturn)
			platform.play(blockturn)
		elseif key == "kp1" or key == "kp2" then
			platform.stop(blockturn)
			platform.play(blockturn)
		end
		
	elseif gamestate == "gameBmulti_results" then
		if key == "return" or key == "escape" then
			if musicno < 4 then
				platform.stop(musicresults)
				platform.play(music[musicno])
			end
			if not fullscreen then
				platform.setmode( 160*scale, 144*scale, false, vsync, 0 )
			end
			gamestate = "multimenu"
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