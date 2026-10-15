--The physics the game needs, on Chipmunk (nt_physics.c, through the global nt: nt_physics_love.lua
--on LÖVE). The same functions as physics_love.lua, which is Box2D, and bodies and shapes with the
--methods listed there.
physics = {}

--The fastest anything moves up, in pixels a second: a bounce never throws a piece far (Box2D had no limit).
--A landing at full speed (500, holding down) bounces up at about 50.
local MAXRISE = 200

local shapes = {} --by id, for reporting collisions
local lastid = 0
local bodies = setmetatable({}, {__mode = "v"}) --by id, for physics.schedule
local lastbodyid = 0

local Body = {}
Body.__index = Body
local Shape = {}
Shape.__index = Shape

local function check(object) --C would crash on what was destroyed; LÖVE gives an error
	return object.p or error("using a body or shape that was destroyed", 3)
end

function physics.newworld(gravityx, gravityy, collide) --collide(a, b) gets the user data of two shapes that began touching, after the update
	local world = {p=nt.world_new(gravityx, gravityy), collide=collide}
	nt.world_setmaxrise(world.p, MAXRISE)
	if platform.physicsiterations then --fewer, where speed matters more
		nt.world_setiterations(world.p, platform.physicsiterations)
	end
	return world
end

function physics.update(world, dt)
	nt.world_step(world.p, dt)
	for i = 1, nt.world_contactcount(world.p) do
		local a, b = nt.world_contact(world.p, i)
		a, b = shapes[a], shapes[b] --nil if an earlier callback destroyed it
		world.collide(a and a.userdata, b and b.userdata)
	end
end

function physics.newbody(world, x, y, kind) --kind is "dynamic" or "static"
	lastbodyid = lastbodyid + 1
	local body = setmetatable({p=nt.body_new(world.p, x, y, kind == "dynamic", lastbodyid), world=world, shapes={}}, Body)
	bodies[lastbodyid] = body
	return body
end

--shapes, attached to a body, with density 1; points are in the body's coordinates
function physics.newrectangle(body, x, y, width, height) --centered on x, y
	local w, h = width/2, height/2
	return physics.newpolygon(body, x-w,y-h, x+w,y-h, x+w,y+h, x-w,y+h)
end

function physics.newpolygon(body, ...) --x1, y1, x2, y2, ...: convex, at most 8 points
	lastid = lastid + 1
	local shape = setmetatable({p=nt.shape_newpolygon(check(body), lastid, ...), id=lastid, body=body, categories=1, mask=0xFFFF}, Shape)
	shapes[lastid] = shape
	body.shapes[shape] = true
	return shape
end

--questions about a shape
function physics.raycast(shape, x1, y1, x2, y2) --how far along the line from x1, y1 to x2, y2 it first meets the shape (0-1), or nil
	return nt.shape_raycast(check(shape), x1, y1, x2, y2)
end

function physics.rowareas(shape, rowheight) --the first row it reaches (from 0, at y 0), then its area in each row from there
	return nt.shape_rowareas(check(shape), rowheight)
end

function physics.gettop(body) --the smallest y of its shapes
	return nt.body_gettop(check(body))
end

function physics.setcollides(body, collides) --false: it collides with nothing
	nt.body_setcollides(check(body), collides)
end

function physics.setkind(body, kind) --the kind of piece it is (1-7), for a platform that draws pieces from the physics
	nt.body_setkind(check(body), kind)
end

--The scheduler (scheduler.lua), in C: its settings, then after each step its bookkeeping and at most
--one change, which it returns: the body it froze or woke, and true if it froze it.
local SCHEDULE = {"liveRows", "maxAwake", "changesPerSecond", "idleSpeed", "idleTime", "maxTurn", "bumpSpeed",
	"ageWeight", "bumpWeight", "movedWeight", "depthWeight"}

function physics.setschedule(world, settings)
	local values = {}
	for i, name in ipairs(SCHEDULE) do
		values[i] = settings[name]
	end
	nt.world_setschedule(world.p, table.unpack(values))
end

function physics.schedule(world, falling, dt) --falling: the piece not in the pile, or nil
	local id, frozen = nt.world_schedule(world.p, falling and check(falling), dt)
	if id ~= 0 then
		return bodies[id], frozen ~= 0
	end
end

--The pile's area in each line of the field (rows of rowheight from y 0): the same as adding up
--physics.rowareas for every shape in the pile, in one call, with each body's kept while it's frozen
--or still. The pile as for physics.schedule.
function physics.lineareas(world, falling, rowheight)
	return nt.world_lineareas(world.p, falling and check(falling), rowheight)
