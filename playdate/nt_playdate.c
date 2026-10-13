/* The game's physics on Playdate: registers nt_physics.c's functions with Playdate's Lua as the
 * global nt, the same functions nt_physics_love.lua makes on LÖVE. That's all the C the game has,
 * so this is also its entry point. Worlds, bodies and shapes go to Lua as objects of the classes
 * nt.World (freed when Lua collects it, with everything in it), nt.Body and nt.Shape.
 *
 * Playdate keeps one Lua object for each pointer it's given, with the class it was first given
 * with. Chipmunk's bodies and shapes are freed while the game plays, and a new body can get the
 * memory of a shape just freed, whose Lua object Lua hasn't collected yet: the new body would come
 * back as that nt.Shape. So bodies and shapes go to Lua by handles, which are only freed when Lua
 * collects their objects, and which empty when what they point to is freed. */
#include <math.h>
#include "pd_api.h"
#include "nt_physics.h"

static PlaydateAPI *pd;

static char WORLD[] = "nt.World";
static char BODY[] = "nt.Body";
static char SHAPE[] = "nt.Shape";

/* getArgObject gives NULL for anything but an object of that class: make that a Lua error, with a
 * traceback, rather than a crash in Chipmunk */
static void *object(int pos, char *type) {
	void *p = pd->lua->getArgObject(pos, type, NULL);
	if (p == NULL) {
		const char *class = NULL;
		int t = pd->lua->getArgType(pos, &class);
		pd->system->error("nt: argument %d should be %s, is type %d %s", pos, type, t, class ? class : "");
	}
	return p;
}

typedef struct {
	void *p; /* NULL once freed */
} handle;

static void push(void *p, char *type) {
	handle *h = pd->system->realloc(NULL, sizeof(handle));
	h->p = p;
	pd->lua->pushObject(h, type, 0);
}

static void *pointer(int pos, char *type) {
	handle *h = object(pos, type);
	if (h->p == NULL) {
		pd->system->error("nt: argument %d is a %s that was destroyed", pos, type);
	}
	return h->p;
}

static void freehandle(int pos, char *type) {
	pd->system->realloc(object(pos, type), 0);
}

static ntWorld *world(int pos) { return object(pos, WORLD); }
static cpBody *body(int pos) { return pointer(pos, BODY); }
static cpShape *shape(int pos) { return pointer(pos, SHAPE); }

static int body_gc(lua_State *L) { freehandle(1, BODY); return 0; }
static int shape_gc(lua_State *L) { freehandle(1, SHAPE); return 0; }
static double number(int pos) { return pd->lua->getArgFloat(pos); }

static int push2(double *out) {
	pd->lua->pushFloat(out[0]);
	pd->lua->pushFloat(out[1]);
	return 2;
}

static int world_gc(lua_State *L) { nt_world_free(world(1)); return 0; }
static int world_new(lua_State *L) { pd->lua->pushObject(nt_world_new(number(1), number(2)), WORLD, 0); return 1; }
static int world_setmaxrise(lua_State *L) { nt_world_setmaxrise(world(1), number(2)); return 0; }
static int world_setiterations(lua_State *L) { nt_world_setiterations(world(1), pd->lua->getArgInt(2)); return 0; }
static int world_step(lua_State *L) { nt_world_step(world(1), number(2)); return 0; }

static int world_contactcount(lua_State *L) {
	const int *pairs;
	pd->lua->pushInt(nt_world_contacts(world(1), &pairs));
	return 1;
}

static int world_contact(lua_State *L) {
	const int *pairs;
	nt_world_contacts(world(1), &pairs);
	int i = pd->lua->getArgInt(2);
	pd->lua->pushInt(pairs[i*2-2]);
	pd->lua->pushInt(pairs[i*2-1]);
	return 2;
}

static int body_new(lua_State *L) {
	push(nt_body_new(world(1), number(2), number(3), pd->lua->getArgBool(4)), BODY);
	return 1;
}

static int body_free(lua_State *L) { /* and its shapes: physics_chipmunk.lua forgets them */
	nt_body_free(body(1));
	((handle *)object(1, BODY))->p = NULL;
	return 0;
}

static int body_getposition(lua_State *L) {
	double out[2];
	nt_body_getposition(body(1), out);
	return push2(out);
}

static int body_setposition(lua_State *L) { nt_body_setposition(body(1), number(2), number(3)); return 0; }
static int body_getangle(lua_State *L) { pd->lua->pushFloat(nt_body_getangle(body(1))); return 1; }
static int body_setangle(lua_State *L) { nt_body_setangle(body(1), number(2)); return 0; }

static int body_getvelocity(lua_State *L) {
	double out[2];
	nt_body_getvelocity(body(1), out);
	return push2(out);
}

