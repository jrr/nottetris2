# Builds nt_physics.so: the game's physics (nt_physics.c, on Chipmunk) as a
# library for LÖVE to load with LuaJIT's FFI (nt_physics_love.lua). The
# harness runs `make -C native` before the game plays. Playdate builds the
# same sources its own way.
#
# chipmunk/ is Chipmunk's source as released. patches/<file>.patch changes
# chipmunk/src/<file>: the patched copy is made in build/patched/ and built
# instead.
#
# Floats, as on Playdate, so both play alike.
CC ?= cc
CFLAGS = -O2 -std=gnu11 -fPIC -ffp-contract=off -DCP_USE_DOUBLES=0 -DCP_USE_CGTYPES=0 -Ichipmunk/include
PATCHED = $(patsubst patches/%.patch,build/patched/%,$(wildcard patches/*.c.patch))
CHIPMUNK = $(filter-out $(patsubst build/patched/%,chipmunk/src/%,$(PATCHED)),$(wildcard chipmunk/src/*.c))
OBJECTS = $(patsubst %.c,build/%.o,nt_physics.c $(CHIPMUNK)) $(PATCHED:.c=.o)

nt_physics.so: $(OBJECTS)
	@$(CC) -shared -o $@ $^ -lm

build/patched/%: chipmunk/src/% patches/%.patch
	@mkdir -p $(dir $@)
	@patch -s -o $@ $< patches/$*.patch

build/patched/%.o: build/patched/%.c
	@$(CC) $(CFLAGS) -c -o $@ $<

build/%.o: %.c nt_physics.h
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -rf build nt_physics.so

# keep the patched sources, to look at and so make doesn't remake them
.SECONDARY: $(PATCHED)

.PHONY: clean
