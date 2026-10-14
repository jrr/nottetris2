--Everything the game needs from the engine, on LÖVE. A Playdate version of this file provides the same functions.
--Look love.* up on every call rather than keeping references: the harness replaces some of them after this file loads.
platform = {}

--LÖVE calls the game through these; Playdate will call the same game_ functions
function love.load()
	game_load()
end

function love.update(dt)
	game_update(dt)
end

function love.draw()
	game_draw()
end

function love.keypressed(key)
	game_keypressed(key)
end

function love.textinput(text) --0.9 sends typed characters here instead of to keypressed
	game_textinput(text)
end

function platform.gettime() --seconds, for timing animations
	return love.timer.getTime()
end

--save files, by name, in the game's save directory
function platform.exists(name)
	return love.filesystem.getInfo(name) ~= nil --11 deprecates exists, and says so on screen
end

function platform.read(name) --the whole file, as a string
	return (love.filesystem.read(name))
end

function platform.write(name, s)
	love.filesystem.write(name, s)
end

--sounds, by path without extension: music is long and streamed, sounds are short effects
function platform.newmusic(path)
	return love.audio.newSource(path .. ".ogg", "stream")
end

function platform.newsound(path)
	return love.audio.newSource(path .. ".ogg", "stream") --11 needs the type; stream was the default
end

function platform.play(sound)
	love.audio.play(sound)
end

function platform.stop(sound)
	love.audio.stop(sound)
end

function platform.pause(sound)
	love.audio.pause(sound)
end

function platform.resume(sound)
	sound:play() --11 has no love.audio.resume; play resumes a paused source
end

function platform.setvolume(sound, volume)
	sound:setVolume(volume)
end

function platform.setlooping(sound, looping)
	sound:setLooping(looping)
end

--keys, by LÖVE's names, which the game uses for its controls: Playdate maps its buttons onto them
function platform.isdown(key) --held down right now
	return love.keyboard.isDown(key)
end

--the window
function platform.setmode(width, height, fullscr, vsync, fsaa) --0.8's setMode arguments; 0.9 takes a table of flags (fsaa is msaa from 0.10)
	love.window.setMode(width, height, {fullscreen=fullscr, vsync=vsync, msaa=fsaa})
end

function platform.setupscreen(vsync) --returns the scale to draw at: the window as big as fits on the screen, up to 5 times the Game Boy's
	local width, height = love.window.getDesktopDimensions()
	local scale = math.min(math.floor((height-50)/144), math.floor((width-10)/160), 5)
	if scale ~= 5 then
		platform.setmode( 160*scale, 144*scale, false, vsync, 16 )
	end
	return scale
end

function platform.randomseed()
	math.randomseed(os.time())
end

function platform.quit()
	love.event.quit() --0.8 renamed the "q" event to "quit"
end

--drawing, with LÖVE's arguments; colors are 0-1 (11 takes colors as 0-1)
function platform.draw(...) --image, x, y, rotation, scale x, scale y, origin x, origin y
	love.graphics.draw(...)
end

function platform.drawpiece(image, polygons, x, y, angle, originx, originy, kind) --a piece: its image turned by angle about its origin at x, y, and the same as polygons (of a kind of piece, 1-7), for platforms that draw those instead
	love.graphics.draw(image, x, y, angle, 1, 1, originx, originy)
end
--(a platform can instead have platform.drawbody(body, scale, kind), to draw a moving piece from its body,
--and platform.drawpreview(kind, x, y, scale), to draw the next piece rather than its image, top left at x, y)

--LÖVE draws every piece each frame; platforms with platform.keepspile keep the pieces that have
--stopped moving drawn instead (clearpile, pilepiece, unpile, drawpile)

function platform.print(...) --text, x, y, rotation, scale x, scale y, in the current font
	love.graphics.print(...)
end

function platform.setfont(font)
	love.graphics.setFont(font)
end

function platform.setcolor(r, g, b)
	love.graphics.setColor(r, g, b)
end

function platform.setbackgroundcolor(r, g, b)
	love.graphics.setBackgroundColor(r, g, b)
end

function platform.rectangle(mode, x, y, width, height)
	love.graphics.rectangle(mode, x, y, width, height)
end

function platform.setscissor(...) --x, y, width, height in screen coordinates: draw only inside; none to draw everywhere
	love.graphics.setScissor(...)
end

--Something drawn by draw() in the top left corner, width by height; where a platform can, it keeps
--the drawing while key stays the same rather than draw again. LÖVE draws every frame.
function platform.drawcached(name, width, height, key, draw)
	draw()
end

function platform.drawnow(draw) --show a frame from the middle of an update
	love.graphics.clear()
	draw()
	love.graphics.present()
end

