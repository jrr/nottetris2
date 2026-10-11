--nt_physics.c, the game's physics on Chipmunk, on LÖVE: `make -C native` builds it as a library
--(the harness does that before the game plays), and LuaJIT's FFI calls it. This makes the global
--nt that physics_chipmunk.lua uses: the C functions, taking and returning Lua values. On Playdate,
--C registers the same functions.
local ffi = require "ffi"

ffi.cdef[[
typedef struct ntWorld ntWorld;
typedef struct cpBody cpBody;
typedef struct cpShape cpShape;

ntWorld *nt_world_new(double gravityx, double gravityy);
void nt_world_free(ntWorld *world);
void nt_world_step(ntWorld *world, double dt);
int nt_world_contacts(ntWorld *world, const int **pairs);

cpBody *nt_body_new(ntWorld *world, double x, double y, int dynamic);
void nt_body_free(cpBody *body);
void nt_body_getposition(cpBody *body, double *out);
void nt_body_setposition(cpBody *body, double x, double y);
double nt_body_getangle(cpBody *body);
void nt_body_setangle(cpBody *body, double angle);
void nt_body_getvelocity(cpBody *body, double *out);
void nt_body_setvelocity(cpBody *body, double x, double y);
double nt_body_getangularvelocity(cpBody *body);
void nt_body_setangularvelocity(cpBody *body, double w);
void nt_body_getworldcenter(cpBody *body, double *out);
void nt_body_applyforce(cpBody *body, double fx, double fy, double x, double y);
void nt_body_applytorque(cpBody *body, double torque);
void nt_body_setdamping(cpBody *body, double damping);
void nt_body_resetmass(cpBody *body);
double nt_body_getmass(cpBody *body);
void nt_body_tolocal(cpBody *body, double x, double y, double *out);
void nt_body_toworld(cpBody *body, double x, double y, double *out);

cpShape *nt_shape_newpolygon(cpBody *body, int count, const double *points, int id);
void nt_shape_free(cpShape *shape);
void nt_shape_setfriction(cpShape *shape, double friction);
void nt_shape_setrestitution(cpShape *shape, double restitution);
void nt_shape_setdensity(cpShape *shape, double density);
void nt_shape_setfilter(cpShape *shape, unsigned categories, unsigned mask);
int nt_shape_testpoint(cpShape *shape, double x, double y);
double nt_shape_raycast(cpShape *shape, double x1, double y1, double x2, double y2);
int nt_shape_getworldpoints(cpShape *shape, double *out);
]]

local MAXPOINTS = 8 --NT_MAXPOINTS
local lib = ffi.load(love.filesystem.getSource() .. "/native/nt_physics.so")
local out = ffi.new("double[?]", MAXPOINTS*2)
local contacts = ffi.new("const int *[1]")

nt = {}

function nt.world_new(gravityx, gravityy) --freed once nothing refers to it
	return ffi.gc(lib.nt_world_new(gravityx, gravityy), lib.nt_world_free)
end

function nt.world_step(world, dt)
	lib.nt_world_step(world, dt)
end

function nt.world_contacts(world) --{a1, b1, a2, b2, ...}: shape ids
	local t = {}
	for i = 0, lib.nt_world_contacts(world, contacts)*2-1 do
		t[i+1] = contacts[0][i]
	end
	return t
end

function nt.body_new(world, x, y, dynamic)
	return lib.nt_body_new(world, x, y, dynamic and 1 or 0)
end

function nt.body_free(body)
	lib.nt_body_free(body)
end

function nt.body_getposition(body)
	lib.nt_body_getposition(body, out)
	return out[0], out[1]
end

function nt.body_setposition(body, x, y)
	lib.nt_body_setposition(body, x, y)
end

function nt.body_getangle(body)
	return lib.nt_body_getangle(body)
end

function nt.body_setangle(body, angle)
	lib.nt_body_setangle(body, angle)
end

function nt.body_getvelocity(body)
	lib.nt_body_getvelocity(body, out)
	return out[0], out[1]
end

function nt.body_setvelocity(body, x, y)
	lib.nt_body_setvelocity(body, x, y)
end

function nt.body_getangularvelocity(body)
	return lib.nt_body_getangularvelocity(body)
end

function nt.body_setangularvelocity(body, w)
	lib.nt_body_setangularvelocity(body, w)
end

function nt.body_getworldcenter(body)
	lib.nt_body_getworldcenter(body, out)
	return out[0], out[1]
end

function nt.body_applyforce(body, fx, fy, x, y)
	lib.nt_body_applyforce(body, fx, fy, x, y)
end

function nt.body_applytorque(body, torque)
	lib.nt_body_applytorque(body, torque)
end

function nt.body_setdamping(body, damping)
	lib.nt_body_setdamping(body, damping)
end

function nt.body_resetmass(body)
	lib.nt_body_resetmass(body)
end

function nt.body_getmass(body)
	return lib.nt_body_getmass(body)
end

function nt.body_tolocal(body, x, y)
	lib.nt_body_tolocal(body, x, y, out)
	return out[0], out[1]
end

function nt.body_toworld(body, x, y)
	lib.nt_body_toworld(body, x, y, out)
	return out[0], out[1]
end

function nt.shape_newpolygon(body, points, id) --points: {x1, y1, x2, y2, ...}
	local count = math.min(#points/2, MAXPOINTS)
	for i = 1, count*2 do
		out[i-1] = points[i]
	end
	return lib.nt_shape_newpolygon(body, count, out, id)
end

function nt.shape_free(shape)
	lib.nt_shape_free(shape)
end

function nt.shape_setfriction(shape, friction)
	lib.nt_shape_setfriction(shape, friction)
end

function nt.shape_setrestitution(shape, restitution)
	lib.nt_shape_setrestitution(shape, restitution)
end

function nt.shape_setdensity(shape, density)
	lib.nt_shape_setdensity(shape, density)
end

function nt.shape_setfilter(shape, categories, mask)
	lib.nt_shape_setfilter(shape, categories, mask)
end

function nt.shape_testpoint(shape, x, y)
	return lib.nt_shape_testpoint(shape, x, y) ~= 0
end

function nt.shape_raycast(shape, x1, y1, x2, y2) --0-1, or nil if it misses
	local fraction = lib.nt_shape_raycast(shape, x1, y1, x2, y2)
	if fraction >= 0 then
		return fraction
	end
end

function nt.shape_getworldpoints(shape) --{x1, y1, x2, y2, ...}
	local t = {}
	for i = 0, lib.nt_shape_getworldpoints(shape, out)*2-1 do
		t[i+1] = out[i]
	end
	return t
end