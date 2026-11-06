# SV-AV50 SD-Audio

How I got music playing on a Panasonic SV-AV50, the 2004 "D-snap" SD camera, from a
Windows 11 laptop.

The AV50 has a music mode, but it only plays SD-Audio: AAC or MP3 wrapped in CPRM copy
protection and written to the card by Panasonic's SD-Jukebox program. SD-Jukebox was
last sold in 2016 and its activation server went away in 2018. Copying MP3s to the
card does nothing, and everything I read said this stopped being possible on a 64-bit
PC years ago.

It still works, with a detour. The camera's cradle is an ordinary USB mass-storage
device, and SD-Jukebox V5.1 LE running in a Windows XP virtual machine on the Windows
11 host, with the cradle passed through to the VM, formats the card and checks tracks
out to it. The camera plays them. I did that on 2026-10-27 with an album I own.

I also got SD-Jukebox V4.0 and V5.1 installed and running directly on Windows 11,
talking to the card through the cradle's CPRM path, which as far as I can tell nobody
had managed. Neither one would finish a check-out there. I know roughly why for V4 and
not at all for V5. [docs/status.md](docs/status.md) lists what's confirmed and what
isn't.

## The short version

The long version is [docs/xp-vm-route.md](docs/xp-vm-route.md).

1. Check the card. It has to be a plain SD card (not SDHC) with a CPRM protected area,
   and most cards made after about 2010 don't have one. `tools/Read-SDStatus.ps1`
   reads the card's SD_STATUS register through the cradle and prints
   `SIZE_OF_PROTECTED_AREA`. If that's zero, no software will ever put music on that
   card. Find an older one.
2. Make a 32-bit Windows XP SP3 VM in VirtualBox 7: one CPU, 1 GB RAM, IDE disk, no
   network, USB 2.0 controller, and a USB filter for vendor `04DA` product `23D3` so the
   cradle lands in the guest. You need your own XP disc and licence.
3. Install SD-Jukebox V5.1 LE in the guest. It's on archive.org as
   `panasonic-sd-jukebox-v-5.1` and lists the SV-AV50 as a device. The installer runs
   on XP with no tricks. Snapshot the VM before the first launch.
4. Dock the camera: AC adaptor in the cradle, battery in, camera switched to PLAY, USB
   cable last. The guest gets a removable disk and SD-Jukebox shows it as an SD drive.
5. In SD-Jukebox set the portable device to SV-AV50/AV25 and MP3 conversion to AAC
   128 kbps. Import the album, format the card from inside SD-Jukebox, select the
   tracks, start the transfer. Quit, undock, switch the camera to AUDIO.

## Things I learned on the way

- The cradle needs no driver. Windows 11 mounts it through its own USB storage driver
  as `USB\VID_04DA&PID_23D3`. No public USB ID list has that number; it comes from the
  INF on the camera's own disc. More in
  [docs/cradle-and-secure-layer.md](docs/cradle-and-secure-layer.md).
- Panasonic's "secure driver" for 2000/XP isn't a driver. It's two 32-bit user-mode
  DLLs and a small Windows service that sends SCSI pass-through commands to the disk.
  That's why it runs under WOW64 on 64-bit Windows, where Panasonic's card readers
  (real kernel drivers) can't. The installer also builds the CPRM key library locally
  from a blob on the disc, so the 2018 server shutdown doesn't touch V4.0 or V5.1.
- SD-Jukebox V4.0 runs on Windows 11 once three things are right. The secure files
  have to be in exactly the folders the installer meant: a stray copy of the SD manager
  DLL in its own plug-in folder makes it load itself until the stack overflows. The
  app has to run elevated, or its SD code silently never loads. And the Gracenote CDDB
  component has to be switched off. Then it authenticates the card through the cradle
  and offers it as a check-out target. The runbook is
  [docs/windows11-runbook.md](docs/windows11-runbook.md).
- "Format failed." on my first two cards was the cards. I attached a small debugger to
  SD-Jukebox and decoded the SCSI commands it sends: it reads the card's SD_STATUS
  register and finds `SIZE_OF_PROTECTED_AREA = 0`. Both were Class 10 1 GB cards, made
  long after anyone cared about CPRM. A pre-2006 card with no speed class in its
  register has the area, and that's the card that worked. The decode is in
  [docs/protected-area.md](docs/protected-area.md).
- With that third card, Windows 11 still didn't get there. V4.0 reads INQUIRY and
  SD_STATUS and quits before sending a single CPRM command; my best guess is a 1 GB
  check that Panasonic fixed only in a Japanese V4.1 update, but I haven't proved it.
  V5.1 goes a lot further, reading the card's media key block over the secure path,
  then lists no SD drive. Same card, same V5.1 package, inside XP: worked the first
  time. Whatever V5.1's CPRM module dislikes about Windows 11 is inside that module,
  and I left it there.
