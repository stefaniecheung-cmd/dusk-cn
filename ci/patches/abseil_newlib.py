#!/usr/bin/env python3
"""Patch Dawn's vendored abseil so it builds with devkitA64 / newlib (Horizon).

Dawn pins abseil-cpp to a Chromium revision that assumes a glibc/BSD host in four
places. devkitA64's newlib provides none of them:

  absl/base/internal/sysinfo.cc
      GetTID()'s fallback is `static_cast<pid_t>(pthread_self())`, but newlib
      declares pthread_t as an opaque `struct __pthread_t *`
      (sys/_pthreadtypes.h), so the static_cast is ill-formed. Cast the pointer
      value instead - still unique per thread, which is all GetCachedTID() needs.

  absl/base/internal/thread_identity.cc
      SetCurrentThreadIdentity() masks signals around pthread_setspecific() with
      sigfillset/pthread_sigmask/SIG_SETMASK. Horizon has no POSIX signals, so
      take the branch abseil already uses for Emscripten/WASI/MinGW.

  absl/debugging/internal/elf_mem_image.h
      devkitA64 targets ELF, so abseil defines ABSL_HAVE_ELF_MEM_IMAGE and
      includes glibc's <link.h> for ElfW/dl_iterate_phdr symbolization. newlib
      has no <link.h>. The macro cannot be predefined (the header #errors if it
      is), so add __SWITCH__ to the exclusion list already holding
      OpenBSD/QNX/wasm/Haiku/VxWorks/hexagon/Xtensa.

  absl/time/internal/cctz/src/time_zone_libc.cc
      The generic fallback declares
      `template<class T> auto tm_gmtoff(const T&) -> decltype(tm.tm_gmtoff)`
      (plus the __tm_gmtoff spelling). tm_gmtoff/tm_zone are glibc/BSD struct
      tm extensions that newlib lacks, so deduction fails outright. Upstream
      abseil later grew a __NEWLIB__ branch, but the pinned revision predates
      it. Add a non-template exact-match overload: it wins overload resolution
      and leaves the templates uninstantiated. Horizon has no zone database, so
      UTC offset 0 / empty zone name.

Idempotent, so it is safe to re-run against a cache-restored tree.
"""
import io
import os
import sys

def edit(root, rel, old, new, marker=None):
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        print("WARN: not found, skipping: %s" % rel)
        return
    src = io.open(path, encoding="utf-8").read()
    if marker and marker in src:
        print("ok (already patched): %s" % rel)
        return
    if old not in src:
        print("WARN: anchor absent, skipping: %s" % rel)
        return
    io.open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
    print("patched: %s" % rel)

def main():
    root = sys.argv[1] if len(sys.argv) > 1 else \
        "platforms/switch/reference/dawn-switch/third_party/abseil-cpp"
    if not os.path.isdir(root):
        print("FATAL: abseil not present at %s" % root)
        return 1

    edit(root, "absl/base/internal/sysinfo.cc",
         "return static_cast<pid_t>(pthread_self());",
         "return static_cast<pid_t>(reinterpret_cast<unsigned long>(pthread_self()));")

    edit(root, "absl/base/internal/thread_identity.cc",
         "defined(__hexagon__)",
         "defined(__hexagon__) || defined(__SWITCH__)",
         marker="__SWITCH__")

    edit(root, "absl/debugging/internal/elf_mem_image.h",
         "!defined(__XTENSA__)",
         "!defined(__XTENSA__) && !defined(__SWITCH__)",
         marker="__SWITCH__")

    edit(root, "absl/time/internal/cctz/src/time_zone_libc.cc",
         "auto tm_gmtoff(const T& tm) -> decltype(tm.tm_gmtoff) {",
         "#if defined(__SWITCH__)\n"
         "// newlib's struct tm carries no tm_gmtoff/__tm_gmtoff extension fields, so the\n"
         "// generic fallback templates below cannot be instantiated for it. A non-template\n"
         "// exact-match overload wins overload resolution and leaves them uninstantiated.\n"
         "inline long tm_gmtoff(const std::tm&) { return 0; }\n"
         "inline const char* tm_zone(const std::tm&) { return \"\"; }\n"
         "#endif\n"
         "auto tm_gmtoff(const T& tm) -> decltype(tm.tm_gmtoff) {",
         marker="__SWITCH__")
    return 0

if __name__ == "__main__":
    sys.exit(main())