static int body_setvelocity(lua_State *L) { nt_body_setvelocity(body(1), number(2), number(3)); return 0; }
static int body_getangularvelocity(lua_State *L) { pd->lua->pushFloat(nt_body_getangularvelocity(body(1))); return 1; }
static int body_setangularvelocity(lua_State *L) { nt_body_setangularvelocity(body(1), number(2)); return 0; }

static int body_getworldcenter(lua_State *L) {
	double out[2];
	nt_body_getworldcenter(body(1), out);
	return push2(out);
}

static int body_applyforce(lua_State *L) {
	nt_body_applyforce(body(1), number(2), number(3), number(4), number(5));
	return 0;
}

static int body_applytorque(lua_State *L) { nt_body_applytorque(body(1), number(2)); return 0; }
static int body_setdamping(lua_State *L) { nt_body_setdamping(body(1), number(2)); return 0; }
static int body_resetmass(lua_State *L) { nt_body_resetmass(body(1)); return 0; }
static int body_getmass(lua_State *L) { pd->lua->pushFloat(nt_body_getmass(body(1))); return 1; }
static int body_isawake(lua_State *L) { pd->lua->pushBool(nt_body_isawake(body(1))); return 1; }
static int body_wake(lua_State *L) { nt_body_wake(body(1)); return 0; }
static int body_isstatic(lua_State *L) { pd->lua->pushBool(nt_body_isstatic(body(1))); return 1; }
static int body_setstatic(lua_State *L) { nt_body_setstatic(body(1), pd->lua->getArgBool(2)); return 0; }
static int body_gettop(lua_State *L) { pd->lua->pushFloat(nt_body_gettop(body(1))); return 1; }
static int body_setcollides(lua_State *L) { nt_body_setcollides(body(1), pd->lua->getArgBool(2)); return 0; }

static int body_touching(lua_State *L) { /* the ids of the shapes it's touching, up to 16 */
	int ids[16];
	int count = nt_body_touching(body(1), ids, 16);
	for (int i = 0; i < count; i++) {
		pd->lua->pushInt(ids[i]);
	}
	return count;
}

static int body_tolocal(lua_State *L) {
	double out[2];
	nt_body_tolocal(body(1), number(2), number(3), out);
	return push2(out);
}

static int body_toworld(lua_State *L) {
	double out[2];
	nt_body_toworld(body(1), number(2), number(3), out);
	return push2(out);
}

static int shape_newpolygon(lua_State *L) { /* body, id, x1, y1, x2, y2, ... */
	double points[NT_MAXPOINTS*2];
	int count = (pd->lua->getArgCount() - 2)/2;
	if (count > NT_MAXPOINTS) {
		count = NT_MAXPOINTS;
	}
	for (int i = 0; i < count*2; i++) {
		points[i] = number(i + 3);
	}
	push(nt_shape_newpolygon(body(1), count, points, pd->lua->getArgInt(2)), SHAPE);
	return 1;
}

static int shape_free(lua_State *L) {
	nt_shape_free(shape(1));
	((handle *)object(1, SHAPE))->p = NULL;
	return 0;
}
static int shape_setfriction(lua_State *L) { nt_shape_setfriction(shape(1), number(2)); return 0; }
static int shape_setrestitution(lua_State *L) { nt_shape_setrestitution(shape(1), number(2)); return 0; }
static int shape_setdensity(lua_State *L) { nt_shape_setdensity(shape(1), number(2)); return 0; }

static int shape_setfilter(lua_State *L) {
	nt_shape_setfilter(shape(1), pd->lua->getArgInt(2), pd->lua->getArgInt(3));
	return 0;
}

static int shape_testpoint(lua_State *L) {
	pd->lua->pushBool(nt_shape_testpoint(shape(1), number(2), number(3)));
	return 1;
}

static int shape_raycast(lua_State *L) { /* 0-1, or nil if it misses */
	double fraction = nt_shape_raycast(shape(1), number(2), number(3), number(4), number(5));
	if (fraction >= 0) {
		pd->lua->pushFloat(fraction);
	} else {
		pd->lua->pushNil();
	}
	return 1;
}

static int shape_getworldpoints(lua_State *L) { /* x1, y1, x2, y2, ... */
	double out[NT_MAXPOINTS*2];
	int count = nt_shape_getworldpoints(shape(1), out);
	for (int i = 0; i < count*2; i++) {
		pd->lua->pushFloat(out[i]);
	}
	return count*2;
}

/* A body's shapes, each a black polygon outlined in white, at scale: what platform_playdate.lua drew
 * from points in tables, which cost more to make on the Playdate than the drawing. */