end

function physics.touching(body) --the bodies its shapes are touching: {body, ...}, maybe more than once
	local bodies = {}
	for _, id in ipairs({nt.body_touching(check(body))}) do
		if shapes[id] then
			bodies[#bodies+1] = shapes[id].body
		end
	end
	return bodies
end

function physics.getworldpoints(shape) --a polygon's points in world coordinates: {x1, y1, x2, y2, ...}
	return {nt.shape_getworldpoints(check(shape))}
end

--A polygon's points on the screen at scale, in whole pixels, so that a piece moves a pixel at a time
--all together and keeps its shape: {x1, y1, x2, y2, ...} (nt_shape_getscreenpoints)
function physics.getscreenpoints(shape, scale)
	return {nt.shape_screenpoints(check(shape), scale)}
end

--bodies
function Body:getPosition()
	return nt.body_getposition(check(self))
end

function Body:getX()
	return (nt.body_getposition(check(self)))
end

function Body:getY()
	local _, y = nt.body_getposition(check(self))
	return y
end

function Body:setY(y)
	local x = nt.body_getposition(check(self))
	nt.body_setposition(self.p, x, y)
end

function Body:getAngle()
	return nt.body_getangle(check(self))
end

function Body:setAngle(angle)
	nt.body_setangle(check(self), angle)
end

function Body:getLinearVelocity()
	return nt.body_getvelocity(check(self))
end

function Body:setLinearVelocity(x, y)
	nt.body_setvelocity(check(self), x, y)
end

function Body:getAngularVelocity()
	return nt.body_getangularvelocity(check(self))
end

function Body:setAngularVelocity(w)
	nt.body_setangularvelocity(check(self), w)
end

function Body:getWorldCenter()
	return nt.body_getworldcenter(check(self))
end

function Body:applyForce(fx, fy, x, y)
	nt.body_applyforce(check(self), fx, fy, x, y)
end

function Body:applyTorque(torque)
	nt.body_applytorque(check(self), torque)
end

function Body:setLinearDamping(damping)
	nt.body_setdamping(check(self), damping)
end

function Body:setBullet() --Chipmunk has no continuous collision; the pieces don't move fast enough to need it
end

function Body:resetMassData()
	nt.body_resetmass(check(self))
end

function Body:getMass()
	return nt.body_getmass(check(self))
end

function Body:isAwake() --false once it's been still a while, until something moves it
	return nt.body_isawake(check(self))
end

function Body:setAwake(awake) --true only: wakes it, and what it touches
	nt.body_wake(check(self))
end

function Body:getType()
	return nt.body_isstatic(check(self)) and "static" or "dynamic"
end

function Body:setType(kind) --"static": doesn't move, and stops; "dynamic" again: mass from its shapes
	nt.body_setstatic(check(self), kind == "static")
end

function Body:getLocalPoint(x, y)
	return nt.body_tolocal(check(self), x, y)
end

function Body:getWorldPoint(x, y)
	return nt.body_toworld(check(self), x, y)
end

function Body:destroy() --and its shapes
	nt.body_free(check(self))
	for shape in pairs(self.shapes) do
		shapes[shape.id] = nil
		shape.p = nil
	end
	self.p = nil
end

--shapes
function Shape:setUserData(data)
	self.userdata = data
end

function Shape:getUserData()
	return self.userdata
end

function Shape:setFriction(friction)
	nt.shape_setfriction(check(self), friction)
end

function Shape:setRestitution(restitution)
	nt.shape_setrestitution(check(self), restitution)
end

function Shape:setDensity(density)
	nt.shape_setdensity(check(self), density)
end

function Shape:testPoint(x, y)
	return nt.shape_testpoint(check(self), x, y)
end

local function bits(...) --Box2D's categories, 1-16, as bits
	local seen, sum = {}, 0
	for _, n in ipairs({...}) do
		if not seen[n] then
			seen[n] = true
			sum = sum + 2^(n-1)
		end
	end
	return sum
end

function Shape:setCategory(...)
	self.categories = bits(...)
	nt.shape_setfilter(check(self), self.categories, self.mask)
end

function Shape:setMask(...)
	self.mask = 0xFFFF - bits(...)
	nt.shape_setfilter(check(self), self.categories, self.mask)
end

function Shape:destroy()
	nt.shape_free(check(self))
	shapes[self.id] = nil
	self.body.shapes[self] = nil
	self.p = nil
end