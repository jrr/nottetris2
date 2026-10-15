/* The game's physics on Chipmunk: see nt_physics.h. */
#include <stdlib.h>
#include <math.h>
#include "chipmunk/chipmunk_private.h"
#include "nt_physics.h"

struct ntWorld {
	cpSpace *space;
	cpFloat maxrise; /* fastest a body may move up; 0 for no limit */
	int *contacts; /* shape ids, two per pair */
	int ncontacts, capacity;
	ntSchedule schedule;
	cpFloat budget; /* the scheduler's changes earned but not yet made */
	int freezes; /* freezes made, numbering them */
};

typedef struct {
	cpFloat damping;
	int id;
	int kind; /* for drawing */
	/* the scheduler's bookkeeping */
	int frozen; /* 0, or the freeze's number */
	int seen, slow;
	cpFloat idle, awake; /* seconds idle, and simulated, since it was woken */
	cpFloat age; /* seconds frozen */
	cpFloat bump; /* knocks from moving pieces while frozen */
	cpFloat moved; /* how far it settled on its last turn */
	cpVect wakepos;
	cpFloat wakeangle;
	/* its area in each line, for nt_world_lineareas, while areasok and it's frozen as it was then
	 * (areasfrozen) or where it was then */
	int areasok, areasfrozen;
	cpVect areaspos;
	cpFloat areasangle;
	ntReal areas[NT_LINES];
} ntBody;

typedef struct {
	int id;
	cpFloat density;
} ntShape;

/* LÖVE measured Box2D's densities per meter of 30 pixels, so a piece's mass was its area
 * over 30*30. The game's forces and its minmass are made for those masses. */
#define METER 30.0f

static void setdensity(cpShape *shape, cpFloat density) {
	cpShapeSetDensity(shape, density/(METER*METER));
}

/* Chipmunk can't remove things while iterating over them, so these collect them first */
typedef struct {
	void **items;
	int count, capacity;
} list;

static void push(list *l, void *item) {
	if (l->count == l->capacity) {
		l->capacity = l->capacity ? l->capacity*2 : 16;
		l->items = realloc(l->items, l->capacity*sizeof(void *));
	}
	l->items[l->count++] = item;
}

static void collectshape(cpBody *body, cpShape *shape, void *l) { push(l, shape); }
static void collectspaceshape(cpShape *shape, void *l) { push(l, shape); }
static void collectbody(cpBody *body, void *l) { push(l, body); }

static void shapeschanged(cpBody *body) { /* its line areas are out of date */
	ntBody *b = cpBodyGetUserData(body);
	if (b) {
		b->areasok = 0;
	}
}

static void freeshape(cpShape *shape) {
	shapeschanged(cpShapeGetBody(shape));
	free(cpShapeGetUserData(shape));
	cpSpaceRemoveShape(cpShapeGetSpace(shape), shape);
	cpShapeFree(shape);
}

/* collisions */
static cpBool begin(cpArbiter *arb, cpSpace *space, cpDataPointer data) {
	ntWorld *world = data;
	CP_ARBITER_GET_SHAPES(arb, a, b);
	if (world->ncontacts + 2 > world->capacity) {
		world->capacity = world->capacity ? world->capacity*2 : 64;
		world->contacts = realloc(world->contacts, world->capacity*sizeof(int));
	}
	world->contacts[world->ncontacts++] = ((ntShape *)cpShapeGetUserData(a))->id;
	world->contacts[world->ncontacts++] = ((ntShape *)cpShapeGetUserData(b))->id;
	return cpTrue;
}

static cpBool presolve(cpArbiter *arb, cpSpace *space, cpDataPointer data) {
	CP_ARBITER_GET_SHAPES(arb, a, b);
	/* Box2D's mixing; Chipmunk multiplies both */
	cpArbiterSetFriction(arb, cpfsqrt(cpShapeGetFriction(a)*cpShapeGetFriction(b)));
	cpArbiterSetRestitution(arb, cpfmax(cpShapeGetElasticity(a), cpShapeGetElasticity(b)));
	return cpTrue;
}

