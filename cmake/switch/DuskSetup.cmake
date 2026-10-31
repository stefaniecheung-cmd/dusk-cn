# Switch platform setup — included after GAME_LIBS / GAME_COMPILE_DEFS are assembled,
# before GAME_DEBUG_FILES is consumed downstream.
#
# Ported from HayatoG/dusklight (Switch port) into an isolated overlay; no-op unless
# AURORA_PLATFORM_SWITCH=ON.

if (NOT AURORA_PLATFORM_SWITCH)
    return()
endif ()

# SQLite on newlib (see switch/AuroraOptions.cmake): compile out mman/WAL/dlopen usage.
if (TARGET sqlite3)
    target_compile_definitions(sqlite3 PRIVATE
        SQLITE_OMIT_WAL              # WAL shared-memory needs <sys/mman.h> (absent in newlib)
        SQLITE_MAX_MMAP_SIZE=0       # disable memory-mapped I/O (<sys/mman.h>)
        SQLITE_OMIT_LOAD_EXTENSION)  # dlopen extension loading needs <dlfcn.h> (absent in newlib)
endif ()

# Extra include paths on Switch:
#  - devkitPro portlibs (libpng, zstd, expat, ...)
#  - aurora's Tracy stub dir (aurora-switch ships a no-op tracy backend for libnx)
#  - platforms/switch/src (SDL3 shims + dusk_rmlui_shim / dusk_imgui_shim)
set(DUSK_SWITCH_INCLUDE_DIRS
    "$ENV{DEVKITPRO}/portlibs/switch/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/extern/aurora/lib/switch/tracy_stub"
    "${CMAKE_CURRENT_SOURCE_DIR}/platforms/switch/src")
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/extern/aurora-switch/include")
    list(APPEND DUSK_SWITCH_INCLUDE_DIRS
        "${CMAKE_CURRENT_SOURCE_DIR}/extern/aurora-switch/include")
endif ()
if (TARGET dusklight_game_headers)
    target_include_directories(dusklight_game_headers INTERFACE ${DUSK_SWITCH_INCLUDE_DIRS})
endif ()

# Library surface on Switch:
#  - `zstd::libzstd` (FetchContent zstd) is replaced by the devkitPro portlib `zstd`
#    (libzstd_static was pre-defined in switch/AuroraOptions.cmake so aurora skips its fetch)
#  - `expat` is a Mesa utility dependency for the NVK-Vulkan path (no EGL/GLESv2/glapi/drm_nouveau;
#    the GLES backend is off and the NVK winsys replaces libdrm_nouveau)
list(REMOVE_ITEM GAME_LIBS zstd::libzstd)
list(APPEND GAME_LIBS zstd expat)
