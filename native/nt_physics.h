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

typedef struct ntWorld ntWorld;
typedef struct cpBody cpBody;
typedef struct cpShape cpShape;

ntWorld *nt_world_new(double gravityx, double gravityy);
void nt_world_free(ntWorld *world); /* and every body and shape in it */
void nt_world_step(ntWorld *world, double dt);
/* the shapes that began touching in the last step, as pairs of their ids:
 * returns how many pairs, and points *pairs at them until the next step */
int nt_world_contacts(ntWorld *world, const int **pairs);

cpBody *nt_body_new(ntWorld *world, double x, double y, int dynamic);
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
int nt_shape_getworldpoints(cpShape *shape, double *out); /* how many points, into out[2*NT_MAXPOINTS] */

#endif
