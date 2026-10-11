# Builds nt_physics.so: the game's physics (nt_physics.c, on Chipmunk) as a
# library for LÖVE to load with LuaJIT's FFI (nt_physics_love.lua). The
# harness runs `make -C native` before the game plays. Playdate builds the
# same sources its own way.
#
# Floats, as on Playdate, so both play alike.
CC ?= cc
CFLAGS = -O2 -std=gnu11 -fPIC -ffp-contract=off -DCP_USE_DOUBLES=0 -DCP_USE_CGTYPES=0 -Ichipmunk/include
SOURCES = nt_physics.c $(wildcard chipmunk/src/*.c)
OBJECTS = $(patsubst %.c,build/%.o,$(SOURCES))

nt_physics.so: $(OBJECTS)
	@$(CC) -shared -o $@ $^ -lm

build/%.o: %.c nt_physics.h
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -rf build nt_physics.so

.PHONY: clean
