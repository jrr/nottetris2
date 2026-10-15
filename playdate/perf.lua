--Where the time goes, on the console every two seconds: frames a second, and milliseconds a frame
--in the physics step, the line fullness check (checklinedensity), the scheduler, the rest of the
--update and drawing (and the pieces' share of it); and how many pieces joined and left the pile.
--Imported after the game, which it wraps. The frame rate shows on the screen as well. And on the
--device, the system's share of the CPU for each part, garbage collection and serial output among
--them, which the timings above can't see (playdate.getStats).
local ms = playdate.getCurrentTimeMilliseconds
if playdate.setStatsInterval then
	playdate.setStatsInterval(2)
end
local totals, frames, since = {}, 0, ms()
local joined, left = 0, 0

local drawpieces = platform.drawpieces
function platform.drawpieces(...)
	local j, l = drawpieces(...)
	joined, left = joined + j, left + l
	return j, l
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
scheduler_update = timed("scheduler", scheduler_update)
game_update = timed("update", game_update)
game_draw = timed("draw", game_draw)
drawpieces = timed("pieces", drawpieces)

local update = playdate.update
function playdate.update()
	update()
	local gfx = playdate.graphics
	local ox, oy = gfx.getDrawOffset()
	gfx.setDrawOffset(0, 0)
	playdate.drawFPS(2, 2) --on the screen too, top left
	gfx.setDrawOffset(ox, oy)
	frames = frames + 1
	local now = ms()
	if now - since >= 2000 then
		local shapes = 0
		for _, s in pairs(tetrishapes or {}) do
			for _ in pairs(s) do shapes = shapes + 1 end
		end
		local function avg(name) return (totals[name] or 0)/frames end
		print(string.format("%s %.1f fps | ms/frame: physics %.0f, density %.0f, scheduler %.0f, other update %.0f, draw %.0f (pieces %.0f) | pieces %d, shapes %d, pile joined %d left %d, mem %dk",
			tostring(gamestate), frames*1000/(now - since), avg("physics"), avg("density"), avg("scheduler"),
			avg("update") - avg("physics") - avg("density") - avg("scheduler"), avg("draw"), avg("pieces"), tetribodies and #tetribodies or 0, shapes,
			joined, left, math.floor(collectgarbage("count"))))
		local stats = playdate.getStats and playdate.getStats()
		if stats then --percentages: only on the device
			local parts = {}
			for name, percent in pairs(stats) do
				parts[#parts+1] = string.format("%s %.0f%%", name, percent)
			end
			table.sort(parts)
			print("  cpu: " .. table.concat(parts, ", "))
		end
		if scheduler.enabled and gamestate == "gameA" then
			print(string.format("  scheduler: %d of the pile simulated, %d changes", scheduler_simulated(), scheduler.changes))
			scheduler.changes = 0
		end
		totals, frames, since = {}, 0, now
		joined, left = 0, 0
	end
end
