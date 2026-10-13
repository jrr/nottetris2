--Simulates only part of the pile in game A, for Playdate, where simulating it all is too slow.
--Pieces near the top of the pile and anything moving stay dynamic; the rest are frozen (static) and
--take turns being dynamic again, the ones most likely to move first. Changes are paced in time, one
--a frame at the Playdate's 30 frames a second, since each costs about a millisecond there.
--The pass over the pile each frame is in C (physics.schedule: nt_world_schedule in nt_physics.c),
--as on Playdate each call from Lua into C costs, and it needs several for every piece; the settings
--are here, and so are the end of the game and line clears.
--On where platform.schedulephysics says (Playdate); F5 turns it on and off.
--From the prototype on the physics-scheduler branch; see pd-box2dbench's NOTES.md.

scheduler = {
	enabled = false,
	liveRows = 1, --pieces reaching within this many rows of the top of the pile are never frozen
	maxAwake = 3, --deep pieces simulated at once, unless more are still moving
	changesPerSecond = 30, --switches between static and dynamic
	idleSpeed = 2, --px/s; a piece slower than this (and hardly turning) is idle
	idleTime = 0.5, --seconds a deep piece must be idle before it can be frozen...
	maxTurn = 1, --...or seconds it's been awake, if it's slow right now (landings jolt the whole pile,
	             --so with pieces landing often, nothing stays idle for long)
	bumpSpeed = 20, --px/s; a piece moving this fast bumps the frozen pieces it touches
	releaseSpeed = 6, --rows/s the pile is let go at when the game is lost, from the bottom up
	goneY = 648, --a piece that's entirely past this has fallen out (failing waits for this)

	--a frozen piece's claim to be woken next
	ageWeight = 30, --per second since it was frozen
	bumpWeight = 60, --per bump (speed / bumpSpeed of whatever hit it)
	movedWeight = 20, --per pixel it moved on its last turn
	depthWeight = 5, --taken off per row below the live rows

	changes = 0, --switches made, for perf.lua
	freezes = 0, --freezes made: each frozen piece has its number, so a later freeze can be told apart
}

--Body -> what the game needs to know without asking C each frame: whether it's frozen (false, or
--the freeze's number: scheduler_frozen) and, as frozen pieces don't move, where its top is.
local info = setmetatable({}, {__mode = "k"})

local function infoFor(body)
	local i = info[body]
	if not i then
		i = {frozen = false}
		info[body] = i
	end
	return i
end

local function pileBodies()
	local bodies = {}
	for i = 2, highestbody() do
		if type(tetribodies[i]) == "table" then
			bodies[#bodies+1] = tetribodies[i]
		end
	end
	return bodies
end

local function changed(body, frozen) --after C or this file froze or woke it
	local i = infoFor(body)
	if frozen then
		scheduler.freezes = scheduler.freezes + 1
		i.frozen, i.top = scheduler.freezes, physics.gettop(body)
	else
		i.frozen, i.top = false, nil
	end
	scheduler.changes = scheduler.changes + 1
end

local function wake(body)
	body:setType("dynamic")
	changed(body, false)
end

local function freeze(body)
	body:setType("static")
	changed(body, true)
end

local function wakeAll()
	for _, body in ipairs(pileBodies()) do
		if body:getType() == "static" then
			wake(body)
		end
	end
end

function scheduler_toggle()
	if not physics.schedule then
		print("[scheduler] needs Chipmunk's physics")
		return
	end
	scheduler.enabled = not scheduler.enabled
	if not scheduler.enabled and tetribodies then
		wakeAll()
	end
	print("[scheduler] " .. (scheduler.enabled and "on" or "off"))
end

function scheduler_update(dt) --after each physics step in game A
	if not scheduler.enabled then
		return
	end
	if gamestate ~= "gameA" then
		scheduler_failing(dt)
		return
	end
	scheduler.releaseY = nil
	if scheduler.world ~= world then --a new game
		physics.setschedule(world, scheduler)
		scheduler.world = world
	end
	local falling = type(tetribodies[1]) == "table" and tetribodies[1] or nil
	local body, frozen = physics.schedule(world, falling, dt)
	if body then
		changed(body, frozen)
	end
end

--When the game is lost the floor goes and the pile falls out. All of it falling at once is slow, so
--it's frozen and let go a row at a time from the bottom, each row falling clear of the next, and
--colliding with nothing: pieces falling together seldom touch, and solving their contacts was most
--of the physics. What's fallen out of sight is frozen again.
function scheduler_failing(dt)
	if not scheduler.releaseY then
		scheduler.releaseY = 18*32 --the bottom of the field
		for _, body in ipairs(pileBodies()) do
			if body:getType() == "dynamic" then
				freeze(body)
			end
		end
	end
	scheduler.releaseY = scheduler.releaseY - scheduler.releaseSpeed * 32 * dt
	for _, body in pairs(tetribodies) do
		local i = type(body) == "table" and infoFor(body)
		local top = i and (i.top or physics.gettop(body))
		if not top then
			--the piece being cut in a line clear isn't a body
		elseif i.frozen then
			if top > scheduler.releaseY and top < scheduler.goneY then
				wake(body)
				physics.setcollides(body, false)
			end
		elseif top > scheduler.goneY and body:getY() >= scheduler.goneY then --failing checks where bodies are, not their shapes
			physics.setcollides(body, false) --(the piece that lost the game still collides till now)
			freeze(body)
		end
	end
end

--A cleared line takes support from everything above it, and cutting needs the pieces it cuts dynamic
--(it reads their mass), so wake everything reaching down to the line first.
function scheduler_beforeclear(lineno)
	if not scheduler.enabled then
		return
	end
	for _, body in ipairs(pileBodies()) do
		if body:getType() == "static" and physics.gettop(body) < lineno * 32 then
			wake(body)
		end
	end
end

--Whether a piece is frozen, so that it can't have moved: nil if not, and if so a number that's the
--same for as long as it stays frozen.
function scheduler_frozen(body)
	local i = info[body]
	return i and i.frozen or nil
end

function scheduler_simulated() --pile pieces that are dynamic, for perf.lua
	local n = 0
	for _, body in ipairs(pileBodies()) do
		if body:getType() == "dynamic" then
			n = n + 1
		end
	end
	return n
end