/* the world */
ntWorld *nt_world_new(double gravityx, double gravityy) {
	ntWorld *world = calloc(1, sizeof(ntWorld));
	world->space = cpSpaceNew();
	cpSpaceSetGravity(world->space, cpv(gravityx, gravityy));
	cpSpaceSetIterations(world->space, 10);
	cpSpaceSetSleepTimeThreshold(world->space, 0.5f); /* Box2D's time to sleep */
	cpSpaceSetUserData(world->space, world);
	cpCollisionHandler *handler = cpSpaceAddDefaultCollisionHandler(world->space);
	handler->beginFunc = begin;
	handler->preSolveFunc = presolve;
	handler->userData = world;
	return world;
}

void nt_world_free(ntWorld *world) {
	list shapes = {0}, bodies = {0};
	cpSpaceEachShape(world->space, collectspaceshape, &shapes);
	for (int i = 0; i < shapes.count; i++) {
		freeshape(shapes.items[i]);
	}
	cpSpaceEachBody(world->space, collectbody, &bodies);
	for (int i = 0; i < bodies.count; i++) {
		cpBody *body = bodies.items[i];
		free(cpBodyGetUserData(body));
		cpSpaceRemoveBody(world->space, body);
		cpBodyFree(body);
	}
	free(shapes.items);
	free(bodies.items);
	cpSpaceFree(world->space);
	free(world->contacts);
	free(world);
}

void nt_world_setmaxrise(ntWorld *world, double speed) { world->maxrise = speed; }

typedef struct {
	cpBody **out;
	int count, max;
} bodylist;

static void listbody(cpBody *body, void *data) {
	bodylist *l = data;
	if (l->count < l->max) {
		l->out[l->count++] = body;
	}
}

int nt_world_getbodies(ntWorld *world, cpBody **out, int max) {
	bodylist l = {out, 0, max};
	cpSpaceEachBody(world->space, listbody, &l);
	return l.count;
}
void nt_world_setiterations(ntWorld *world, int iterations) { cpSpaceSetIterations(world->space, iterations); }

/* after the contacts have been solved, since they can throw a body up; bodies move by it in the next step */
static void limitrise(cpBody *body, void *data) {
	cpFloat maxrise = *(cpFloat *)data;
	if (cpBodyGetType(body) == CP_BODY_TYPE_DYNAMIC && body->v.y < -maxrise) {
		body->v.y = -maxrise;
	}
}

void nt_world_step(ntWorld *world, double dt) {
	world->ncontacts = 0;
	cpSpaceStep(world->space, dt);
	if (world->maxrise > 0.0f) {
		cpSpaceEachBody(world->space, limitrise, &world->maxrise);
	}
}

int nt_world_contacts(ntWorld *world, const int **pairs) {
	*pairs = world->contacts;
	return world->ncontacts/2;
}

/* bodies */

/* Chipmunk's integration, with Box2D's damping: of moving only, after the forces */
static void updatevelocity(cpBody *body, cpVect gravity, cpFloat damping, cpFloat dt) {
	cpBodyUpdateVelocity(body, gravity, 1.0f, dt);
	body->v = cpvmult(body->v, 1.0f/(1.0f + dt*((ntBody *)body->userData)->damping));
}

cpBody *nt_body_new(ntWorld *world, double x, double y, int dynamic, int id) {
	cpBody *body = dynamic ? cpBodyNew(0.0f, 0.0f) : cpBodyNewStatic(); /* mass comes from the shapes */
	ntBody *b = calloc(1, sizeof(ntBody));
	b->id = id;
	cpBodySetUserData(body, b);
	cpBodySetVelocityUpdateFunc(body, updatevelocity);
	cpBodySetPosition(body, cpv(x, y));
	cpSpaceAddBody(world->space, body);
	return body;
}

