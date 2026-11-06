# Windows 11 native: how far it gets

Tested on Windows 11 Pro 25H2 (build 26200), 64-bit, in October 2026, with the SV-AV50
on its cradle.

Short version: SD-Jukebox V4.0 installs, runs, authenticates the cradle and shows the
card as `SD(D:)` in its playlist tree, but its Format refused all three cards I tried.
V5.1 can be made to run too, and then declines the card after reading its protected
area. No check-out ever finished directly on Windows 11. What worked was an XP guest in
a VM, in xp-vm-route.md.

If you just want music on the camera, go there. This page is for anyone who wants to
know what actually happens on Windows 11, because V4.0 gets much further here than in
any report I've found, and the three fixes that get it there aren't written down
anywhere else.

You need the installers from the export disc (archive.org `panasonic-svav50-vff0217`),
the serial number from your own CD case, and the camera docked in PC mode.

## 0. Before you start

- Create a restore point.
- Go offline for the install and the first launch. Nothing in V4.0 needs the network,
  and this guarantees nothing can try to phone home and fail.

## 1. Install the secure layer

Run `USB_Driver\Setup.exe` elevated. If the 2004 InstallShield 6 engine refuses, place
the 2000/XP files by hand, exactly like this:

| File | Goes in |
|---|---|
| `sdpaums.dll` | `C:\Windows\SysWOW64\sda\` |
| `SDDEVMGR.dll` | `C:\Windows\SysWOW64\` (the root, not `sda\`) |
| `sdpasvc.exe` | `C:\Windows\SysWOW64\` |
| `sdsrvctl.exe` | `C:\Windows\SysWOW64\` |

Then from an elevated prompt:

```
C:\Windows\SysWOW64\sdpasvc.exe install
sc query SDPASVC
```

Why the folder matters. `SDDEVMGR.dll` loads every `sda\SD*.dll` as a plug-in and
skips only `<SystemDir>\sddevmgr.dll` itself. A copy of `SDDEVMGR.dll` inside `sda\`
matches the plug-in pattern, so the manager loads its own twin, whose init scans
`sda\` and loads it again, forever. The symptom is `sd-jukebox.exe` dying with
exception `0xC00000FD` (stack overflow) about seven seconds after launch. I spent two
crash dumps on this before `tools/Analyze-Minidump.py` showed roughly 33,000 frames of
`SDDEVMGR.dll` on the faulting stack with the strings `\sddevmgr.dll` and
`DDUnlockDrive` next to them. My first guess was the Gracenote CDDB init, because the
crash came right after it wrote its registry key. Wrong: turning CDDB off only changed
the timing.

## 2. Install SD-Jukebox V4.0

Run `SD-JukeboxV4\Setup.exe` elevated and offline. Click through the OS warning (it's
a continue-anyway prompt). Enter your serial. The installer runs `Cfg.exe` and builds
`SDCprm.dll` in `C:\Program Files (x86)\Common Files\Panasonic\SDApf\`, about 1.7 MB;
if that file exists afterwards, the CPRM step passed with no network. It may reboot for
the Intel IPP runtime.

After the reboot, check the service. The Jukebox installer re-registers `SDPASVC`
with the path `C:\Windows\system32\sdpasvc.exe`, which doesn't resolve on x64 (the
binary is in `SysWOW64`). Fix it:

```
sc config SDPASVC binPath= "C:\Windows\SysWOW64\sdpasvc.exe -service"
sc start SDPASVC
```

## 3. Three things to set before the first launch

1. Run the app elevated, always. Non-elevated launches never load `SDCore` or
   `SDCardMgr`; the SD subsystem silently does nothing and the window just has no SD
   node. Give `sd-jukebox.exe` the per-user `RUNASADMIN` compatibility layer, or start
   it with an explicit run-as. Note that a process started from some automation shells
   doesn't get the compatibility layer applied even when it's set; a double-click
   from Explorer does.
2. Turn CDDB off. Under `HKCU\Software\CNC\SD-JukeboxV4\Settings\CDDB` set
   `CDDBUse=0` and `CDDBAvailable=0`. The Gracenote component's init path is fragile
   on Windows 11 and, offline, it only adds a "cannot connect" dialog on every start.
3. Dock the camera in PC mode before launching. The app enumerates secure SD devices
   at startup only. If you dock afterwards, quit and relaunch.

## 4. What success looks like

- The main window shows a playlist tree with an `SD(D:)` node. That node appears only
  after the secure layer has authenticated the card through the cradle, so CPRM over
  the stock USBSTOR path is working on Windows 11.
- The `SV-AV50/AV25` device profile is selectable under the options.

## 5. Library and import quirks

- Non-elevated runs write the library into the VirtualStore shadow of the program
  folder; elevated runs use the real folder. Mixing the two makes the library appear
  to vanish. Pick elevated and stay there.
- The app orders imported tracks by filename and ignores the track-number tag. Pad the
  filenames (`01 - Title.mp3`) or build a User playlist in album order; the User
  playlist is what gets checked out as the card's playlist.
- Cover art shows as a thumbnail of about 76 px. A high-resolution scan rendered as a
  black square; a tightly cropped, high-contrast image around 900 px worked.

## 6. Where V4.0 stops

Dragging tracks to `SD(D:)` produced "Different file system. Open the settings and
format SD." The app's own Format then reported "Format failed." instantly and wrote
nothing. This happened on all three of my cards. For the two cards with no CPRM
protected area it was correct to (protected-area.md). For the third card, which has
one, a trace of the Format click (`tools/Watch-PassThrough.ps1`) shows the app sending
INQUIRY and the vendor SD_STATUS command, both answered normally, and then giving up
without a single CPRM command. The refusal is a pre-check on what it already read.

The only thing that differs from the cards Panasonic tested V4.0 with is size: 1 GB
against a documented maximum of 512 MB, and the Japanese V4.1 update's changelog
says it fixed "some 1 GB SD memory cards not being recognised". That's my best
explanation, and it's not proven: I didn't reverse the check itself, and I never tried
V4.0 with a 512 MB card.

## 7. SD-Jukebox V5.1 LE natively: what it takes, and where it stops

V5.1 handles 1 GB cards, so I tried it natively too. In order of the walls hit:

1. The installer refuses anything newer than Windows 2000/XP ("an operating system
   supporting SD-Jukebox has not been installed on this computer"). The test reads the
   version flags the InstallShield 6 engine computes. Compatibility mode on
   `Setup.exe` doesn't help, because the script runs in the separately launched
   engine (`IKernel.exe`, started over COM), and a compatibility layer on the engine
   didn't take either. I got past it with a copy of the installer whose one OS test
   was widened to accept any NT; the rest of the installer is unchanged, and the
   original package was left as is. Because V4 and V5.1 share one product GUID, the
   installer removes V4 first.
2. Smart App Control blocks every unsigned COM component the installer registers:
   the DirectShow filters, the G.726 codec, two OCX controls. The app then shows
   "Processing failed." Smart App Control has no per-file exception; it has to be
   turned off, after which 32-bit `regsvr32` registers them all.
3. The SDPASVC service path, the same fix as in section 2.
4. Elevation, as with V4.
5. The installer skips `SDResidence.exe`, the card-watcher helper, on this OS. I put it
   in place by hand from the package. It made no difference to what follows.
6. The card isn't listed. With all of the above, V5.1 runs and shows "Processing
   complete", the options page offers the SV-AV50/AV25 profile, and the Format Drive
   list is empty. A startup trace shows that within half a second of launch it sends
   22 SCSI pass-through commands to the cradle, every one with status 0 and empty
   sense: INQUIRY (six times), the vendor SD_STATUS command (protected area present),
   five vendor status polls, two 16-byte vendor reads, a session open, six secure
   reads of the protected area (five 512-byte blocks and one 16 KB block, the size of a
   CPRM media key block), and a session close. Then nothing. It never attempts an
   authentication. Whatever it decides, it decides inside the encrypted CPRM module
   after reading the MKB, and I didn't open that. The same card with the same V5.1 in
   an XP guest formats and checks out first time, so the card isn't the problem.

Steps 1 and 2 mean weakening the host's security for nothing in return. The XP guest is
the better deal even though it sounds like more work.

The import quirks in section 5 apply inside XP too, minus elevation and the
VirtualStore shadow, which don't exist there.
