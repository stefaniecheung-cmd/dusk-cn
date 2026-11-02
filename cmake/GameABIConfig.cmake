# The game ABI surface shared by the main build and the mod SDK (sdk/CMakeLists.txt)
include_guard(GLOBAL)

get_filename_component(_game_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

# PARTIAL_DEBUG makes debug and release share one struct/vtable ABI so a mod binary loads into either
set(_game_compile_defs TARGET_PC=1 WIDESCREEN_SUPPORT=1 AVOID_UB=1 VERSION=0 MTX_USE_PS=1 PARTIAL_DEBUG=1)
if (ANDROID)
    list(APPEND _game_compile_defs TARGET_ANDROID=1)
endif ()

# Public game headers
#
# On Switch the game compiles against the aurora-switch fork (extern/aurora-switch), not the
# upstream PC aurora tree (extern/aurora). Keeping extern/aurora/include on the include path
# here lets <dolphin.h> (the unprefixed form JUTGamePad.h uses) resolve to the PC dolphin.h,
# which #includes <dolphin/arq.h>; that arq.h then re-includes "dolphin/ar.h" which resolves to
# aurora-switch's ar.h (already defines ARQRequest) -> redefinition/conflicting-typedef errors.
# aurora-switch ships the full aurora/ + dolphin/ header set (ar.h folds AR + ARQ together and
# there is no arq.h), so point the ABI dirs at aurora-switch instead on Switch.
if (AURORA_PLATFORM_SWITCH)
    set(_dusk_aurora_include_dolphin ${_game_root}/extern/aurora-switch/include/dolphin)
    set(_dusk_aurora_include        ${_game_root}/extern/aurora-switch/include)
else ()
    set(_dusk_aurora_include_dolphin ${_game_root}/extern/aurora/include/dolphin)
    set(_dusk_aurora_include        ${_game_root}/extern/aurora/include)
endif ()

set(_game_abi_include_dirs
        ${_game_root}/include
        ${_game_root}/assets/GZ2E01
        ${_game_root}/libs/JSystem/include
        ${_dusk_aurora_include_dolphin}
        ${_dusk_aurora_include}
        ${_game_root}/sdk/include
)

# Internal game headers
set(_game_include_dirs
        ${_game_abi_include_dirs}
        ${_game_root}/src
        ${_game_root}/extern
        ${CMAKE_CURRENT_BINARY_DIR}
)

# Mod API, including services
add_library(dusklight_mod_api INTERFACE)
target_include_directories(dusklight_mod_api INTERFACE ${_game_root}/sdk/include)

# Full internal headers used to build the game
add_library(dusklight_game_headers INTERFACE)
target_include_directories(dusklight_game_headers INTERFACE ${_game_include_dirs})
target_compile_definitions(dusklight_game_headers INTERFACE ${_game_compile_defs})

# Public game ABI for mods
add_library(dusklight_game_abi_headers INTERFACE)
target_include_directories(dusklight_game_abi_headers INTERFACE ${_game_abi_include_dirs})
target_compile_definitions(dusklight_game_abi_headers INTERFACE ${_game_compile_defs})

# Mod feature targets
add_library(dusklight_mod_feature_game INTERFACE)
target_link_libraries(dusklight_mod_feature_game INTERFACE
        dusklight_mod_api
        dusklight_game_abi_headers)
target_compile_definitions(dusklight_mod_feature_game INTERFACE DUSK_MOD_FEATURE_GAME=1)
# Game headers assume global.h comes first in the translation unit (it defines DUSK_GAME_DATA
# and friends); force-include it so mods don't depend on include order.
if (CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
    target_compile_options(dusklight_mod_feature_game INTERFACE
            "$<$<COMPILE_LANGUAGE:CXX>:/FIglobal.h>")
else ()
    target_compile_options(dusklight_mod_feature_game INTERFACE
            "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-include global.h>")
endif ()
target_sources(dusklight_mod_feature_game INTERFACE
        ${_game_root}/sdk/src/game_feature.cpp)

add_library(dusklight_mod_feature_webgpu INTERFACE)
target_link_libraries(dusklight_mod_feature_webgpu INTERFACE dusklight_mod_api)
target_compile_definitions(dusklight_mod_feature_webgpu INTERFACE DUSK_MOD_FEATURE_WEBGPU=1)

add_library(dusklight_mod_feature_fmt INTERFACE)
target_link_libraries(dusklight_mod_feature_fmt INTERFACE dusklight_mod_api)
target_compile_definitions(dusklight_mod_feature_fmt INTERFACE DUSK_MOD_FEATURE_FMT=1)