void nt_body_free(cpBody *body) {
	list shapes = {0};
	cpBodyEachShape(body, collectshape, &shapes);
	for (int i = 0; i < shapes.count; i++) {
		freeshape(shapes.items[i]);
	}
	free(shapes.items);
	free(cpBodyGetUserData(body));
	cpSpaceRemoveBody(cpBodyGetSpace(body), body);
	cpBodyFree(body);
}

static void put(cpVect v, double *out) {
	out[0] = v.x;
	out[1] = v.y;
}

void nt_body_getposition(cpBody *body, double *out) { put(cpBodyGetPosition(body), out); }
void nt_body_setposition(cpBody *body, double x, double y) { cpBodySetPosition(body, cpv(x, y)); }
double nt_body_getangle(cpBody *body) { return cpBodyGetAngle(body); }

void nt_body_setangle(cpBody *body, double angle) {
	cpVect origin = cpBodyGetPosition(body); /* Chipmunk turns bodies about their center of mass */
	cpBodySetAngle(body, angle);
	cpBodySetPosition(body, origin);
}

void nt_body_getvelocity(cpBody *body, double *out) { put(cpBodyGetVelocity(body), out); }
void nt_body_setvelocity(cpBody *body, double x, double y) { cpBodySetVelocity(body, cpv(x, y)); }
double nt_body_getangularvelocity(cpBody *body) { return cpBodyGetAngularVelocity(body); }
void nt_body_setangularvelocity(cpBody *body, double w) { cpBodySetAngularVelocity(body, w); }

void nt_body_getworldcenter(cpBody *body, double *out) {
	put(cpBodyLocalToWorld(body, cpBodyGetCenterOfGravity(body)), out);
}

void nt_body_applyforce(cpBody *body, double fx, double fy, double x, double y) {
	cpBodyApplyForceAtWorldPoint(body, cpv(fx, fy), cpv(x, y));
}

void nt_body_applytorque(cpBody *body, double torque) {
	cpBodySetTorque(body, cpBodyGetTorque(body) + torque);
}

void nt_body_setdamping(cpBody *body, double damping) {
	((ntBody *)cpBodyGetUserData(body))->damping = damping;
}

static void usedensity(cpBody *body, cpShape *shape, void *unused) {
	setdensity(shape, ((ntShape *)cpShapeGetUserData(shape))->density);
}

void nt_body_resetmass(cpBody *body) {
	if (cpBodyGetType(body) == CP_BODY_TYPE_DYNAMIC) {
		cpBodyEachShape(body, usedensity, NULL);
	}
}

double nt_body_getmass(cpBody *body) { return cpBodyGetMass(body); }
int nt_body_isawake(cpBody *body) { return !cpBodyIsSleeping(body); }
void nt_body_wake(cpBody *body) { cpBodyActivate(body); }
int nt_body_isstatic(cpBody *body) { return cpBodyGetType(body) == CP_BODY_TYPE_STATIC; }

static void firstseen(ntBody *b, cpBody *body) { /* where its first turn starts */
	if (!b->seen) {
		b->seen = 1;
		b->wakepos = cpBodyGetPosition(body);
		b->wakeangle = cpBodyGetAngle(body);
	}
}

int nt_body_setstatic(cpBody *body, int isstatic) {
	ntBody *b = cpBodyGetUserData(body);
	ntWorld *world = cpSpaceGetUserData(cpBodyGetSpace(body));
	firstseen(b, body);
	/* Wake it first, or what's asleep against it: cpBodySetType wakes neither. A sleeping body's
	 * shapes aren't where cpBodySetType moves them from (a crash in cpBBTree), and a static body
	 * keeps the contacts of what sleeps on it, which, once it's dynamic, tangle the contact graph
	 * (a hang). */
	if (cpBodyGetType(body) == CP_BODY_TYPE_STATIC) {
		cpBodyActivateStatic(body, NULL);
	} else {
		cpBodyActivate(body);
	}
	cpBodySetType(body, isstatic ? CP_BODY_TYPE_STATIC : CP_BODY_TYPE_DYNAMIC);
	if (isstatic) {
		cpSpaceReindexShapesForBody(cpBodyGetSpace(body), body); /* where it is now, if it was moved since the last step */
		/* how far it settled on its turn; turning counts at a block's half-width */
		b->moved = cpvdist(cpBodyGetPosition(body), b->wakepos) + cpfabs(cpBodyGetAngle(body) - b->wakeangle)*16.0f;
		b->age = 0.0f;
		b->frozen = ++world->freezes;
	} else {
		b->frozen = 0;
		b->idle = b->awake = b->bump = 0.0f;
		b->wakepos = cpBodyGetPosition(body);
		b->wakeangle = cpBodyGetAngle(body);
	}
	return b->frozen;
}

