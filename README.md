# SV-AV50 SD-Audio

Getting music to play on a Panasonic SV-AV50, the 2004 "D-snap" SD camera, from a
Windows 11 PC.

The AV50 has an [AUDIO] mode, but it only plays CPRM-protected SD-Audio written by
Panasonic's SD-Jukebox software, which was last sold in 2016 and whose activation
servers went away in 2018. Plain MP3s copied to the card do nothing. The usual advice
is that this cannot be done from a modern 64-bit PC any more.

It can. On 2026-10-27 an album I own checked out to a 1 GB card and played in the
camera's [AUDIO] mode. The route that worked is SD-Jukebox V5.1 LE inside an offline
Windows XP SP3 virtual machine on the Windows 11 host, with the camera's cradle passed
through to the VM over USB. Natively on Windows 11 I got SD-Jukebox V4.0 and V5.1
installed, running, and talking to the card through the cradle's CPRM path, which is
further than any report I could find, but neither completed a check-out there.
[docs/status.md](docs/status.md) says exactly what is verified and what is not.

This repo is the write-up: what the camera and its cradle actually are on USB, how
Panasonic's "secure driver" works, why "Format failed" on two of my three cards, the
Windows 11 runbook as far as it goes, the XP VM runbook that works, and the small
tools I wrote to find all that out.

## The route that works, in short

Full version in [docs/xp-vm-route.md](docs/xp-vm-route.md).

1. Check your card first. It must be a standard SD card (not SDHC) with a CPRM
   protected area. Most cards made after about 2010 have none and can never hold
   SD-Audio. `tools/Read-SDStatus.ps1` reads the card's SD_STATUS register through
   the cradle and prints `SIZE_OF_PROTECTED_AREA`. Zero means stop and find another
   card.
2. Build a 32-bit Windows XP SP3 guest in VirtualBox 7: one CPU, 1 GB RAM, IDE disk,
   no network, USB 2.0 (EHCI) controller, and a USB filter for vendor `04DA` product
   `23D3` so the cradle goes straight to the guest. You need your own XP media and
   licence.
3. Install SD-Jukebox V5.1 LE in the guest from the archive.org item
   `panasonic-sd-jukebox-v-5.1`. Its device list includes the SV-AV50. The unmodified
   installer runs on XP with no tricks. Snapshot before first launch.
4. Dock the camera in PC mode (AC adaptor in the cradle, battery in, camera in PLAY,
   USB cable last). The guest sees a removable disk, SD-Jukebox shows it as an SD
   drive.
5. Set the portable device to SV-AV50/AV25 and MP3 conversion to AAC 128 kbps, import
   the album, format the card from inside SD-Jukebox, select the tracks and start the
   transfer. Quit, undock, switch the camera to [AUDIO], play.

## What I found along the way

The cradle is plain USB mass storage. With no Panasonic software at all, Windows 11
mounts the camera as a removable disk through its own USBSTOR driver. The device is
`USB\VID_04DA&PID_23D3`, Bulk-Only mass storage. No public USB ID database lists it,
so that number comes from the INF on the camera's own disc.
[docs/cradle-and-secure-layer.md](docs/cradle-and-secure-layer.md)

The "secure driver" Panasonic bundled for Windows 2000/XP is not a driver. It is a
pair of 32-bit user-mode DLLs and a small Windows service that sends SCSI pass-through
commands to the mass-storage disk. That is why it runs under WOW64 on 64-bit Windows,
where Panasonic's card readers (real kernel drivers) never could. The CPRM key library
is built locally by the installer from a blob on the disc, so the 2018 shutdown of
Panasonic's download server does not affect V4.0 or V5.1.
[docs/cradle-and-secure-layer.md](docs/cradle-and-secure-layer.md)

SD-Jukebox V4.0 runs on Windows 11 if three undocumented things are right: the secure
files sit in exactly the folders the installer meant (a copy of the SD manager DLL in
the plug-in folder makes it load itself recursively until the stack overflows), the
app runs elevated or its SD subsystem silently never loads, and the Gracenote CDDB
component is switched off. With those, it authenticates the card through the cradle
and shows it as a check-out target.
[docs/windows11-runbook.md](docs/windows11-runbook.md)

"Format failed" on my first two cards was the cards, not Windows. By attaching a small
debugger to SD-Jukebox and decoding the SCSI pass-through commands it sends, I found
it reads the card's SD_STATUS register and sees `SIZE_OF_PROTECTED_AREA = 0`. Both
were Class 10 1 GB cards made long after CPRM stopped being standard practice. A
pre-2006 card with no speed class in its register had a protected area and worked.
[docs/protected-area.md](docs/protected-area.md)

Natively on Windows 11, that third card still failed. V4.0 reads INQUIRY and SD_STATUS
and gives up before sending a single CPRM command; my best explanation is a 1 GB
pre-check that Panasonic only fixed in a Japanese V4.1 update, but I have not proven
it. V5.1 goes much further, reading the card's media key block over the secure path,
and then lists no SD drive. The same card with the same V5.1 in the XP guest worked
first time. Whatever V5.1's CPRM module objects to on Windows 11, I did not open the
module to find out, on purpose. [docs/windows11-runbook.md](docs/windows11-runbook.md)

