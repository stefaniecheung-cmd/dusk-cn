# Switch platform options for Aurora/Dawn — included BEFORE add_subdirectory(extern/aurora).
#
# Ported from HayatoG/dusklight (Switch port, main @ 95322b8) into this isolated overlay so the
# main CMakeLists keeps a single include() hook and upstream merges stay clean. All logic is a
# no-op unless AURORA_PLATFORM_SWITCH=ON (set by the devkitPro Switch.cmake toolchain).
#
# NOTE: this file must be included after the unconditional `set(AURORA_ENABLE_RMLUI ON ... FORCE)`
# in the main CMakeLists (CACHE FORCE: last writer wins) and before add_subdirectory(extern/aurora).

if (NOT AURORA_PLATFORM_SWITCH)
    return()
endif ()

# RmlUi powers the dusklight launcher UI; the aurora-switch fork ships RmlUi support for libnx.
# Override with -DDUSK_SWITCH_RMLUI=OFF for a minimal first bring-up.
set(DUSK_SWITCH_RMLUI ON CACHE BOOL "Build the RmlUi launcher UI on Switch")
set(AURORA_ENABLE_RMLUI ${DUSK_SWITCH_RMLUI} CACHE BOOL "Enable RmlUi UI support" FORCE)
# ImGui SDL3 backend is unavailable on libnx; the Switch build uses stubs instead.
set(AURORA_ENABLE_IMGUI OFF CACHE BOOL "Enable ImGui support" FORCE)

# WS1: enable Aurora's persistent WebGPU shader cache. Aurora defaults this OFF on Switch
# (_aurora_default_gpu_cache OFF), which selects pipeline_cache_memory.cpp + gpu_cache_null.cpp =
# per-frame shader-compile stutter. ON selects the async SQLite pipeline_cache.cpp path + Dawn
# BlobCache, matching the reference build's pre-seeded pipeline_cache.db / dawn_cache.db.
set(AURORA_ENABLE_GPU_CACHE ON CACHE BOOL "Enable persistent WebGPU shader cache" FORCE)
set(AURORA_CACHE_USE_ZSTD ON CACHE BOOL "Compress WebGPU cache entries with zstd" FORCE)

# On Switch, reuse the devkitPro portlib libzstd.a instead of letting Aurora FetchContent zstd
# (which also builds a `zstd` CLI EXECUTABLE target that collides with GAME_LIBS' plain `zstd`
# portlib link -> "Target zstd of type EXECUTABLE may not be linked"). Pre-defining
# libzstd_static makes aurora/extern/CMakeLists take its "Using existing zstd" branch (no fetch).
# borealis' io / disc / data / file_select modules all pull in borealis_sdl_dep, which needs an
# SDL3 target. There is no SDL3 for Horizon: aurora-switch answers this with a standalone
# interface target (see AuroraSDL3Provider.cmake, AURORA_PLATFORM_SWITCH branch) backed by libnx
# + its SDL3 shims. borealis only consults that provider when it bootstraps aurora itself; here
# aurora::core already exists (added above), so it skips the bootstrap and falls through to
# find_package(SDL3 CONFIG REQUIRED), which cannot succeed. Define the target up front so
# borealis links aurora-switch's Switch backend instead of searching for a package.
if (NOT TARGET SDL3::SDL3 AND NOT TARGET SDL3::SDL3-static)
    add_library(aurora_sdl3_switch_shim INTERFACE)
    add_library(SDL3::SDL3-static ALIAS aurora_sdl3_switch_shim)
endif ()

if (NOT TARGET libzstd_static)
    find_library(DUSK_SWITCH_LIBZSTD NAMES zstd libzstd
        PATHS "$ENV{DEVKITPRO}/portlibs/switch/lib" /opt/devkitpro/portlibs/switch/lib NO_DEFAULT_PATH)
    if (DUSK_SWITCH_LIBZSTD)
        add_library(libzstd_static STATIC IMPORTED GLOBAL)
        set_target_properties(libzstd_static PROPERTIES IMPORTED_LOCATION "${DUSK_SWITCH_LIBZSTD}")
    endif ()
endif ()

# WS1: the SQLite amalgamation includes <sys/mman.h>, which newlib/devkitA64 lacks. The shader
# cache needs neither memory-mapped I/O nor WAL shared-memory, so compile both out. The on-disk
# .db format is unchanged, so we can still consume pre-seeded pipeline_cache.db / dawn_cache.db.
# (Applied after add_subdirectory via LinkOptions? No: applied here if the target already exists
# is impossible pre-add_subdirectory; the definition block lives in switch/LinkOptions.cmake.)
