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