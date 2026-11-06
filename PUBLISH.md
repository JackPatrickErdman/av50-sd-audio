# Publishing this repo

Run these yourself from a normal terminal in this folder. The GitHub CLI is installed
at `C:\Program Files\GitHub CLI\gh.exe` and is not on PATH, so it is called by full
path below. It is already logged in as JackPatrickErdman.

Before publishing, read the repo once more for anything that should not be public:

```
git ls-files
```

```
git grep -n -i -E "jackp|icloud|gmail|[a-z0-9._-]+@[a-z0-9.-]+\.[a-z]|c:\\users" -- . ":!PUBLISH.md"
```

The second command should print nothing.

## 1. Create the repo and push

```
& "C:\Program Files\GitHub CLI\gh.exe" repo create av50-sd-audio --public --source . --remote origin --push --description "Getting music to play on a 2004 Panasonic SV-AV50 D-snap camera from Windows 11: CPRM SD-Audio, SD-Jukebox, the cradle on USB, and the tools used to work it out"
```

That creates `github.com/JackPatrickErdman/av50-sd-audio`, adds it as `origin` and
pushes `main`.

## 2. Tag and release

```
git tag -a v0.1.0 -m "First public write-up: XP VM route verified 2026-10-27, Windows 11 native documented as far as it goes"
```

```
git push origin v0.1.0
```

```
& "C:\Program Files\GitHub CLI\gh.exe" release create v0.1.0 --title "v0.1.0" --notes "First public version. Music verified playing on the SV-AV50 on 2026-10-27 via SD-Jukebox V5.1 LE in an XP SP3 VirtualBox guest with the cradle passed through. Windows 11 native route documented as far as it gets (V4.0 and V5.1 run and talk to the card, no check-out). Tools: Read-SDStatus.ps1, Watch-PassThrough.ps1, Analyze-Minidump.py. See docs/status.md for what is and is not verified."
```

## 3. Afterwards

- Add the topics on the repo page if you want them: `panasonic`, `d-snap`, `sv-av50`,
  `sd-audio`, `cprm`, `sd-jukebox`, `retro-computing`.
- Issues are the support channel the README points to, so leave them enabled.
- This file can stay in the repo; it contains no secrets. Delete it if you prefer.