static int body_draw(lua_State *L) {
	cpShape *shapes[16];
	int count = nt_body_getshapes(body(1), shapes, 16);
	double scale = number(2);
	for (int i = 0; i < count; i++) {
		double points[NT_MAXPOINTS*2];
		int n = nt_shape_getworldpoints(shapes[i], points), coords[NT_MAXPOINTS*2];
		for (int j = 0; j < n*2; j++) {
			coords[j] = (int)floor(points[j]*scale);
		}
		pd->graphics->fillPolygon(n, coords, kColorBlack, kPolygonFillNonZero);
		for (int j = 0; j < n; j++) {
			int k = (j + 1) % n;
			pd->graphics->drawLine(coords[j*2], coords[j*2+1], coords[k*2], coords[k*2+1], 1, kColorWhite);
		}
	}
	return 0;
}

static int shape_rowareas(lua_State *L) { /* first row, then the area in each */
	double areas[NT_MAXROWS];
	int first, count = nt_shape_rowareas(shape(1), number(2), &first, areas);
	pd->lua->pushInt(first);
	for (int i = 0; i < count; i++) {
		pd->lua->pushFloat(areas[i]);
	}
	return count + 1;
}

static const struct {
	const char *name;
	lua_CFunction f;
} functions[] = {
	{"nt.world_new", world_new},
	{"nt.world_setmaxrise", world_setmaxrise},
	{"nt.world_setiterations", world_setiterations},
	{"nt.world_step", world_step},
	{"nt.world_contactcount", world_contactcount},
	{"nt.world_contact", world_contact},
	{"nt.body_new", body_new},
	{"nt.body_free", body_free},
	{"nt.body_getposition", body_getposition},
	{"nt.body_setposition", body_setposition},
	{"nt.body_getangle", body_getangle},
	{"nt.body_setangle", body_setangle},
	{"nt.body_getvelocity", body_getvelocity},
	{"nt.body_setvelocity", body_setvelocity},
	{"nt.body_getangularvelocity", body_getangularvelocity},
	{"nt.body_setangularvelocity", body_setangularvelocity},
	{"nt.body_getworldcenter", body_getworldcenter},
	{"nt.body_applyforce", body_applyforce},
	{"nt.body_applytorque", body_applytorque},
	{"nt.body_setdamping", body_setdamping},
	{"nt.body_resetmass", body_resetmass},
	{"nt.body_getmass", body_getmass},
	{"nt.body_isawake", body_isawake},
	{"nt.body_wake", body_wake},
	{"nt.body_isstatic", body_isstatic},
	{"nt.body_setstatic", body_setstatic},
	{"nt.body_gettop", body_gettop},
	{"nt.body_setcollides", body_setcollides},
	{"nt.body_touching", body_touching},
	{"nt.body_tolocal", body_tolocal},
	{"nt.body_toworld", body_toworld},
	{"nt.shape_newpolygon", shape_newpolygon},
	{"nt.shape_free", shape_free},
	{"nt.shape_setfriction", shape_setfriction},
	{"nt.shape_setrestitution", shape_setrestitution},
	{"nt.shape_setdensity", shape_setdensity},
	{"nt.shape_setfilter", shape_setfilter},
	{"nt.shape_testpoint", shape_testpoint},
	{"nt.shape_raycast", shape_raycast},
	{"nt.shape_getworldpoints", shape_getworldpoints},
	{"nt.shape_rowareas", shape_rowareas},
	{"nt.body_draw", body_draw},
};

static void check(int ok, const char *what, const char *err) {
	if (!ok) {
		pd->system->error("registering %s: %s", what, err ? err : "failed");
	}
}

#ifdef _WINDLL
__declspec(dllexport)
#endif
int eventHandler(PlaydateAPI *playdate, PDSystemEvent event, uint32_t arg) {
	(void)arg;
	if (event == kEventInitLua) {
		const char *err = NULL;
		static const lua_reg worldmethods[] = {{"__gc", world_gc}, {NULL, NULL}};
		static const lua_reg bodymethods[] = {{"__gc", body_gc}, {NULL, NULL}};
		static const lua_reg shapemethods[] = {{"__gc", shape_gc}, {NULL, NULL}};
		pd = playdate;
		check(pd->lua->registerClass(WORLD, worldmethods, NULL, 0, &err), WORLD, err);
		check(pd->lua->registerClass(BODY, bodymethods, NULL, 0, &err), BODY, err);
		check(pd->lua->registerClass(SHAPE, shapemethods, NULL, 0, &err), SHAPE, err);
		for (unsigned i = 0; i < sizeof(functions)/sizeof(functions[0]); i++) {
			check(pd->lua->addFunction(functions[i].f, functions[i].name, &err), functions[i].name, err);
		}
	}
	return 0;
}
