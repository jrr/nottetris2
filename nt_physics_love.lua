--nt_physics.c, the game's physics on Chipmunk, on LÖVE: `make -C native` builds it as a library
--(the harness does that before the game plays), and LuaJIT's FFI calls it. This makes the global
--nt that physics_chipmunk.lua uses: the C functions, taking and returning plain Lua values (no
--tables, which Playdate's C API can't make). On Playdate, playdate/nt_playdate.c registers the same.
local ffi = require "ffi"

--(ntReal, nt_physics.h's type for the game's own arithmetic, is double here: NT_FLOAT is for Playdate)
ffi.cdef[[
typedef struct ntWorld ntWorld;
typedef struct cpBody cpBody;
typedef struct cpShape cpShape;

ntWorld *nt_world_new(double gravityx, double gravityy);
void nt_world_free(ntWorld *world);
void nt_world_setmaxrise(ntWorld *world, double speed);
void nt_world_setiterations(ntWorld *world, int iterations);
void nt_world_step(ntWorld *world, double dt);
int nt_world_contacts(ntWorld *world, const int **pairs);
typedef struct {
	double liveRows, maxAwake, changesPerSecond, idleSpeed, idleTime, maxTurn, bumpSpeed;
	double ageWeight, bumpWeight, movedWeight, depthWeight;
} ntSchedule;
void nt_world_setschedule(ntWorld *world, const ntSchedule *schedule);
int nt_world_schedule(ntWorld *world, cpBody *falling, double dt, int *frozen);
void nt_world_lineareas(ntWorld *world, cpBody *falling, double rowheight, double *out);

cpBody *nt_body_new(ntWorld *world, double x, double y, int dynamic, int id);
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
int nt_body_isawake(cpBody *body);
void nt_body_wake(cpBody *body);
int nt_body_isstatic(cpBody *body);
int nt_body_setstatic(cpBody *body, int isstatic);
double nt_body_gettop(cpBody *body);
void nt_body_getbounds(cpBody *body, double *out);
void nt_body_setcollides(cpBody *body, int collides);
void nt_body_setkind(cpBody *body, int kind);
int nt_body_touching(cpBody *body, int *ids, int max);
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
int nt_shape_getscreenpoints(cpShape *shape, double scale, int *out);
int nt_shape_rowareas(cpShape *shape, double rowheight, int *firstrow, double *areas);
]]

local MAXPOINTS = 8 --NT_MAXPOINTS
local lib = ffi.load(love.filesystem.getSource() .. "/native/nt_physics.so")
local out = ffi.new("double[?]", MAXPOINTS*2)
local contacts = ffi.new("const int *[1]")
local firstrow = ffi.new("int[1]")
local MAXTOUCHING = 16
local ids = ffi.new("int[?]", MAXTOUCHING)

nt = {}

function nt.world_new(gravityx, gravityy) --freed once nothing refers to it
	return ffi.gc(lib.nt_world_new(gravityx, gravityy), lib.nt_world_free)
end

function nt.world_setmaxrise(world, speed)
	lib.nt_world_setmaxrise(world, speed)
end

local schedule = ffi.new("ntSchedule")
function nt.world_setschedule(world, ...) --the numbers in ntSchedule, in order
	local fields = {"liveRows", "maxAwake", "changesPerSecond", "idleSpeed", "idleTime", "maxTurn", "bumpSpeed",
		"ageWeight", "bumpWeight", "movedWeight", "depthWeight"}
	for i, field in ipairs(fields) do
		schedule[field] = select(i, ...)
	end
	lib.nt_world_setschedule(world, schedule)
end

local frozen = ffi.new("int[1]")
function nt.world_schedule(world, falling, dt) --the id of the body changed (or 0), and its freeze's number (or 0)
	local id = lib.nt_world_schedule(world, falling, dt, frozen)
	return id, frozen[0]
end

local LINES = 18 --NT_LINES
local lineareas = ffi.new("double[?]", LINES)
function nt.world_lineareas(world, falling, rowheight) --the pile's area in each line
	lib.nt_world_lineareas(world, falling, rowheight, lineareas)
	local areas = {}
	for line = 1, LINES do
		areas[line] = lineareas[line - 1]
	end
	return unpack(areas)
end

function nt.world_setiterations(world, iterations)
	lib.nt_world_setiterations(world, iterations)
end

function nt.world_step(world, dt)
	lib.nt_world_step(world, dt)
end

function nt.world_contactcount(world) --how many pairs of shapes began touching in the last step
	return lib.nt_world_contacts(world, contacts)
end

function nt.world_contact(world, i) --the ids of the shapes in pair i (from 1), after world_contactcount
	return contacts[0][i*2-2], contacts[0][i*2-1]
end

function nt.body_new(world, x, y, dynamic, id)
	return lib.nt_body_new(world, x, y, dynamic and 1 or 0, id)
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

function nt.body_isawake(body)
	return lib.nt_body_isawake(body) ~= 0
end

function nt.body_wake(body)
	lib.nt_body_wake(body)
end

function nt.body_isstatic(body)
	return lib.nt_body_isstatic(body) ~= 0
end

function nt.body_setstatic(body, isstatic) --the freeze's number, or 0
	return lib.nt_body_setstatic(body, isstatic and 1 or 0)
end

function nt.body_gettop(body)
	return lib.nt_body_gettop(body)
end

function nt.body_getbounds(body) --top, bottom
	lib.nt_body_getbounds(body, out)
	return out[0], out[1]
end

function nt.body_setcollides(body, collides)
	lib.nt_body_setcollides(body, collides and 1 or 0)
end

function nt.body_setkind(body, kind)
	lib.nt_body_setkind(body, kind)
end

function nt.body_touching(body) --the ids of the shapes it's touching, up to 16
	local n = lib.nt_body_touching(body, ids, MAXTOUCHING)
	local t = {}
	for i = 1, n do
		t[i] = ids[i-1]
	end
	return unpack(t, 1, n)
end

function nt.body_tolocal(body, x, y)
	lib.nt_body_tolocal(body, x, y, out)
	return out[0], out[1]
end

function nt.body_toworld(body, x, y)
	lib.nt_body_toworld(body, x, y, out)
	return out[0], out[1]
end

function nt.shape_newpolygon(body, id, ...) --x1, y1, x2, y2, ...
	local count = math.min(select("#", ...)/2, MAXPOINTS)
	for i = 1, count*2 do
		out[i-1] = (select(i, ...))
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

function nt.shape_rowareas(shape, rowheight) --the first row's number (from 0), then the shape's area in each row from there
	local n = lib.nt_shape_rowareas(shape, rowheight, firstrow, out)
	if n == 1 then
		return firstrow[0], out[0]
	end
	local t = {}
	for i = 1, n do
		t[i] = out[i-1]
	end
	return firstrow[0], unpack(t, 1, n)
end

local screenpoints = ffi.new("int[?]", MAXPOINTS*2)
function nt.shape_screenpoints(shape, scale) --x1, y1, x2, y2, ... in whole pixels
	local n = lib.nt_shape_getscreenpoints(shape, scale, screenpoints)*2
	local t = {}
	for i = 1, n do
		t[i] = screenpoints[i-1]
	end
	return unpack(t, 1, n)
end

function nt.shape_getworldpoints(shape) --x1, y1, x2, y2, ...
	local n = lib.nt_shape_getworldpoints(shape, out)*2
	local t = {}
	for i = 1, n do
		t[i] = out[i-1]
	end
	return unpack(t, 1, n)
end