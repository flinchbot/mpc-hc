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
2. **Toolchain** — run `setup-toolchain.ps1` (elevates itself): VS 2026 Community with v143 +
   ATL/MFC + Win11 SDK 26100 + clang-cl, `nasm.exe` 2.16.03 in `C:\Windows`, Python 3.13 + polib.
3. **build.user.bat** (gitignored):
   ```bat
   SET "MPCHC_GIT=C:\Program Files\Git"
   SET "MPCHC_PYTHON=C:\Program Files\Python313"
   SET "MPCHC_WINSDK_VER=10.0.26100.0"
   SET "MPCHC_LAV_TOOLCHAIN=MSVC"
   ```

## Toolchain
VS 2026 + **MSVC v143** toolset + **C++ MFC (v143)** + Windows 11 SDK (10.0.26100) · NASM · polib.
Since the 2026-10 upstream sync, LAV Filters' ffmpeg builds with MSBuild (`MPCHC_LAV_TOOLCHAIN=MSVC`),
so MSYS2, the maintainer mingw and YASM are no longer needed. The GCC route (docs\Compilation.md
Part H) still works if `MPCHC_MSYS`/`MPCHC_MINGW*` are set; the MSYS-related quirks below apply only to it.

## Build
```
git submodule update --init --recursive
build.bat Release x64        # full build; output: bin\mpc-hc_x64\mpc-hc64.exe
build.bat Lite Release x64   # Lite; output: "bin\mpc-hc_x64 Lite\mpc-hc64.exe" (note the space)
```
Note: "Lite" still compiles ffmpeg/LAV — it is not codec-free.

Install: `powershell -ExecutionPolicy Bypass -File install.ps1` (add `-Lite` for the Lite build)
copies the build into `C:\Program Files\MPC-HC`, overwriting the old build. It elevates itself,
closes a running player, keeps files only in the install folder (MPCVR, Shaders, uninstaller)
and skips `*.pdb/*.exp/*.lib/*.ilk`.

### VS 2026 asm quirk (parallel build)
Under VS 2026's MSBuild with `/maxcpucount`, the custom YASM/NASM tasks spuriously fail
("exited with code 1") on the first not-yet-built `.asm`/`.asm64` in each asm project, though the
exact command works run by hand. Workaround: pre-assemble the x64 asm objs, then the full build
finds them up-to-date and links. The 3 asm projects and their x64 files:
- **libass** (nasm): be_blur, blend_bitmaps, blur, cpuid, rasterizer
- **VirtualDub/system** (yasm): a64_cpuaccel, a64_fraction, a64_int128, a64_thunk
- **VirtualDub/Kasumi** (yasm): a64_resample.asm64

The plain 32-bit `.asm` siblings are `ExcludedFromBuild` for x64 — do not assemble those.

### Other build quirks (seen during the 2.8.0 sync, 2026-08)
- **Stale PCH after an MSVC update** — `error C1853: ... precompiled header file is from a
  different version of the compiler` across many projects. Fix: delete all `*.pch` under
  `bin\obj\` and rebuild (no full clean needed).
- **cmd "input line is too long" in build_lavfilters.bat** — happens when the invoking shell's
  `PATH` is already large (the batch prepends MSYS/mingw dirs and overflows cmd's 8191-char
  limit). Fix: launch `build.bat` with a lean PATH (System32 + git + python is enough; the
  build scripts add their own toolchain dirs).
- **Nondeterministic mingw gcc 15.2 ICE building ffmpeg** — `internal compiler error: in
  try_forward_edges, at cfgcleanup.cc:580` on a *different* file each run. The ffmpeg build is
  incremental, so simply re-running `build.bat` makes forward progress; 1–2 retries complete it.
