Chipmunk2D 7.0.3 (https://github.com/slembcke/Chipmunk2D, tag Chipmunk-7.0.3,
commit 87340c2), MIT licensed (LICENSE.txt): its `src/` and `include/` only,
without the threaded solver (cpHastySpace), which needs pthreads.

Changed here: cpArbiterApplyCachedImpulse (src/cpArbiter.c) scales the
accumulated contact impulses by the step ratio, as Box2D does, instead of only
what it applies. See the comment there.