The camera's own video clips are MPEG-4 part 2 with G.726 audio in ASF, which ffmpeg
can reproduce. In principle songs could go on the card as still-image "videos" with no
DRM at all, at telephone quality. I encoded one but never played it on the camera, so
that stays an untested idea. [docs/video-route.md](docs/video-route.md)

## Tools

Three scripts in [tools/](tools/). The PowerShell ones need Windows PowerShell 5.1 and
an elevated prompt, because SCSI pass-through and debugging another process both need
admin. None of them writes to the card.

`Read-SDStatus.ps1` finds the cradle's disk, sends the same INQUIRY and Panasonic
vendor SD_STATUS command that SD-Jukebox sends, and decodes the reply, including the
protected-area size. Run it elevated with the camera docked in PC mode. It logs to a
text file next to itself. This is the one to run before buying a second card.

```
powershell -ExecutionPolicy Bypass -File .\tools\Read-SDStatus.ps1
```

`Watch-PassThrough.ps1` attaches to a running `sd-jukebox.exe`, sets a breakpoint on
`kernel32!DeviceIoControl`, and for every SCSI pass-through logs the command bytes,
direction and length, then on return the SCSI status, sense data and the first bytes of
the reply. It detaches cleanly after the timeout and the app keeps running. It must
run in 32-bit PowerShell, elevated, because the target is a 32-bit elevated process.
It catches V4.0's Format click. V5.1 probes the card once at startup and never again,
so attaching to V5.1 afterwards sees nothing; the startup numbers in the docs came
from a launch-under-debugger variant I have not cleaned up for publishing.

```
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\tools\Watch-PassThrough.ps1 -Seconds 60
```

`Analyze-Minidump.py` reads a Windows minidump with nothing but the Python standard
library: exception record, module list, and a scan of the faulting thread's stack for
return addresses inside loaded modules. It is a poor man's stack walk, but it was
enough to see 33,000 frames of one DLL and find the recursive load.

```
python tools\Analyze-Minidump.py crash.dmp
```

## What I left out, and why

Nothing from Panasonic's discs is in this repo. The AV50's export software disc is on
archive.org as `panasonic-svav50-vff0217` and SD-Jukebox V5.1 LE as
`panasonic-sd-jukebox-v-5.1`; the docs describe what is inside them and link to them.

No Windows XP media or licence keys, and no pointers to any. You need your own.

No SD-Jukebox serial numbers and no way to make one. The installer asks for the number
printed on the CD case. I had to work out how the V4 installer checks it because my
case was lost, for software that came with my own camera, but publishing a generator
is not what this project is for.

No CPRM keys, no decryptor, no patch to SD-Jukebox's CPRM library and no attempt at
one. The licensed device keys inside that library are what make a check-out work, and
they stay where they are. Where V5.1 declined the card on Windows 11, I left the
reason inside that module unexamined.

No music. The album I used is one I own on MP3.

## Docs

- [docs/background.md](docs/background.md): what the manual settles, how SD-Audio
  and CPRM fit together, why there is no third way, and every published attempt I
  found.
- [docs/cradle-and-secure-layer.md](docs/cradle-and-secure-layer.md): the cradle on
  USB, the Panasonic SD-USB device ID table, and how the user-mode secure layer works.
- [docs/windows11-runbook.md](docs/windows11-runbook.md): SD-Jukebox V4.0 and V5.1
  natively on Windows 11, how far each gets, and the fixes that got them there.
- [docs/protected-area.md](docs/protected-area.md): the SD_STATUS decode, which cards
  work, and how to check one.
- [docs/xp-vm-route.md](docs/xp-vm-route.md): the full runbook for the route that
  works.
- [docs/video-route.md](docs/video-route.md): the untested DRM-free idea.
- [docs/status.md](docs/status.md): what is verified, what is not, and what I ruled
  out on purpose.

## Hardware, for the record

Panasonic SV-AV50, Japanese-market unit, Japanese firmware, 1.2 MP, standard SD only
(no SDHC). Cradle VSK0655 with AC adaptor VSK0647 (4.8 V), USB Mini-B, and a 4-pole
AV jack that is in and out on the Japanese cradle. Battery CGA-S301. The camera has no
USB socket of its own; USB only exists through the cradle, and only with the AC
adaptor and the battery both present.

The AV50's photos and ASF video clips I import with
[Card Drawer](https://github.com/JackPatrickErdman/card-drawer), a separate project.

## Problems

Open an issue on GitHub. If a script misbehaves, include the log it wrote next to
itself and which SD-Jukebox version and card you were using.

## License

MIT for everything in this repository. Panasonic, D-snap, SD-Jukebox and CPRM are
their owners' trademarks; nothing here is affiliated with them.
