# The game's C for Playdate: nt_playdate.c with nt_physics.c and Chipmunk from ../native, built
# like native/Makefile builds them for LÖVE (patches applied, floats, no debug checks). build.sh
# runs this twice, for the Simulator and the device.
cmake_minimum_required(VERSION 3.19)
set(CMAKE_C_STANDARD 11)

set(PLAYDATE_GAME_NAME nottetris2)
set(PLAYDATE_GAME_DEVICE nottetris2_DEVICE)
project(nottetris2 C ASM)

file(TO_CMAKE_PATH "$ENV{PLAYDATE_SDK_PATH}" SDK)
if (NOT EXISTS "${SDK}")
	message(FATAL_ERROR "SDK path not found; set PLAYDATE_SDK_PATH (mise does)")
endif()

set(NATIVE ${CMAKE_CURRENT_SOURCE_DIR}/../native)
file(GLOB CHIPMUNK ${NATIVE}/chipmunk/src/*.c)

# native/patches/<file>.patch changes chipmunk/src/<file>: build a patched copy instead
file(GLOB PATCHES ${NATIVE}/patches/*.c.patch)
foreach(PATCH ${PATCHES})
	get_filename_component(NAME ${PATCH} NAME)
	string(REGEX REPLACE "\\.patch$" "" FILE ${NAME})
	set(PATCHED ${CMAKE_CURRENT_BINARY_DIR}/patched/${FILE})
	add_custom_command(
		OUTPUT ${PATCHED}
		COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/patched
		COMMAND patch -s -o ${PATCHED} ${NATIVE}/chipmunk/src/${FILE} ${PATCH}
		DEPENDS ${PATCH} ${NATIVE}/chipmunk/src/${FILE}
	)
	list(REMOVE_ITEM CHIPMUNK ${NATIVE}/chipmunk/src/${FILE})
	list(APPEND CHIPMUNK ${PATCHED})
endforeach()

set(SOURCES nt_playdate.c ${NATIVE}/nt_physics.c ${CHIPMUNK})
# unsuffixed constants like 0.5 as floats too, or they'd make float arithmetic software doubles
set_source_files_properties(${NATIVE}/nt_physics.c ${CHIPMUNK} PROPERTIES COMPILE_OPTIONS -fsingle-precision-constant)

if (TOOLCHAIN STREQUAL "armgcc")
	set(TARGET ${PLAYDATE_GAME_DEVICE})
	add_executable(${TARGET} ${SOURCES} syscalls.c)
else()
	set(TARGET ${PLAYDATE_GAME_NAME})
	add_library(${TARGET} SHARED ${SOURCES})
endif()

target_include_directories(${TARGET} PRIVATE ${NATIVE} ${NATIVE}/chipmunk/include)
target_compile_definitions(${TARGET} PRIVATE NDEBUG CP_USE_DOUBLES=0 CP_USE_CGTYPES=0)
target_compile_options(${TARGET} PRIVATE -Wno-double-promotion)

include(${SDK}/C_API/buildsupport/playdate_game.cmake)
