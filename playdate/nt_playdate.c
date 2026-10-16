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
#include <stdint.h>
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
static int world_setschedule(lua_State *L) { /* the numbers in ntSchedule, in order */
	ntSchedule s = {number(2), number(3), number(4), number(5), number(6), number(7), number(8),
		number(9), number(10), number(11), number(12)};
	nt_world_setschedule(world(1), &s);
	return 0;
}

static int world_schedule(lua_State *L) { /* the id of the body changed (or 0), and its freeze's number (or 0) */
	cpBody *falling = pd->lua->getArgType(2, NULL) == kTypeNil ? NULL : body(2);
	int frozen, id = nt_world_schedule(world(1), falling, number(3), &frozen);
	pd->lua->pushInt(id);
	pd->lua->pushInt(frozen);
	return 2;
}

static int world_lineareas(lua_State *L) { /* the pile's area in each line */
	cpBody *falling = pd->lua->getArgType(2, NULL) == kTypeNil ? NULL : body(2);
	ntReal areas[NT_LINES];
	nt_world_lineareas(world(1), falling, number(3), areas);
	for (int line = 0; line < NT_LINES; line++) {
		pd->lua->pushFloat(areas[line]);
	}
	return NT_LINES;
}

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
	push(nt_body_new(world(1), number(2), number(3), pd->lua->getArgBool(4), pd->lua->getArgInt(5)), BODY);
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
static int body_setstatic(lua_State *L) { pd->lua->pushInt(nt_body_setstatic(body(1), pd->lua->getArgBool(2))); return 1; }
static int body_gettop(lua_State *L) { pd->lua->pushFloat(nt_body_gettop(body(1))); return 1; }

static int body_getbounds(lua_State *L) { /* top, bottom */
	ntReal out[2];
	nt_body_getbounds(body(1), out);
	pd->lua->pushFloat(out[0]);
	pd->lua->pushFloat(out[1]);
	return 2;
}
static int body_setcollides(lua_State *L) { nt_body_setcollides(body(1), pd->lua->getArgBool(2)); return 0; }
static int body_setkind(lua_State *L) { nt_body_setkind(body(1), pd->lua->getArgInt(2)); return 0; }

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
	ntReal out[NT_MAXPOINTS*2];
	int count = nt_shape_getworldpoints(shape(1), out);
	for (int i = 0; i < count*2; i++) {
		pd->lua->pushFloat(out[i]);
	}
	return count*2;
}

/* each kind of piece's pattern, as platform_playdate.lua gives it: 8 rows, bits set for white, and
 * whether it's fixed to the screen rather than starting at each block's corner */
#define NT_KINDS 8 /* kinds of piece, 1-7 */
static uint8_t patterns[NT_KINDS][8];
static int fixed[NT_KINDS];

static int setpattern(lua_State *L) { /* kind, fixed, then the 8 rows */
	int kind = pd->lua->getArgInt(1);
	if (kind >= 0 && kind < NT_KINDS) {
		fixed[kind] = pd->lua->getArgBool(2);
		for (int r = 0; r < 8; r++) {
			patterns[kind][r] = pd->lua->getArgInt(3 + r);
		}
	}
	return 0;
}

static int shape_screenpoints(lua_State *L) { /* x1, y1, x2, y2, ...: nt_shape_getscreenpoints */
	int out[NT_MAXPOINTS*2];
	int count = nt_shape_getscreenpoints(shape(1), number(2), out);
	for (int i = 0; i < count*2; i++) {
		pd->lua->pushInt(out[i]);
	}
	return count*2;
}

/* A polygon (points in whole pixels) filled with a kind's pattern and outlined in black, as
 * platform_playdate.lua's drawpolygons does. The pattern starts at its first point, so that every
 * block of a piece looks the same and the pattern moves with it, unless it's fixed to the screen.
 * Patterns line up with the corner of what's drawn into: gridx, gridy is where that is on the
 * screen, and the points are drawn offsetx, offsety from it (the draw offset, which the C API
 * doesn't tell). */
static void drawpolygon(int *coords, int n, int kind, int offsetx, int offsety, int gridx, int gridy) {
	if (n < 3) {
		return; /* not a polygon: nothing to draw */
	}
	int known = kind >= 0 && kind < NT_KINDS;
	int dx = -gridx, dy = -gridy; /* the screen's corner, in the grid */
	if (known && !fixed[kind]) {
		dx = coords[0] + offsetx - gridx;
		dy = coords[1] + offsety - gridy;
	}
	dx &= 7;
	dy &= 7;
	LCDPattern pattern;
	for (int r = 0; r < 8; r++) {
		uint8_t row = known ? patterns[kind][(r - dy) & 7] : 0;
		pattern[r] = (uint8_t)((row >> dx) | (row << (8 - dx))); /* moved right dx */
		pattern[8 + r] = 0xFF; /* opaque */
	}
	pd->graphics->fillPolygon(n, coords, (LCDColor)pattern, kPolygonFillNonZero);
	for (int j = 0; j < n; j++) {
		int k = (j + 1) % n;
		pd->graphics->drawLine(coords[j*2], coords[j*2+1], coords[k*2], coords[k*2+1], 1, kColorBlack);
	}
}

