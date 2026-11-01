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
      (plus the __tm_gmtoff and tm_zone spellings). tm_gmtoff/tm_zone are
      glibc/BSD struct tm extensions that newlib lacks. Crucially, these are
      SFINAE-UNFRIENDLY: the trailing decltype(tm.tm_gmtoff) is evaluated
      eagerly when the alias
          using tm_gmtoff_t = decltype(tm_gmtoff(std::tm{}));
      is formed, so merely adding a competing non-template overload does NOT
      suppress the templates - they still get instantiated and hard-error.
      The only correct fix is to REPLACE the template block wholesale with
      non-template overloads (this is exactly what upstream abseil later did
      under __NEWLIB__). Horizon has no zone database, so UTC offset 0 / empty
      zone name. Done unconditionally: this file is only ever compiled for the
      Switch build, and Dawn compiles abseil as a FetchContent subproject, so
      the parent toolchain's -D__SWITCH__ (add_definitions) does NOT reach it -
      a macro guard here would silently compile back out.

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

    edit_time_zone_libc(root)
    return 0

# The cctz fallback templates are SFINAE-unfriendly: a trailing
# `-> decltype(tm.tm_gmtoff)` is eagerly substituted, so the only safe fix is to
# replace the whole template trio with non-template overloads. The exact block
# differs across abseil revisions (the newer one has a leading `#if` guarding a
# `tm_gmtoff_t`/`tm_zone_t` alias), so match on the distinctive first template
# and consume through the tm_zone template's closing brace.
def edit_time_zone_libc(root):
    rel = "absl/time/internal/cctz/src/time_zone_libc.cc"
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        print("WARN: not found, skipping: %s" % rel)
        return
    src = io.open(path, encoding="utf-8").read()
    if "HORIZON_NEWLIB_TM_EXTENSIONS" in src:
        print("ok (already patched): %s" % rel)
        return
    body = src.find("auto tm_gmtoff(const T& tm) -> decltype(tm.tm_gmtoff) {")
    if body < 0:
        print("WARN: anchor absent, skipping: %s" % rel)
        return
    # Walk back to the `template <class T>` keyword line that introduces this
    # first tm_gmtoff template, so the whole template trio is removed and no
    # dangling `template <class T>` keyword is left behind.
    start = src.rfind("template", 0, body)
    if start < 0:
        print("WARN: template keyword absent, skipping: %s" % rel)
        return
    # End of the last template (tm_zone) - search from the first template onward.
    end = src.find("}", src.find("tm_zone", body)) + 1
    replacement = (
        "inline long tm_gmtoff(const std::tm&) { return 0; }\n"
        "inline const char* tm_zone(const std::tm&) { return \"\"; }\n"
        "// HORIZON_NEWLIB_TM_EXTENSIONS: the SFINAE-unfriendly fallback templates\n"
        "// above were replaced with these non-template overloads for newlib/Horizon,\n"
        "// whose struct tm has no tm_gmtoff/__tm_gmtoff/tm_zone fields.\n"
    )
    src = src[:start] + replacement + src[end:]
    io.open(path, "w", encoding="utf-8").write(src)
    print("patched: %s" % rel)

if __name__ == "__main__":
    sys.exit(main())
