# flinchbot-MPC-HC — fork notes

Personal fork of clsid2/mpc-hc. All in-tree changes are tagged `[FORK CUSTOMIZATION]`
(find them with `git grep "FORK CUSTOMIZATION"`).

## Feature changes
- **Frameless window** — `AppSettings.cpp`: caption pinned to `MODE_FRAMEONLY` (no title bar,
  no menu bar; drag the video to move the window).
- **Fast-forward / rewind buttons removed** — `PlayerToolBar.cpp` (skip-track prev/next kept).
- **Playlist shuffle by default** — `AppSettings.cpp` (forced ON each launch; toggleable per-session).
- **Don't resize window to video** — `AppSettings.cpp`: `fRememberWindowSize` forced ON; video
  scales to the current window (`DVS_FROMINSIDE`).
- **Brutal bulk playlist add** — `PlayerPlaylistBar.cpp`: folder drops use O(1) hash-set de-dup
  (was O(n^2)) and defer per-item `AutoLoadFiles()`/`LoadDuration()` to play time
  (`GetCurOMD` re-runs `AutoLoadFiles`), eliminating thousands of NAS round-trips on populate.
- **Renamed to flinchbot-MPC-HC** — `MainFrm.cpp` (window/taskbar title) + `res/mpc-hc.rc2`
  (FileDescription / ProductName → Task Manager + file Properties).

## Build-compat changes — none as of 2.7.4 (upstream absorbed them)
Through 2.7.3 the fork carried two VS 2026 / Windows SDK 10.0.26100 build-compat patches:
`src/platform.props` (map `VisualStudioVersion == 18.0` → **v143**) and `src/mpc-hc/DpiHelper.cpp`
(reconcile the SDK-26100 DPI-function declarations that collided with the file's forward-declares,
error C3556). **Upstream 2.7.4 adopted both independently** — it maps 18.0 → v143 and rewrote
`DpiHelper.cpp` to drop the forward-declares and use explicit `WinapiFunc<>` signatures. Both fork
patches were therefore dropped during the 2.7.4 rebase; these files now match upstream verbatim.

## Out-of-tree / environment prerequisites (NOT committed)
These live outside the main repo and must be re-applied on a fresh machine:

1. **qsdecoder toolset patch (submodule)** — `src/thirdparty/LAVFilters/src/qsdecoder/IntelQuickSyncDecoder.vcxproj`
   has no VS 2026 entry and falls back to v100. Add, after the `17.0` block:
   ```xml
   <PropertyGroup Label="Configuration" Condition="'$(VisualStudioVersion)' == '18.0'">
     <PlatformToolset>v143</PlatformToolset>
     <SpectreMitigation>false</SpectreMitigation>
     <WindowsTargetPlatformVersion>10.0</WindowsTargetPlatformVersion>
   </PropertyGroup>
   ```
2. **polib** (translation build) — `python -m pip install polib`
3. **nasm + yasm** — not in stock MSYS2. Put `nasm.exe` (2.16.03, nasm.us) and `yasm.exe`
   (1.3.0, tortall.net) in `C:\msys64\usr\bin` (on the build PATH).
4. **maintainer mingw** (dual i686+x86_64 sysroot, files.1f0.de) — used by `update_mingwlib.bat`
   for `libmingwex.a`/`libgcc.a` (both arches). Latest r44 = gcc 15.2. Extract to a dir and point
   `MPCHC_MINGW32/64` at it (kept separate from stock MSYS2 mingw64 is fine).
5. **build.user.bat** (gitignored) — set `MPCHC_WINSDK_VER`, `MPCHC_MSYS=C:\msys64`,
   `MPCHC_MINGW32/64` = the maintainer mingw, `MSYSTEM=MINGW64`, `MSYS2_PATH_TYPE=inherit`.

## Toolchain
VS 2026 + **MSVC v143** toolset + **C++ MFC (v143)** + Windows 11 SDK (10.0.26100) ·
MSYS2 (`make pkg-config diffutils`) · maintainer mingw-w64-gcc (dual sysroot) · YASM + NASM · polib.

## Build
```
git submodule update --init --recursive
build.bat Release x64        # full build; output: bin\mpc-hc_x64\mpc-hc64.exe
build.bat Lite Release x64   # Lite; output: "bin\mpc-hc_x64 Lite\mpc-hc64.exe" (note the space)
```
Note: "Lite" still compiles ffmpeg/LAV — it is not codec-free.

### VS 2026 asm quirk (parallel build)
Under VS 2026's MSBuild with `/maxcpucount`, the custom YASM/NASM tasks spuriously fail
("exited with code 1") on the first not-yet-built `.asm`/`.asm64` in each asm project, though the
exact command works run by hand. Workaround: pre-assemble the x64 asm objs, then the full build
finds them up-to-date and links. The 3 asm projects and their x64 files:
- **libass** (nasm): be_blur, blend_bitmaps, blur, cpuid, rasterizer
- **VirtualDub/system** (yasm): a64_cpuaccel, a64_fraction, a64_int128, a64_thunk
- **VirtualDub/Kasumi** (yasm): a64_resample.asm64

The plain 32-bit `.asm` siblings are `ExcludedFromBuild` for x64 — do not assemble those.