/* The pieces, each frame, in one call from Lua: platform_playdate.lua's platform.drawpieces.
 * Pieces that have stopped moving are the pile, kept drawn in an image the size of the field
 * rather than drawn each frame. A piece joins it once it's been still a few frames, and leaves it
 * once it's visibly moved from where it was drawn into it, or is gone; what it covered is then
 * redrawn from the pieces still there. Pieces are the world's bodies with a kind (nt_body_setkind),
 * known here by their ids, as a new body can have the memory of one just freed. Points are
 * nt_shape_getscreenpoints, so that a piece keeps its shape as it moves. */
#define JOINFRAMES 3 /* frames still, for joining */
#define STILL 0.1f /* screen pixels a frame, for joining */
#define MOVED 0.5f /* screen pixels from where it joined, for leaving */
#define MAXSHAPES 16 /* a piece's, drawn */
#define MAXBODIES 512

typedef struct {
	int id, kind;
	cpBody *body; /* this frame's, or NULL once it's gone */
	int fresh; /* first seen this frame */
	int still; /* frames it's been still */
	int inpile;
	ntReal last[3], joined[3]; /* x, y, angle: last frame, and when it joined the pile */
	int x1, y1, x2, y2; /* what it covers in the pile's image */
	int shapes, counts[MAXSHAPES];
	int coords[MAXSHAPES][NT_MAXPOINTS*2];
} pilepiece;

static struct {
	LCDBitmap *image;
	pilepiece *pieces;
	int count, capacity;
} pile;

static ntReal distance(const ntReal *a, const ntReal *b, ntReal scale) { /* in screen pixels; turning counts at a block's half-width */
	return (fabsf(a[0] - b[0]) + fabsf(a[1] - b[1]) + fabsf(a[2] - b[2])*16)*scale;
}

static void drawpiece(pilepiece *p, int offsetx, int offsety, int gridx, int gridy) {
	for (int i = 0; i < p->shapes; i++) {
		drawpolygon(p->coords[i], p->counts[i], p->kind, offsetx, offsety, gridx, gridy);
	}
}

static void getshapes(pilepiece *p, ntReal scale) { /* where its shapes are on the screen now */
	cpShape *shapes[MAXSHAPES];
	p->shapes = nt_body_getshapes(p->body, shapes, MAXSHAPES);
	for (int i = 0; i < p->shapes; i++) {
		p->counts[i] = nt_shape_getscreenpoints(shapes[i], scale, p->coords[i]);
	}
}

static void unpile(pilepiece *p, int offsetx, int offsety) { /* out of the pile: redraw the area it covered */
	p->inpile = 0;
	int x = p->x1, y = p->y1, width = p->x2 - p->x1, height = p->y2 - p->y1;
	pd->graphics->pushContext(pile.image);
	pd->graphics->setClipRect(x, y, width, height);
	pd->graphics->fillRect(x, y, width, height, kColorClear);
	for (int i = 0; i < pile.count; i++) {
		pilepiece *q = &pile.pieces[i];
		if (q->inpile && q->x1 < p->x2 && q->x2 > p->x1 && q->y1 < p->y2 && q->y2 > p->y1) {
			drawpiece(q, offsetx, offsety, offsetx, offsety);
		}
	}
	pd->graphics->clearClipRect();
	pd->graphics->popContext();
}

static void joinpile(pilepiece *p, int offsetx, int offsety) { /* into the pile's image */
	p->inpile = 1;
	p->x1 = p->y1 = INT32_MAX;
	p->x2 = p->y2 = INT32_MIN;
	for (int i = 0; i < p->shapes; i++) {
		for (int j = 0; j < p->counts[i]; j++) {
			int x = p->coords[i][j*2], y = p->coords[i][j*2+1];
			p->x1 = x < p->x1 ? x : p->x1;
			p->x2 = x > p->x2 ? x : p->x2;
			p->y1 = y < p->y1 ? y : p->y1;
			p->y2 = y > p->y2 ? y : p->y2;
		}
	}
	p->x1 -= 1;
	p->y1 -= 1;
	p->x2 += 1;
	p->y2 += 1;
	pd->graphics->pushContext(pile.image);
	drawpiece(p, offsetx, offsety, offsetx, offsety);
	pd->graphics->popContext();
}

