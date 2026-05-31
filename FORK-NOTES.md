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

## Build-compat changes (needed for VS 2026 / Windows SDK 10.0.26100)
- `src/platform.props` — maps VS 2026 (`VisualStudioVersion == 18.0`) to the **v143** toolset.
- `src/mpc-hc/DpiHelper.cpp` — SDK 26100 now declares the DPI functions the file also
  forward-declared; reconciled to avoid the `decltype` collision (error C3556).

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
3. **build.user.bat** (gitignored) — set `MPCHC_WINSDK_VER`, `MPCHC_MSYS=C:\msys64`,
   `MPCHC_MINGW32/64` = the maintainer mingw (dual i686+x86_64 sysroot from files.1f0.de),
   `MSYSTEM=MINGW64`, `MSYS2_PATH_TYPE=inherit`, and prepend the yasm/nasm dir to `PATH`.

## Toolchain
VS 2026 + **MSVC v143** toolset + **C++ MFC (v143)** + Windows 11 SDK (10.0.26100) ·
MSYS2 (`make pkg-config diffutils`) · maintainer mingw-w64-gcc (dual sysroot) · YASM + NASM · polib.

## Build
```
git submodule update --init --recursive
build.bat Release x64        # full build (LAV Filters + codecs); output: bin\mpc-hc_x64\mpc-hc64.exe
build.bat Lite Release x64   # fast UI-only build (no internal codecs)
```
