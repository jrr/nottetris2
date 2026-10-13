--The physics the game needs, on LÖVE (Box2D). physics_chipmunk.lua provides the same functions on Chipmunk.
--Look love.* up on every call rather than keeping references, as platform_love.lua does.
--
--These functions make worlds, bodies and shapes. The game then calls methods on them, by LÖVE's
--names, so another version's bodies and shapes need these (the harness's state dumps call the
--body ones too). Units are pixels, seconds and radians; y points down.
--  bodies: getX, getY, setY, getAngle, setAngle, getLinearVelocity, setLinearVelocity,
--    getAngularVelocity, setAngularVelocity, getWorldCenter, applyForce(fx, fy, x, y),
--    applyTorque, setLinearDamping, setBullet, resetMassData (mass from the shapes' density),
--    getMass, isAwake, getLocalPoint, getWorldPoint, destroy
--  shapes: setUserData, setFriction, setRestitution, setDensity, testPoint(x, y),
--    destroy, setCategory(n) and setMask(n, ...): Box2D's collision categories, 1-16; a shape
--    doesn't collide with shapes in the categories it masks
physics = {}

--LÖVE 0.7 collected contacts during world:update and only then called the collision
--callback, with each pair of shapes' data. 0.8 calls it in the middle of the update,
--when bodies can't be created, which the games do when a piece lands. So contacts are
--queued during the update and handed to the callback afterwards, as 0.7 did.
local queuedcollisions = {}

local function userdata(fixture) --nil if the fixture was destroyed by an earlier callback
	local ok, data = pcall(fixture.getUserData, fixture)
	return ok and data or nil
end

function physics.newworld(gravityx, gravityy, collide) --collide(a, b) gets the user data of two shapes that began touching, after the update
	local world = love.physics.newWorld(gravityx, gravityy, true)
	world:setCallbacks(function(a, b)
		table.insert(queuedcollisions, {collide, a, b})
	end)
	return world
end

function physics.update(world, dt)
	world:update(dt, 8, 6) --11 defaults to 3 position iterations; earlier versions ran 6
	local queue = queuedcollisions
	queuedcollisions = {}
	for _, c in ipairs(queue) do
		c[1](userdata(c[2]), userdata(c[3]))
	end
end

function physics.newbody(world, x, y, kind) --kind is "dynamic" or "static"
	return love.physics.newBody(world, x, y, kind)
end

--shapes, attached to a body, with density 1; points are in the body's coordinates
function physics.newrectangle(body, x, y, width, height) --centered on x, y
	return love.physics.newFixture(body, love.physics.newRectangleShape(x, y, width, height), 1)
end

function physics.newpolygon(body, ...) --x1, y1, x2, y2, ...: convex, at most 8 points
	return love.physics.newFixture(body, love.physics.newPolygonShape(...), 1)
end

--questions about a shape
function physics.raycast(shape, x1, y1, x2, y2) --how far along the line from x1, y1 to x2, y2 it first meets the shape (0-1), or nil
	local _, _, fraction = shape:rayCast(x1, y1, x2, y2, 1)
	return fraction
end

local function clip(points, line, below) --the part of a polygon {x1, y1, ...} on one side of a horizontal line
	local out, n = {}, #points/2
	for i = 1, n do
		local ax, ay = points[i*2-1], points[i*2]
		local j = i % n + 1
		local bx, by = points[j*2-1], points[j*2]
		local ain, bin
		if below then ain, bin = ay >= line, by >= line else ain, bin = ay <= line, by <= line end
		if ain then
			out[#out+1], out[#out+2] = ax, ay
		end
		if ain ~= bin then
			local t = (line - ay)/(by - ay)
			out[#out+1], out[#out+2] = ax + t*(bx - ax), line
		end
	end
	return out
end

local function area(points)
	local sum, n = 0, #points/2
	for i = 1, n do
		local j = i % n + 1
		sum = sum + points[i*2-1]*points[j*2] - points[j*2-1]*points[i*2]
	end
	return math.abs(sum)/2
end

function physics.rowareas(shape, rowheight) --the first row it reaches (from 0, at y 0), then its area in each row from there
	local points = physics.getworldpoints(shape)
	local ymin, ymax = points[2], points[2]
	for i = 4, #points, 2 do
		ymin, ymax = math.min(ymin, points[i]), math.max(ymax, points[i])
	end
	local first = math.floor(ymin/rowheight)
	local last = math.max(first, math.ceil(ymax/rowheight) - 1)
	local areas = {}
	for row = first, last do
		local band = clip(clip(points, row*rowheight, true), (row + 1)*rowheight, false)
		areas[#areas+1] = #band >= 6 and area(band) or 0
	end
	return first, table.unpack(areas)
end

function physics.getworldpoints(shape) --a polygon's points in world coordinates: {x1, y1, x2, y2, ...}
	return {shape:getBody():getWorldPoints(shape:getShape():getPoints())}
end