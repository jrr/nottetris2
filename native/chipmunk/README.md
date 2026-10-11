Chipmunk2D 7.0.3 (https://github.com/slembcke/Chipmunk2D, tag Chipmunk-7.0.3,
commit 87340c2), MIT licensed (LICENSE.txt): its `src/` and `include/` only,
without the threaded solver (cpHastySpace), which needs pthreads.

Unchanged from the release: changes are patches in ../patches, which the
Makefile applies when it builds.
