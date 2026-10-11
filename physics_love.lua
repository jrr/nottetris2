--The physics the game needs, on LÖVE (Box2D). A Chipmunk version of this file provides the same functions.
--Look love.* up on every call rather than keeping references, as platform_love.lua does.
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