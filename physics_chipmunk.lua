--The physics the game needs, on Chipmunk (nt_physics.c, through the global nt: nt_physics_love.lua
--on LÖVE). The same functions as physics_love.lua, which is Box2D, and bodies and shapes with the
--methods listed there.
physics = {}

--The fastest anything moves up, in pixels a second: a bounce never throws a piece far (Box2D had no limit).
--A landing at full speed (500, holding down) bounces up at about 50.
local MAXRISE = 200

local shapes = {} --by id, for reporting collisions
local lastid = 0

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
	return setmetatable({p=nt.body_new(world.p, x, y, kind == "dynamic"), world=world, shapes={}}, Body)
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

function physics.getworldpoints(shape) --a polygon's points in world coordinates: {x1, y1, x2, y2, ...}
	return {nt.shape_getworldpoints(check(shape))}
end

--bodies
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