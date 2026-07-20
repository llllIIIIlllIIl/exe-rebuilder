# exe-rebuilder

A small PowerShell-based build tool that packages an app and its dependencies into a single self-extracting, self-running `.exe`, using 7-Zip's SFX (self-extracting archive) installer module.

Drop your app's files in `files\`, run the script, and get back one portable `.exe` that silently extracts everything to a temp folder and launches your app — no installer wizard, no separate DLLs to ship.

## Folder structure

```
exe-builder\
├── build.ps1          # the build script — run this
├── 7za.exe             # 7-Zip CLI, used to compress files\ into payload.7z
├── 7zSD.sfx            # 7-Zip SFX installer module (supports auto-run on extract)
├── config.7z.ini        # generated install config (regenerated on every run)
├── files\               # put app.exe + everything it needs here
└── export folder\      # rebuilt.exe lands here
```

## How it works

1. **Archive** — everything inside `files\` is compressed into a temporary `payload.7z`, with files stored flat at the archive root (no subfolder), so they extract back out sitting next to each other exactly as they do in `files\`.
2. **Configure** — `config.7z.ini` is generated with two directives: `RunProgram="app.exe"` (launch it after extraction) and `Progress="no"` (extract silently, no dialog).
3. **Bundle** — `7zSD.sfx`, `config.7z.ini`, and `payload.7z` are concatenated byte-for-byte into one file: `rebuilt.exe`, written to `export folder\`.
4. **Clean up** — `payload.7z` is deleted automatically, but only after `rebuilt.exe` is confirmed to exist.

`7zSD.sfx` specifically is used instead of the plain `7z.sfx` module, because only the installer-flavored SFX modules (`7zSD.sfx` / `7zS.sfx`) support the `RunProgram` directive — the plain module just extracts files and stops.

## Rebuilding an existing `.exe`

This isn't limited to apps you build from scratch — it also works for repacking a `.exe` that was itself created as a 7-Zip SFX archive, which is exactly the kind of file this tool produces. Since the whole file is just an SFX stub with a normal 7z archive attached to the end, 7-Zip can extract it directly, no different from extracting a `.7z` file:

```powershell
& ".\7za.exe" x "path\to\some-file.exe" -o"extracted"
```

Whatever comes out of that extraction is yours to edit freely before repacking — add files, remove files, replace files, anything. The repack step doesn't validate contents against the original; it just archives whatever's sitting in `files\` and glues it behind `7zSD.sfx`.

1. Extract the original `.exe` with 7-Zip (right-click → Extract, or the command above).
2. Copy the extracted files into `files\`, changing whatever you want along the way.
3. Run `.\build.ps1` as usual.
4. `rebuilt.exe` in `export folder\` behaves like the original — silent extract, auto-run — but with your edits baked in.

If the original `.exe`'s entry point isn't named `app.exe`, update the `RunProgram` value in `build.ps1` to match it.

> Only do this with software you actually have the right to modify and redistribute.

## Usage

1. Put `app.exe` and every file it depends on (DLLs, data files, etc.) into `files\`.
2. Run the build script:
   ```powershell
   .\build.ps1
   ```
3. Grab the finished executable from `export folder\rebuilt.exe`.

Running `rebuilt.exe` extracts all of `files\`'s contents to a temp folder and launches `app.exe` from there, silently, with no visible extraction dialog.

## Requirements

- Windows PowerShell
- `7za.exe` and `7zSD.sfx` present in this folder (both included)

## Notes

- The script resolves its own folder via `$PSScriptRoot`, so the whole `exe-builder` folder can be moved or copied anywhere (even a different drive) and `.\build.ps1` will keep working without edits — as long as you run it as a saved `.ps1` file, not pasted line-by-line into the console.
- `app.exe` must be named `app.exe` and sit at the top level of `files\` (not in a subfolder) for `RunProgram="app.exe"` to find it after extraction.
- Any file placed in `files\` gets bundled — there's no filtering, so keep that folder limited to exactly what `app.exe` needs at runtime.