static int inpile(cpBody *body, cpBody *falling) { /* the pile: dynamic, or frozen by the scheduler */
	ntBody *b = cpBodyGetUserData(body);
	return body != falling && b && (cpBodyGetType(body) == CP_BODY_TYPE_DYNAMIC || b->frozen);
}

/* the line areas */
void nt_world_lineareas(ntWorld *world, cpBody *falling, ntReal rowheight, ntReal *out) {
	for (int line = 0; line < NT_LINES; line++) {
		out[line] = 0;
	}
	list all = {0};
	cpSpaceEachBody(world->space, collectbody, &all);
	for (int i = 0; i < all.count; i++) {
		cpBody *body = all.items[i];
		if (!inpile(body, falling)) {
			continue;
		}
		ntBody *b = cpBodyGetUserData(body);
		cpVect pos = cpBodyGetPosition(body);
		cpFloat angle = cpBodyGetAngle(body);
		int same = b->areasok && (b->frozen ? b->frozen == b->areasfrozen : cpveql(pos, b->areaspos) && angle == b->areasangle);
		if (!same) {
			for (int line = 0; line < NT_LINES; line++) {
				b->areas[line] = 0;
			}
			CP_BODY_FOREACH_SHAPE(body, shape) {
				ntReal areas[NT_MAXROWS];
				int first, count = nt_shape_rowareas(shape, rowheight, &first, areas);
				for (int k = 0; k < count; k++) {
					if (first + k >= 0 && first + k < NT_LINES) {
						b->areas[first + k] += areas[k];
					}
				}
			}
			b->areasok = 1;
			b->areasfrozen = b->frozen;
			b->areaspos = pos;
			b->areasangle = angle;
		}
		for (int line = 0; line < NT_LINES; line++) {
			out[line] += b->areas[line];
		}
	}
	free(all.items);
}

/* the scheduler */
void nt_world_setschedule(ntWorld *world, const ntSchedule *schedule) { world->schedule = *schedule; }

static cpFloat bodytop(cpBody *body) { /* the smallest y of its shapes, from their bounding boxes */
	cpFloat top = INFINITY;
	CP_BODY_FOREACH_SHAPE(body, shape) {
		top = cpfmin(top, shape->bb.b);
	}
	return top;
}

static void bumpfrozen(cpBody *body, cpArbiter *arb, void *knock) { /* what it's touching that's frozen */
	CP_ARBITER_GET_BODIES(arb, mine, other);
	(void)mine;
	ntBody *o = cpBodyGetUserData(other);
	if (cpArbiterGetCount(arb) > 0 && o && o->frozen) {
		o->bump += *(cpFloat *)knock;
	}
}

static void bumpfrom(cpBody *body, cpFloat speed, const ntSchedule *s) {
	cpFloat knock = speed/s->bumpSpeed;
	cpBodyEachArbiter(body, bumpfrozen, &knock);
}

