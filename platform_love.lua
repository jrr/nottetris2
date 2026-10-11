--Everything the game needs from the engine, on LÖVE. A Playdate version of this file provides the same functions.
--Look love.* up on every call rather than keeping references: the harness replaces some of them after this file loads.
platform = {}

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

function platform.getdimensions() --the window's size
	return love.graphics.getWidth(), love.graphics.getHeight()
end

function platform.getdesktopdimensions()
	return love.window.getDesktopDimensions()
end

function platform.setmousevisible(visible)
	love.mouse.setVisible(visible)
end

function platform.quit()
	love.event.quit() --0.8 renamed the "q" event to "quit"
end