static pilepiece *findpiece(int id) {
	for (int i = 0; i < pile.count; i++) {
		if (pile.pieces[i].id == id) {
			return &pile.pieces[i];
		}
	}
	return NULL;
}

/* world, the falling piece (which never joins the pile) or nil, scale, the draw offset, the pile's
 * image's size, and whether it's a new game. Returns how many pieces joined the pile and how many
 * left it. */
static int pile_draw(lua_State *L) {
	ntWorld *w = world(1);
	cpBody *falling = pd->lua->getArgType(2, NULL) == kTypeNil ? NULL : body(2);
	ntReal scale = number(3);
	int offsetx = pd->lua->getArgInt(4), offsety = pd->lua->getArgInt(5);
	int joined = 0, left = 0;
	if (pile.image == NULL) {
		pile.image = pd->graphics->newBitmap(pd->lua->getArgInt(6), pd->lua->getArgInt(7), kColorClear);
	}
	if (pd->lua->getArgBool(8)) {
		pile.count = 0;
		pd->graphics->clearBitmap(pile.image, kColorClear);
	}
	/* what's there now */
	for (int i = 0; i < pile.count; i++) {
		pile.pieces[i].body = NULL;
	}
	static cpBody *bodies[MAXBODIES];
	int count = nt_world_getbodies(w, bodies, MAXBODIES);
	for (int i = 0; i < count; i++) {
		int kind = nt_body_getkind(bodies[i]);
		if (kind == 0) {
			continue;
		}
		int id = nt_body_getid(bodies[i]);
		pilepiece *p = findpiece(id);
		if (p == NULL) {
			if (pile.count == pile.capacity) {
				pile.capacity = pile.capacity ? pile.capacity*2 : 64;
				pile.pieces = pd->system->realloc(pile.pieces, pile.capacity*sizeof(pilepiece));
			}
			p = &pile.pieces[pile.count++];
			p->id = id;
			p->fresh = 1;
			p->still = 0;
			p->inpile = 0;
		}
		p->kind = kind;
		p->body = bodies[i];
	}
	/* first what leaves the pile, so it's patched before it's drawn */
	for (int i = 0; i < pile.count; i++) {
		pilepiece *p = &pile.pieces[i];
		if (p->body && p->inpile) {
			double pos[2];
			nt_body_getposition(p->body, pos);
			ntReal now[3] = {pos[0], pos[1], nt_body_getangle(p->body)};
			if (distance(p->joined, now, scale) > MOVED) {
				unpile(p, offsetx, offsety);
				left++;
			}
		}
	}
	for (int i = 0; i < pile.count; i++) {
		if (pile.pieces[i].body == NULL) {
			if (pile.pieces[i].inpile) {
				unpile(&pile.pieces[i], offsetx, offsety);
				left++;
			}
			pile.pieces[i--] = pile.pieces[--pile.count];
		}
	}
	pd->graphics->drawBitmap(pile.image, 0, 0, kBitmapUnflipped);
	/* then what's moving, and what's joining the pile */
	for (int i = 0; i < pile.count; i++) {
		pilepiece *p = &pile.pieces[i];
		if (p->inpile) {
			continue;
		}
		double pos[2];
		nt_body_getposition(p->body, pos);
		ntReal now[3] = {pos[0], pos[1], nt_body_getangle(p->body)};
		if (!p->fresh && p->body != falling && distance(p->last, now, scale) < STILL) {
			p->still++;
		} else {
			p->still = 0;
		}
		p->fresh = 0;
		for (int k = 0; k < 3; k++) {
			p->last[k] = now[k];
		}
		getshapes(p, scale);
		if (p->still >= JOINFRAMES) {
			for (int k = 0; k < 3; k++) {
				p->joined[k] = now[k];
			}
			joinpile(p, offsetx, offsety);
			joined++;
		}
		drawpiece(p, offsetx, offsety, 0, 0);
	}
	pd->lua->pushInt(joined);
	pd->lua->pushInt(left);
	return 2;
}

static int shape_rowareas(lua_State *L) { /* first row, then the area in each */
	ntReal areas[NT_MAXROWS];
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
	{"nt.world_setschedule", world_setschedule},
	{"nt.world_schedule", world_schedule},
	{"nt.world_lineareas", world_lineareas},
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
	{"nt.body_getbounds", body_getbounds},
	{"nt.body_setcollides", body_setcollides},
	{"nt.body_setkind", body_setkind},
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
	{"nt.pile_draw", pile_draw},
	{"nt.setpattern", setpattern},
	{"nt.shape_screenpoints", shape_screenpoints},
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