int nt_world_schedule(ntWorld *world, cpBody *falling, ntReal dt, int *frozen) {
	const ntSchedule *s = &world->schedule;
	*frozen = 0;
	list all = {0};
	cpSpaceEachBody(world->space, collectbody, &all);
	/* the pile, and its top */
	int n = 0;
	cpBody **pile = malloc((all.count + 1)*sizeof(cpBody *));
	cpFloat *tops = malloc((all.count + 1)*sizeof(cpFloat));
	cpFloat piletop = INFINITY;
	for (int i = 0; i < all.count; i++) {
		cpBody *body = all.items[i];
		ntBody *b = cpBodyGetUserData(body);
		if (!inpile(body, falling)) {
			continue; /* the falling piece, the walls */
		}
		firstseen(b, body);
		pile[n] = body;
		tops[n] = bodytop(body);
		piletop = cpfmin(piletop, tops[n]);
		n++;
	}
	free(all.items);
	cpFloat livey = piletop + s->liveRows*32.0f;

	/* bookkeeping, and bumps from anything moving (the falling piece included) */
	if (falling) {
		bumpfrom(falling, cpvlength(cpBodyGetVelocity(falling)), s);
	}
	for (int i = 0; i < n; i++) {
		ntBody *b = cpBodyGetUserData(pile[i]);
		if (b->frozen) {
			b->age += dt;
			continue;
		}
		cpFloat speed = cpvlength(cpBodyGetVelocity(pile[i]));
		b->awake += dt;
		b->slow = speed < s->idleSpeed && cpfabs(cpBodyGetAngularVelocity(pile[i])) < 0.05f;
		b->idle = b->slow ? b->idle + dt : 0.0f;
		if (speed > s->bumpSpeed) {
			bumpfrom(pile[i], speed, s);
		}
	}

	/* changes come at changesPerSecond, at most one a step (the budget doesn't build up beyond that) */
	int changed = 0;
	world->budget = cpfmin(world->budget + dt*s->changesPerSecond, 1.0f);
	if (world->budget >= 1.0f) {
		/* a frozen piece in the live rows first, then a deep one if there's room, otherwise freeze
		 * the deep piece that's been idle longest */
		cpBody *best = NULL, *idlest = NULL;
		cpFloat bestscore = -INFINITY;
		int deepawake = 0;
		for (int i = 0; i < n; i++) {
			ntBody *b = cpBodyGetUserData(pile[i]);
			int live = tops[i] < livey;
			if (b->frozen) {
				cpFloat score = live ? INFINITY
					: b->age*s->ageWeight + b->bump*s->bumpWeight + b->moved*s->movedWeight - (tops[i] - livey)/32.0f*s->depthWeight;
				if (score > bestscore) {
					best = pile[i];
					bestscore = score;
				}
			} else if (!live) {
				deepawake++;
				int done = b->idle >= s->idleTime || (b->slow && b->awake >= s->maxTurn);
				if (done) {
					ntBody *d = idlest ? cpBodyGetUserData(idlest) : NULL;
					if (!d || b->idle + b->awake > d->idle + d->awake) {
						idlest = pile[i];
					}
				}
			}
		}
		if (best && (bestscore == INFINITY || deepawake < s->maxAwake)) {
			nt_body_setstatic(best, 0);
			changed = ((ntBody *)cpBodyGetUserData(best))->id;
			world->budget -= 1.0f;
		} else if (idlest && deepawake >= s->maxAwake) {
			*frozen = nt_body_setstatic(idlest, 1);
			changed = ((ntBody *)cpBodyGetUserData(idlest))->id;
			world->budget -= 1.0f;
		}
	}
	free(pile);
	free(tops);
	return changed;
}

static void top(cpBody *body, cpShape *shape, void *data) {
	cpFloat *y = data;
	for (int i = 0; i < cpPolyShapeGetCount(shape); i++) {
		cpFloat vy = cpBodyLocalToWorld(body, cpPolyShapeGetVert(shape, i)).y;
		*y = vy < *y ? vy : *y;
	}
}

static void setfilter(cpBody *body, cpShape *shape, void *filter) { cpShapeSetFilter(shape, *(cpShapeFilter *)filter); }

void nt_body_setcollides(cpBody *body, int collides) {
	cpShapeFilter filter = collides ? CP_SHAPE_FILTER_ALL : CP_SHAPE_FILTER_NONE;
	cpBodyEachShape(body, setfilter, &filter);
}

