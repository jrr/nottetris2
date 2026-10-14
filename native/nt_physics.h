/* The game's physics in C, on Chipmunk: plain functions of numbers and
 * handles, so LÖVE can call them through LuaJIT's FFI (nt_physics_love.lua)
 * and Playdate through its Lua API. physics_chipmunk.lua makes the game's
 * bodies and shapes from them.
 *
 * Units are pixels, seconds and radians, with y pointing down. Where Box2D
 * and Chipmunk differ, this does what Box2D did, since the game was made on it:
 * linear damping per body, densities that only count from the next
 * nt_body_resetmass, Box2D's mixing of friction and restitution, and
 * collisions reported after the step. */
#ifndef NT_PHYSICS_H
#define NT_PHYSICS_H

#define NT_MAXPOINTS 8 /* points in a polygon */
#define NT_MAXROWS 8 /* rows a shape can reach across, for nt_shape_rowareas */
#define NT_LINES 18 /* the field's lines, for nt_world_lineareas */

/* The type of the game's own arithmetic here (row areas, line areas, the scheduler): double, which
 * LÖVE's baselines were made with, or float where NT_FLOAT is defined: the Playdate, whose processor
 * does only floats, and doubles in software. */
#ifdef NT_FLOAT
typedef float ntReal;
#define NT_FLOOR floorf
#define NT_CEIL ceilf
#else
typedef double ntReal;
#define NT_FLOOR floor
#define NT_CEIL ceil
#endif

typedef struct ntWorld ntWorld;
typedef struct cpBody cpBody;
typedef struct cpShape cpShape;

ntWorld *nt_world_new(double gravityx, double gravityy);
void nt_world_free(ntWorld *world); /* and every body and shape in it */
/* the fastest a body may move up (against y), from then on; 0, the default, for no limit */
void nt_world_setmaxrise(ntWorld *world, double speed);
void nt_world_setiterations(ntWorld *world, int iterations); /* the solver's passes a step: more is stiffer and slower */
void nt_world_step(ntWorld *world, double dt);

/* The scheduler (scheduler.lua): simulates only part of the pile, freezing (making static) pieces
 * that have settled deep in it and letting them take turns being simulated again. The pile is every
 * body that's dynamic or that it froze, but the falling piece. Settings, as scheduler.lua has them: */
typedef struct {
	ntReal liveRows; /* pieces reaching within this many rows (of 32) of the top of the pile are never frozen */
	ntReal maxAwake; /* deep pieces simulated at once, unless more are still moving */
	ntReal changesPerSecond; /* switches between static and dynamic, at most one a step */
	ntReal idleSpeed; /* a piece slower than this, hardly turning, is idle */
	ntReal idleTime; /* seconds a deep piece must be idle before it can be frozen... */
	ntReal maxTurn; /* ...or seconds it's been awake, if it's slow right now */
	ntReal bumpSpeed; /* a piece this fast bumps the frozen pieces it touches */
	ntReal ageWeight, bumpWeight, movedWeight, depthWeight; /* a frozen piece's claim to be woken next */
} ntSchedule;
void nt_world_setschedule(ntWorld *world, const ntSchedule *schedule);
/* After a step: the scheduler's bookkeeping, and at most one change. Returns the id of the body it
 * froze or woke, or 0; *frozen says which (its freeze's number, or 0). falling may be NULL. */
int nt_world_schedule(ntWorld *world, cpBody *falling, ntReal dt, int *frozen);
/* The pile's area in each of the field's lines (rows of rowheight from y 0), into out[NT_LINES]: what
 * gameA.lua's checklinedensity adds up from nt_shape_rowareas, kept for each body while it's frozen
 * or hasn't moved. The pile as for nt_world_schedule. */
void nt_world_lineareas(ntWorld *world, cpBody *falling, ntReal rowheight, ntReal *out);
/* the shapes that began touching in the last step, as pairs of their ids:
 * returns how many pairs, and points *pairs at them until the next step */
int nt_world_contacts(ntWorld *world, const int **pairs);

cpBody *nt_body_new(ntWorld *world, double x, double y, int dynamic, int id); /* id: the game's, for nt_world_schedule */
void nt_body_free(cpBody *body); /* and its shapes */
void nt_body_getposition(cpBody *body, double *out); /* the body's origin: out[0], out[1] */
void nt_body_setposition(cpBody *body, double x, double y);
double nt_body_getangle(cpBody *body);
void nt_body_setangle(cpBody *body, double angle); /* turning about the origin */
void nt_body_getvelocity(cpBody *body, double *out);
void nt_body_setvelocity(cpBody *body, double x, double y);
double nt_body_getangularvelocity(cpBody *body);
void nt_body_setangularvelocity(cpBody *body, double w);
void nt_body_getworldcenter(cpBody *body, double *out); /* center of mass */
void nt_body_applyforce(cpBody *body, double fx, double fy, double x, double y); /* for the next step, at x, y */
void nt_body_applytorque(cpBody *body, double torque);
void nt_body_setdamping(cpBody *body, double damping);
void nt_body_resetmass(cpBody *body); /* from its shapes' densities */
double nt_body_getmass(cpBody *body);
int nt_body_isawake(cpBody *body); /* not asleep: Chipmunk puts bodies that have been still a while to sleep */
void nt_body_wake(cpBody *body);
int nt_body_isstatic(cpBody *body);
/* static: doesn't move, and stops; dynamic again: mass from its shapes. Returns the freeze's number
 * (each freeze has its own), or 0 */
int nt_body_setstatic(cpBody *body, int isstatic);
double nt_body_gettop(cpBody *body); /* the smallest y of its shapes */
void nt_body_setcollides(cpBody *body, int collides); /* off: its shapes collide with nothing */
/* the ids of the shapes of other bodies its shapes are touching: how many (up to max), into ids */
int nt_body_touching(cpBody *body, int *ids, int max);
int nt_body_getshapes(cpBody *body, cpShape **out, int max); /* how many, up to max */
void nt_body_tolocal(cpBody *body, double x, double y, double *out);
void nt_body_toworld(cpBody *body, double x, double y, double *out);

/* points: x1, y1, x2, y2, ... in the body's coordinates, convex; density 1.
 * id: any number but 0, reported by nt_world_contacts */
cpShape *nt_shape_newpolygon(cpBody *body, int count, const double *points, int id);
void nt_shape_free(cpShape *shape);
void nt_shape_setfriction(cpShape *shape, double friction);
void nt_shape_setrestitution(cpShape *shape, double restitution);
void nt_shape_setdensity(cpShape *shape, double density);
/* two shapes collide when each one's categories meet the other's mask */
void nt_shape_setfilter(cpShape *shape, unsigned categories, unsigned mask);
int nt_shape_testpoint(cpShape *shape, double x, double y);
/* how far along the line from x1, y1 to x2, y2 it first meets the shape (0-1), or -1 */
double nt_shape_raycast(cpShape *shape, double x1, double y1, double x2, double y2);
int nt_shape_getworldpoints(cpShape *shape, ntReal *out); /* how many points, into out[2*NT_MAXPOINTS] */
/* how much of the shape is in each of the rows of the given height it reaches: returns how many
 * rows, into areas[NT_MAXROWS], and the first row's number (from 0, at y 0) into *firstrow */
int nt_shape_rowareas(cpShape *shape, ntReal rowheight, int *firstrow, ntReal *areas);

#endif
