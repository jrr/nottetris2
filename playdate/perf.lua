--Where the time goes, on the console every two seconds: frames a second, and milliseconds a frame
--in the physics step, the line fullness check (checklinedensity), the rest of the update and
--drawing; and how many frames had the pile already drawn. Imported after the game, which it wraps.
local ms = playdate.getCurrentTimeMilliseconds
local totals, frames, since = {}, 0, ms()
local pilekept, piledrawn = 0, 0

local startpile = platform.startpile
function platform.startpile(version)
	local kept = startpile(version)
	if kept then pilekept = pilekept + 1 else piledrawn = piledrawn + 1 end
	return kept
end

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
		print(string.format("%s %.1f fps | ms/frame: physics %.0f, density %.0f, other update %.0f, draw %.0f | pieces %d, shapes %d, pile kept %d/%d, mem %dk",
			tostring(gamestate), frames*1000/(now - since), avg("physics"), avg("density"),
			avg("update") - avg("physics") - avg("density"), avg("draw"), tetribodies and #tetribodies or 0, shapes,
			pilekept, pilekept + piledrawn, math.floor(collectgarbage("count"))))
		if scheduler.enabled and gamestate == "gameA" then
			print(string.format("  scheduler: %d of the pile simulated, %d changes", scheduler_simulated(), scheduler.changes))
			scheduler.changes = 0
		end
		totals, frames, since = {}, 0, now
		pilekept, piledrawn = 0, 0
	end
end