double nt_body_gettop(cpBody *body) {
	cpFloat y = INFINITY;
	cpBodyEachShape(body, top, &y);
	return y;
}

typedef struct {
	int *ids, count, max;
} touching;

static void touchingshape(cpBody *body, cpArbiter *arb, void *data) {
	touching *t = data;
	CP_ARBITER_GET_SHAPES(arb, mine, other); /* each arbiter's first shape is the body's own */
	(void)mine;
	if (cpArbiterGetCount(arb) > 0 && t->count < t->max) {
		t->ids[t->count++] = ((ntShape *)cpShapeGetUserData(other))->id;
	}
}

typedef struct {
	cpShape **out;
	int count, max;
} shapelist;

static void listshape(cpBody *body, cpShape *shape, void *data) {
	shapelist *l = data;
	if (l->count < l->max) {
		l->out[l->count++] = shape;
	}
}

int nt_body_getshapes(cpBody *body, cpShape **out, int max) {
	shapelist l = {out, 0, max};
	cpBodyEachShape(body, listshape, &l);
	return l.count;
}

int nt_body_getid(cpBody *body) { return ((ntBody *)cpBodyGetUserData(body))->id; }
void nt_body_setkind(cpBody *body, int kind) { ((ntBody *)cpBodyGetUserData(body))->kind = kind; }
int nt_body_getkind(cpBody *body) { return ((ntBody *)cpBodyGetUserData(body))->kind; }

int nt_body_touching(cpBody *body, int *ids, int max) {
	touching t = {ids, 0, max};
	cpBodyEachArbiter(body, touchingshape, &t);
	return t.count;
}
void nt_body_tolocal(cpBody *body, double x, double y, double *out) { put(cpBodyWorldToLocal(body, cpv(x, y)), out); }
void nt_body_toworld(cpBody *body, double x, double y, double *out) { put(cpBodyLocalToWorld(body, cpv(x, y)), out); }

/* shapes */
cpShape *nt_shape_newpolygon(cpBody *body, int count, const double *points, int id) {
	cpVect verts[NT_MAXPOINTS];
	if (count > NT_MAXPOINTS) {
		count = NT_MAXPOINTS;
	}
	for (int i = 0; i < count; i++) {
		verts[i] = cpv(points[i*2], points[i*2+1]);
	}
	cpShape *shape = cpPolyShapeNew(body, count, verts, cpTransformIdentity, 0.0f);
	shapeschanged(body);
	ntShape *data = calloc(1, sizeof(ntShape));
	data->id = id;
	data->density = 1.0f;
	cpShapeSetUserData(shape, data);
	cpShapeSetFilter(shape, cpShapeFilterNew(CP_NO_GROUP, 1, CP_ALL_CATEGORIES));
	cpSpaceAddShape(cpBodyGetSpace(body), shape);
	if (cpBodyGetType(body) == CP_BODY_TYPE_DYNAMIC) {
		setdensity(shape, data->density);
	}
	return shape;
}

void nt_shape_free(cpShape *shape) { freeshape(shape); }
void nt_shape_setfriction(cpShape *shape, double friction) { cpShapeSetFriction(shape, friction); }
void nt_shape_setrestitution(cpShape *shape, double restitution) { cpShapeSetElasticity(shape, restitution); }
void nt_shape_setdensity(cpShape *shape, double density) { ((ntShape *)cpShapeGetUserData(shape))->density = density; }

void nt_shape_setfilter(cpShape *shape, unsigned categories, unsigned mask) {
	cpShapeSetFilter(shape, cpShapeFilterNew(CP_NO_GROUP, categories, mask));
}

/* Queries go by where the shape was at the last step, so move it to where its body is now first:
 * the game asks about bodies it has just made or moved. */
static void update(cpShape *shape) {
	cpShapeUpdate(shape, cpShapeGetBody(shape)->transform);
}

