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
};

typedef struct {
	cpFloat damping;
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

static void freeshape(cpShape *shape) {
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

cpBody *nt_body_new(ntWorld *world, double x, double y, int dynamic) {
	cpBody *body = dynamic ? cpBodyNew(0.0f, 0.0f) : cpBodyNewStatic(); /* mass comes from the shapes */
	cpBodySetUserData(body, calloc(1, sizeof(ntBody)));
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

void nt_body_setstatic(cpBody *body, int isstatic) {
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
}

static void top(cpBody *body, cpShape *shape, void *data) {
	cpFloat *y = data;
	for (int i = 0; i < cpPolyShapeGetCount(shape); i++) {
		cpFloat vy = cpBodyLocalToWorld(body, cpPolyShapeGetVert(shape, i)).y;
		*y = vy < *y ? vy : *y;
	}
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
static int clip(const double *in, int n, double line, int below, double *out) {
	int count = 0;
	for (int i = 0; i < n; i++) {
		const double *a = in + i*2, *b = in + ((i + 1) % n)*2;
		int ain = below ? a[1] >= line : a[1] <= line;
		int bin = below ? b[1] >= line : b[1] <= line;
		if (ain) {
			out[count*2] = a[0];
			out[count*2+1] = a[1];
			count++;
		}
		if (ain != bin) {
			double t = (line - a[1])/(b[1] - a[1]);
			out[count*2] = a[0] + t*(b[0] - a[0]);
			out[count*2+1] = line;
			count++;
		}
	}
	return count;
}

static double area(const double *p, int n) {
	double sum = 0;
	for (int i = 0; i < n; i++) {
		const double *a = p + i*2, *b = p + ((i + 1) % n)*2;
		sum += a[0]*b[1] - b[0]*a[1];
	}
	return sum < 0 ? -sum/2 : sum/2;
}

int nt_shape_rowareas(cpShape *shape, double rowheight, int *firstrow, double *areas) {
	double points[NT_MAXPOINTS*2], top[(NT_MAXPOINTS+2)*2], band[(NT_MAXPOINTS+4)*2];
	int n = nt_shape_getworldpoints(shape, points);
	double ymin = points[1], ymax = points[1];
	for (int i = 1; i < n; i++) {
		ymin = points[i*2+1] < ymin ? points[i*2+1] : ymin;
		ymax = points[i*2+1] > ymax ? points[i*2+1] : ymax;
	}
	int first = (int)floor(ymin/rowheight), last = (int)ceil(ymax/rowheight) - 1;
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

int nt_shape_getworldpoints(cpShape *shape, double *out) {
	cpBody *body = cpShapeGetBody(shape);
	int count = cpPolyShapeGetCount(shape);
	for (int i = 0; i < count; i++) {
		put(cpBodyLocalToWorld(body, cpPolyShapeGetVert(shape, i)), out + i*2);
	}
	return count;
}
