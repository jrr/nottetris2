--Where the time goes, on the console every two seconds: frames a second, and milliseconds a frame
--in the physics step, the line fullness check (checklinedensity), the rest of the update and
--drawing. Imported after the game, which it wraps.
local ms = playdate.getCurrentTimeMilliseconds
local totals, frames, since = {}, 0, ms()

local function timed(name, f)
	return function(...)
		local t = ms()
		local a, b, c = f(...)
		totals[name] = (totals[name] or 0) + ms() - t
		return a, b, c
	end
end

physics.update = timed("physics", physics.update)
checklinedensity = timed("density", checklinedensity)
game_update = timed("update", game_update)
game_draw = timed("draw", game_draw)

local update = playdate.update
function playdate.update()
	update()
	frames = frames + 1
	local now = ms()
	if now - since >= 2000 then
		local shapes = 0
		for _, s in pairs(tetrishapes or {}) do
			for _ in pairs(s) do shapes = shapes + 1 end
		end
		local function avg(name) return (totals[name] or 0)/frames end
		print(string.format("%s %.1f fps | ms/frame: physics %.0f, density %.0f, other update %.0f, draw %.0f | pieces %d, shapes %d, mem %dk",
			tostring(gamestate), frames*1000/(now - since), avg("physics"), avg("density"),
			avg("update") - avg("physics") - avg("density"), avg("draw"), tetribodies and #tetribodies or 0, shapes,
			math.floor(collectgarbage("count"))))
		totals, frames, since = {}, 0, now
	end
end
