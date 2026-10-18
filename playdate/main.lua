--Not Tetris 2 on Playdate. Playdate has no require: pdc compiles in what's imported here, and
--build.sh copies the game's files in beside this one (its main.lua as game.lua).
require = function() end --the game's own requires are LÖVE's

import "panel"
import "menuart"
import "platform_playdate"
import "physics_chipmunk"
import "game"
import "gameA"
import "gameB"
import "menu"
import "failed"
import "rocket"
import "scheduler"

game_load()
import "perf"
