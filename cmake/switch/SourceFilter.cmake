# Switch source-set filter — included after GAME_FILES is split from DUSK_INTERNAL_FILES,
# before add_library(dusk_internal)/add_executable(dusklight).
#
# Ported from HayatoG/dusklight (Switch port). No-op unless AURORA_PLATFORM_SWITCH=ON.

if (NOT AURORA_PLATFORM_SWITCH)
    return()
endif ()

# PC-only sources: SDL3 audio backend, ImGui SDL backend, crash handler (<dlfcn.h>/<link.h>
# POSIX symbols not in newlib). Functional replacements come from platforms/switch/src stubs +
# the libnx audren audio backend. See switch/LinkOptions.cmake for the symbol-wraps story.
list(FILTER DUSK_INTERNAL_FILES EXCLUDE REGEX "src/dusk/audio/")
list(FILTER DUSK_INTERNAL_FILES EXCLUDE REGEX "src/dusk/imgui/")
list(FILTER DUSK_INTERNAL_FILES EXCLUDE REGEX "src/dusk/crash_handler\\.cpp")
list(FILTER DUSK_INTERNAL_FILES EXCLUDE REGEX "src/dusk/iso_validate")
list(FILTER GAME_FILES EXCLUDE REGEX "src/dusk/")

# Audio IS enabled on Switch: the JAudio2/DSP software pipeline is portable, and the SDL3 audio
# surface DuskAudioSystem uses is implemented over libnx audren in platforms/switch/src/
# switch_audio.cpp (mirrors the reference build's SDL3 audren backend). Re-include those five:
list(APPEND GAME_FILES
    src/dusk/audio/DuskAudioSystem.cpp
    src/dusk/audio/DuskDsp.cpp
    src/dusk/audio/Adpcm.cpp
    src/dusk/audio/JASCriticalSection.cpp
    src/dusk/audio/DspStub.cpp
    platforms/switch/src/switch_audio.cpp
    platforms/switch/src/switch_perf.cpp
    platforms/switch/src/switch_stubs.cpp)