int nt_shape_testpoint(cpShape *shape, double x, double y) {
	update(shape);
	return cpShapePointQuery(shape, cpv(x, y), NULL) <= 0.0f;
}

double nt_shape_raycast(cpShape *shape, double x1, double y1, double x2, double y2) {
	cpSegmentQueryInfo info;
	update(shape);
	if (cpShapeSegmentQuery(shape, cpv(x1, y1), cpv(x2, y2), 0.0f, &info)) {
		return info.alpha;
	}
	return -1;
}

/* the part of a polygon on one side of a horizontal line: y >= line if below, else y <= line */
static int clip(const ntReal *in, int n, ntReal line, int below, ntReal *out) {
	int count = 0;
	for (int i = 0; i < n; i++) {
		const ntReal *a = in + i*2, *b = in + ((i + 1) % n)*2;
		int ain = below ? a[1] >= line : a[1] <= line;
		int bin = below ? b[1] >= line : b[1] <= line;
		if (ain) {
			out[count*2] = a[0];
			out[count*2+1] = a[1];
			count++;
		}
		if (ain != bin) {
			ntReal t = (line - a[1])/(b[1] - a[1]);
			out[count*2] = a[0] + t*(b[0] - a[0]);
			out[count*2+1] = line;
			count++;
		}
	}
	return count;
}

static ntReal area(const ntReal *p, int n) {
	ntReal sum = 0;
	for (int i = 0; i < n; i++) {
		const ntReal *a = p + i*2, *b = p + ((i + 1) % n)*2;
		sum += a[0]*b[1] - b[0]*a[1];
	}
	return sum < 0 ? -sum/2 : sum/2;
}

int nt_shape_rowareas(cpShape *shape, ntReal rowheight, int *firstrow, ntReal *areas) {
	ntReal points[NT_MAXPOINTS*2], top[(NT_MAXPOINTS+2)*2], band[(NT_MAXPOINTS+4)*2];
	int n = nt_shape_getworldpoints(shape, points);
	ntReal ymin = points[1], ymax = points[1];
	for (int i = 1; i < n; i++) {
		ymin = points[i*2+1] < ymin ? points[i*2+1] : ymin;
		ymax = points[i*2+1] > ymax ? points[i*2+1] : ymax;
	}
	int first = (int)NT_FLOOR(ymin/rowheight), last = (int)NT_CEIL(ymax/rowheight) - 1;
	if (last < first) {
		last = first;
	}
	if (last - first + 1 > NT_MAXROWS) {
		last = first + NT_MAXROWS - 1;
	}
	for (int row = first; row <= last; row++) {
		int m = clip(points, n, row*rowheight, 1, top);
		m = clip(top, m, (row + 1)*rowheight, 0, band);
		areas[row - first] = m >= 3 ? area(band, m) : 0;
	}
	*firstrow = first;
	return last - first + 1;
}

int nt_shape_getscreenpoints(cpShape *shape, ntReal scale, int *out) {
	cpBody *body = cpShapeGetBody(shape);
	cpVect origin = cpBodyGetPosition(body);
	int ox = (int)NT_FLOOR(origin.x*scale), oy = (int)NT_FLOOR(origin.y*scale);
	int count = cpPolyShapeGetCount(shape);
	for (int i = 0; i < count; i++) {
		cpVect v = cpvsub(cpBodyLocalToWorld(body, cpPolyShapeGetVert(shape, i)), origin);
		out[i*2] = ox + (int)NT_FLOOR(v.x*scale + 0.5f);
		out[i*2+1] = oy + (int)NT_FLOOR(v.y*scale + 0.5f);
	}
	return count;
}

int nt_shape_getworldpoints(cpShape *shape, ntReal *out) {
	cpBody *body = cpShapeGetBody(shape);
	int count = cpPolyShapeGetCount(shape);
	for (int i = 0; i < count; i++) {
		cpVect v = cpBodyLocalToWorld(body, cpPolyShapeGetVert(shape, i));
		out[i*2] = v.x;
		out[i*2+1] = v.y;
	}
	return count;
}
