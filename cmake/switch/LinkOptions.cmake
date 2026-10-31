# Switch link options — included after target_link_libraries(dusklight ...).
#
# Ported from HayatoG/dusklight (Switch port). No-op unless AURORA_PLATFORM_SWITCH=ON.

if (NOT AURORA_PLATFORM_SWITCH)
    return()
endif ()

# devkitA64 GCC doesn't advertise LINK_GROUP RESCAN; fall back to raw --start-group/--end-group
# so the split JSystem static archives resolve cross-references.
if (NOT CMAKE_CXX_LINK_GROUP_USING_RESCAN_SUPPORTED)
    set(JSYSTEM_LINK_LIBRARIES "-Wl,--start-group" ${JSYSTEM_LIBRARIES} "-Wl,--end-group")
endif ()

# M-DV-2 NVK-Vulkan final link. The NVK driver archive (DAWN_SWITCH_NVK_LIBRARY, exported by
# aurora_core.cmake when built against the dawn-switch fork) MUST be --whole-archive: Mesa's
# entrypoint dispatch uses WEAK symbols; on-demand archive pull leaves null dispatch entries ->
# wsi_device_init calls a null proc -> Instruction Abort. The winsys shim baked into it needs the
# open/close/stat/lstat wraps + the loaderless vk_icdGetInstanceProcAddr wrap.
if (NOT AURORA_BACKEND_DEKO3D AND NOT AURORA_BACKEND_GLES AND NOT AURORA_BACKEND_DAWN_GL)
    target_link_options(dusklight PRIVATE
        -Wl,--allow-multiple-definition
        -Wl,--wrap=open -Wl,--wrap=close -Wl,--wrap=stat -Wl,--wrap=lstat
        -Wl,--wrap=vk_icdGetInstanceProcAddr
        # diagnostics: log who calls abort() (NVK/NAK panic asserts -> User Break) before breaking.
        -Wl,--wrap=abort
        -Wl,--whole-archive "${DAWN_SWITCH_NVK_LIBRARY}" -Wl,--no-whole-archive)
endif ()