--images. These helpers are LÖVE only: they tint the art by hue, scale it, and pad it to powers of two for old graphics cards.
local newImageData, newPaddedImage, padImagedata, newPaddedImageFont, scaleImagedata
function newImageData(path, s)
	local imagedata = love.image.newImageData( path )
	
	if s then
		imagedata = scaleImagedata(imagedata, s)
	end
	
	local width, height = imagedata:getWidth(), imagedata:getHeight()
	
	local rr, rg, rb = table.unpack(getrainbowcolor(hue))
	
	for y = 0, height-1 do
		for x = 0, width-1 do
			local oldr, oldg, oldb, olda = imagedata:getPixel(x, y)
			oldr = oldr*255 --11 gives pixels as 0-1
			
			if olda ~= 0 then
				if oldr > 203 and oldr < 213 then --lightgrey
					local r = 145 + rr*64
					local g = 145 + rg*64
					local b = 145 + rb*64
					imagedata:setPixel(x, y, r/255, g/255, b/255, olda)
				elseif oldr > 107 and oldr < 117 then --darkgrey
					local r = 73 + rr*43
					local g = 73 + rg*43
					local b = 73 + rb*43
					imagedata:setPixel(x, y, r/255, g/255, b/255, olda)
				end
			end
		end
	end
	
	return imagedata
end

function newPaddedImage(filename, s)
    local source = newImageData(filename)
	
	if s then
		source = scaleImagedata(source, s)
	end
	
    local w, h = source:getWidth(), source:getHeight()
   
    -- Find closest power-of-two.
    local wp = 2^math.ceil(math.log(w)/math.log(2))
    local hp = 2^math.ceil(math.log(h)/math.log(2))
   
    -- Only pad if needed:
    if wp ~= w or hp ~= h then
        local padded = love.image.newImageData(wp, hp)
        padded:paste(source, 0, 0)
        return love.graphics.newImage(padded)
    end
   
    return love.graphics.newImage(source)
end

function padImagedata(source) --returns image, not imagedata!
    local w, h = source:getWidth(), source:getHeight()
   
    -- Find closest power-of-two.
    local wp = 2^math.ceil(math.log(w)/math.log(2))
    local hp = 2^math.ceil(math.log(h)/math.log(2))
   
    -- Only pad if needed:
    if wp ~= w or hp ~= h then
        local padded = love.image.newImageData(wp, hp)
        padded:paste(source, 0, 0)
        return love.graphics.newImage(padded)
    end
   
    return love.graphics.newImage(source)
end

function newPaddedImageFont(filename, glyphs)
    local source = newImageData(filename)
    local w, h = source:getWidth(), source:getHeight()
   
    -- Find closest power-of-two.
    local wp = 2^math.ceil(math.log(w)/math.log(2))
    local hp = 2^math.ceil(math.log(h)/math.log(2))
   
    -- Only pad if needed:
    if wp ~= w or hp ~= h then
        local padded = love.image.newImageData(wp, hp)
        padded:paste(source, 0, 0)
		local font = love.graphics.newImageFont(padded, glyphs, 1) --0.10 no longer adds a pixel between glyphs; 11 takes ImageData, not an Image
		font:setFilter("nearest", "nearest")
        return font
    end
	
    return love.graphics.newImageFont(source, glyphs, 1)
end

function scaleImagedata(imagedata, i)
	local width, height = imagedata:getWidth(), imagedata:getHeight()
	local scaled = love.image.newImageData(width*i, height*i)
	
	for y = 0, height*i-1 do
		for x = 0, width*i-1 do
			local r, g, b, a = imagedata:getPixel(math.floor(x/i), math.floor(y/i))
			scaled:setPixel(x, y, r, g, b, a)
		end
	end	
	
	return scaled
end


function platform.newimage(path) --path without extension; tinted by hue
	local image = newPaddedImage(path .. ".png")
	image:setFilter("nearest", "nearest")
	return image
end

function platform.newfont(path, glyphs) --an image font, tinted like the art
	return newPaddedImageFont(path .. ".png", glyphs)
end

--pieces: images drawn rotated, so smoothly filtered, and scaled up when loaded
function platform.newpieceimage(path, scale)
	return newPaddedImage(path .. ".png", scale)
end

--the pixels of a piece's image, which line clears cut away; made into an image to draw
function platform.newpiecepixels(path, scale)
	return newImageData(path .. ".png", scale)
end

function platform.copypixels(pixels)
	local copy = love.image.newImageData(pixels:getWidth(), pixels:getHeight())
	copy:paste(pixels, 0, 0, 0, 0, pixels:getWidth(), pixels:getHeight())
	return copy
end

function platform.getpixelsize(pixels)
	return pixels:getWidth(), pixels:getHeight()
end

function platform.erasepixel(pixels, x, y) --make it transparent
	pixels:setPixel(x, y, 1, 1, 1, 0)
end

function platform.imagefrompixels(pixels)
	return padImagedata(pixels)
end