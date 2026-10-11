--Simulates only part of the pile in game A, for Playdate, where simulating it all is too slow.
--Pieces near the top of the pile and anything moving stay dynamic; the rest are frozen (static) and
--take turns being dynamic again, the ones most likely to move first. Changes are paced in time, one
--a frame at the Playdate's 30 frames a second, since each costs about a millisecond there.
--On where platform.schedulephysics says (Playdate); F5 turns it on and off.
--From the prototype on the physics-scheduler branch; see pd-box2dbench's NOTES.md.

scheduler = {
	enabled = false,
	liveRows = 2, --pieces reaching within this many rows of the top of the pile are never frozen
	maxAwake = 3, --deep pieces simulated at once, unless more are still moving
	changesPerSecond = 30, --switches between static and dynamic
	idleSpeed = 2, --px/s; a piece slower than this (and hardly turning) is idle
	idleTime = 0.5, --seconds a deep piece must be idle before it can be frozen...
	maxTurn = 1, --...or seconds it's been awake, if it's slow right now (landings jolt the whole pile,
	             --so with pieces landing often, nothing stays idle for long)
	bumpSpeed = 20, --px/s; a piece moving this fast bumps the frozen pieces it touches

	--a frozen piece's claim to be woken next
	ageWeight = 30, --per second since it was frozen
	bumpWeight = 60, --per bump (speed / bumpSpeed of whatever hit it)
	movedWeight = 20, --per pixel it moved on its last turn
	depthWeight = 5, --taken off per row below the live rows

	changes = 0, --switches made, for perf.lua
	budget = 0, --changes earned but not yet made
}

local info = setmetatable({}, {__mode = "k"}) --body -> bookkeeping, forgotten with the body

local function infoFor(body)
	local i = info[body]
	if not i then
		i = {idle = 0, awake = 0, age = 0, bump = 0, moved = 0, wakeX = body:getX(), wakeY = body:getY(), wakeAngle = body:getAngle()}
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

local function wake(body)
	local i = infoFor(body)
	body:setType("dynamic")
	i.idle, i.awake, i.bump = 0, 0, 0
	i.wakeX, i.wakeY, i.wakeAngle = body:getX(), body:getY(), body:getAngle()
	scheduler.changes = scheduler.changes + 1
end

local function freeze(body)
	local i = infoFor(body)
	--how far it settled on its turn; turning counts at a block's half-width
	i.moved = math.sqrt((body:getX() - i.wakeX)^2 + (body:getY() - i.wakeY)^2) + math.abs(body:getAngle() - i.wakeAngle) * 16
	i.age = 0
	body:setType("static")
	scheduler.changes = scheduler.changes + 1
end

local function wakeAll()
	for _, body in ipairs(pileBodies()) do
		if body:getType() == "static" then
			wake(body)
		end
	end
end

local function bumpTouching(body, speed, frozen)
	for _, other in ipairs(physics.touching(body)) do
		if frozen[other] then
			local i = infoFor(other)
			i.bump = i.bump + speed / scheduler.bumpSpeed
		end
	end
end

function scheduler_toggle()
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
	if gamestate ~= "gameA" then --the floor goes away when failing; let everything fall
		wakeAll()
		return
	end

	local bodies = pileBodies()
	local tops, frozen = {}, {}
	local pileTop = math.huge
	for _, body in ipairs(bodies) do
		tops[body] = physics.gettop(body)
		pileTop = math.min(pileTop, tops[body])
		frozen[body] = body:getType() == "static"
	end
	local liveY = pileTop + scheduler.liveRows * 32

	--bookkeeping, and bumps from anything moving (the falling piece included)
	if type(tetribodies[1]) == "table" then
		local vx, vy = tetribodies[1]:getLinearVelocity()
		bumpTouching(tetribodies[1], math.sqrt(vx*vx + vy*vy), frozen)
	end
	for _, body in ipairs(bodies) do
		local i = infoFor(body)
		if not frozen[body] then
			local vx, vy = body:getLinearVelocity()
			local speed = math.sqrt(vx*vx + vy*vy)
			i.awake = i.awake + dt
			i.slow = speed < scheduler.idleSpeed and math.abs(body:getAngularVelocity()) < 0.05
			if i.slow then
				i.idle = i.idle + dt
			else
				i.idle = 0
			end
			if speed > scheduler.bumpSpeed then
				bumpTouching(body, speed, frozen)
			end
		else
			i.age = i.age + dt
		end
	end

	--changes come at changesPerSecond, at most one a frame (the budget doesn't build up beyond that)
	scheduler.budget = math.min(scheduler.budget + dt * scheduler.changesPerSecond, 1)
	if scheduler.budget < 1 then
		return
	end

	--one change: a frozen piece in the live rows first, then a deep one if there's room, otherwise
	--freeze the deep piece that's been idle longest
	local bestFrozen, bestScore, deepAwake, idlest = nil, -math.huge, 0, nil
	for _, body in ipairs(bodies) do
		local i = info[body]
		local live = tops[body] < liveY
		if frozen[body] then
			local score = live and math.huge
				or i.age * scheduler.ageWeight + i.bump * scheduler.bumpWeight + i.moved * scheduler.movedWeight
				- (tops[body] - liveY) / 32 * scheduler.depthWeight
			if score > bestScore then
				bestFrozen, bestScore = body, score
			end
		elseif not live then
			deepAwake = deepAwake + 1
			local done = i.idle >= scheduler.idleTime or (i.slow and i.awake >= scheduler.maxTurn)
			if done and (not idlest or i.idle + i.awake > info[idlest].idle + info[idlest].awake) then
				idlest = body
			end
		end
	end

	if bestFrozen and (bestScore == math.huge or deepAwake < scheduler.maxAwake) then
		wake(bestFrozen)
		scheduler.budget = scheduler.budget - 1
	elseif idlest and deepAwake >= scheduler.maxAwake then
		freeze(idlest)
		scheduler.budget = scheduler.budget - 1
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

function scheduler_simulated() --pile pieces that are dynamic, for perf.lua
	local n = 0
	for _, body in ipairs(pileBodies()) do
		if body:getType() == "dynamic" then
			n = n + 1
		end
	end
	return n
end
