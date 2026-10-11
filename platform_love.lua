--Everything the game needs from the engine, on LÖVE. A Playdate version of this file provides the same functions.
--Look love.* up on every call rather than keeping references: the harness replaces some of them after this file loads.
platform = {}

function platform.gettime() --seconds, for timing animations
	return love.timer.getTime()
end