- The camera's own video clips are MPEG-4 part 2 with G.726 audio in an ASF
  container, and ffmpeg can make matching files. So in theory songs could go on the
  card as still-image "videos" with no DRM at all, at phone-call quality. I encoded one
  and never got to try it on the camera. Notes in
  [docs/video-route.md](docs/video-route.md).

## Tools

Three scripts, in [tools/](tools/). The PowerShell ones want Windows PowerShell 5.1 and
an elevated prompt, since SCSI pass-through and debugging another process both need
admin. None of them writes to the card.

**Read-SDStatus.ps1** finds the cradle's disk, sends the same INQUIRY and Panasonic
vendor SD_STATUS command that SD-Jukebox sends, and decodes the reply, protected-area
size included. Run it elevated with the camera docked in PC mode. It logs to a text
file next to itself. Run this before buying a second card.

```
powershell -ExecutionPolicy Bypass -File .\tools\Read-SDStatus.ps1
```

**Watch-PassThrough.ps1** attaches to a running `sd-jukebox.exe`, puts a breakpoint on
`kernel32!DeviceIoControl`, and for every SCSI pass-through logs the command bytes,
direction and length, then the SCSI status, sense data and the start of the reply when
it returns. It detaches after the timeout and the app carries on. It has to run in
32-bit PowerShell, elevated, because the target is a 32-bit elevated process. It
catches V4.0's Format click. V5.1 probes the card once at startup and never again, so
attaching to V5.1 later sees nothing; the V5.1 startup numbers in the docs came from a
launch-under-debugger variant I haven't tidied up enough to publish.

```
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\tools\Watch-PassThrough.ps1 -Seconds 60
```

**Analyze-Minidump.py** reads a Windows crash dump with just the Python standard
library: exception record, module list, and a scan of the crashing thread's stack for
return addresses inside loaded modules. A crude stack walk, but it was enough to show
33,000 frames of one DLL and find the recursive load.

```
python tools\Analyze-Minidump.py crash.dmp
```

## What's not here

Nothing from Panasonic's discs. The AV50's export disc is on archive.org as
`panasonic-svav50-vff0217` and SD-Jukebox V5.1 LE as `panasonic-sd-jukebox-v-5.1`.
The docs describe what's inside them and link to them.

No Windows XP media or keys, and no pointers to any.

No SD-Jukebox serial numbers and no way to make one. The installer wants the number
printed on the CD case. Mine was lost, so I worked out how the V4 installer checks it,
to get software that came with my own camera installed again. That's as far as it goes.

No CPRM keys, decryptors, or patches to SD-Jukebox's CPRM library. The licensed device
keys in that library are what make a check-out work, and I didn't go near them. Where
V5.1 refused the card on Windows 11, the reason is inside that module and I left it
unexamined.

No music. The album is one I own on MP3.

## Docs

- [background.md](docs/background.md): what the manual says, how SD-Audio and CPRM fit
  together, why there's no third way, and every published attempt I found.
- [cradle-and-secure-layer.md](docs/cradle-and-secure-layer.md): the cradle on USB,
  Panasonic's SD-USB device IDs, and how the user-mode secure layer works.
- [windows11-runbook.md](docs/windows11-runbook.md): V4.0 and V5.1 directly on
  Windows 11, how far each gets, and the fixes that got them there.
- [protected-area.md](docs/protected-area.md): the SD_STATUS decode, which cards work,
  how to check one.
- [xp-vm-route.md](docs/xp-vm-route.md): the full runbook for the route that works.
- [video-route.md](docs/video-route.md): the untested DRM-free idea.
- [status.md](docs/status.md): what's verified, what isn't, what I ruled out on
  purpose.

## The hardware

A Japanese-market SV-AV50 with Japanese firmware, 1.2 MP, standard SD only. The
cradle is a VSK0655 with the VSK0647 AC adaptor (4.8 V), a USB Mini-B socket, and a
4-pole AV jack that's both in and out on the Japanese cradle. The battery is a
CGA-S301. The camera has no USB socket of its own; USB only exists through the cradle,
and only with the AC adaptor and the battery both in place.

The camera's photos and ASF clips I import with
[Card Drawer](https://github.com/JackPatrickErdman/card-drawer), a separate project.

## Problems

If something here doesn't match what you see, open an issue. For a script, include the
log it wrote next to itself, the SD-Jukebox version, and what card you had in.

## License

MIT. Panasonic, D-snap, SD-Jukebox and CPRM are their owners' trademarks; this isn't
affiliated with any of them.
