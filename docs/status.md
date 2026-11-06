# Status

As of 2026-11-06.

## What works

Music plays on the SV-AV50. On 2026-10-27 I imported an album I own into SD-Jukebox
V5.1 LE running in a Windows XP SP3 VirtualBox guest on a Windows 11 host, formatted a
1 GB CPRM-capable card from SD-Jukebox, checked the tracks out through the camera's
cradle passed through over USB, and the camera played them in AUDIO mode. It played
several times that afternoon. The runbook is xp-vm-route.md.

Other things I'm sure of because I've done them more than once:

- The SV-AV50 on its cradle shows up on Windows 11 as plain USB mass storage with no
  driver, as long as the dock conditions are met. VirtualBox passes the cradle through
  to an XP guest fine, CPRM traffic included.
- SD-Jukebox V4.0L40 installs on 64-bit Windows 11 from the export disc, offline, and
  builds its CPRM library locally, so the 2018 activation shutdown doesn't affect it.
  With the secure files in the right folders, the service path corrected, CDDB off and
  the app elevated, it runs and shows the card. Its Format refuses my 1 GB cards after
  reading only INQUIRY and SD_STATUS.
- SD-Jukebox V5.1 LE builds its CPRM library offline too, and in an XP guest it formats
  a 1 GB card and checks out to it.
- Two 1 GB Class 10 cards report `SIZE_OF_PROTECTED_AREA = 0` and can never hold
  SD-Audio. A pre-2006 1 GB card with no speed class reports 0x38 units and works.
- The camera's clips are MPEG-4 part 2 with G.726 audio in ASF, and ffmpeg can produce
  a file with the same stream layout.

## What works, but goes nowhere

SD-Jukebox V5.1 directly on Windows 11. Getting it to run takes an installer with its
Windows 2000/XP check widened, Smart App Control switched off, the SDPASVC service
path fix, and elevation. Then it runs, and at startup it sends 22 SCSI commands to the
cradle, all with good status, including secure reads of the card's protected area, and
stops before any authentication with no SD drive listed. Whatever it decides, it
decides inside its encrypted CPRM module, and I didn't look further than that. The
same card works with the same software in XP.

## What I haven't checked

- V4.0 with a 512 MB card, the size Panasonic tested with, directly on Windows 11. If
  that works, nobody needs the VM. I haven't bought one.
- Why V4.0 refuses the 1 GB card that does have a protected area. The 1 GB check is my
  best explanation, not a proven one.
- Which codec and bit rate the successful check-out actually used. AAC 128 kbps was
  what I set.
- Named playlists on the camera.
- The video route (video-route.md). One file encoded, never played.
- A second batch of six albums I checked out later on 2026-10-27 the same way. The
  camera failed before I could confirm they played; see below.
- VMware instead of VirtualBox, a 2 GB card, or any other card model.

## The camera right now

On the evening of 2026-10-27, after the music had been playing for a while, the camera
developed a hardware fault. First the record mode started hanging at power-on or when
taking a photo while playback modes still worked, then the whole unit stopped
responding: black picture with the on-screen display, buttons dead, with or without a
card, after a rest, with a battery that measures 4.16 V. It fails the same way with no
card in it, so the music and the card aren't the cause, and there's no firmware path
for the PC software to have touched. My guess is an age-related component failure in a
22-year-old unit, maybe brought on by hours docked and warm. The battery came out of
the hung camera warm, which points at a heavy current draw somewhere.

So nothing on the camera can be re-tested until it's repaired or I find another
SV-AV50. The card, the VM and the workflow carry over. The dates above are when things
were last seen working.

## What I ruled out on purpose

- Writing my own SD-Audio writer. It would need the licensed CPRM device keys inside
  SD-Jukebox's library, which means extracting keys from a licensed DRM module.
- Patching or bypassing anything inside SD-Jukebox's CPRM library, including its card
  checks, for the same reason. I traced V4.0's format call chain far enough to see that
  the card verdict comes from inside that encrypted module, and stopped.
- Publishing the installer's serial-number check or a generator for it.
- Making a 4 GB or larger card work. All of those are SDHC or SDXC, and the camera's
  2004 host controller can't initialise them.
- Patching the camera firmware. There's no update path.
- Ripping music I don't own for the card.

## Tools, in the order I wrote them

A USB arrival logger (not published; Device Manager does the job once you know what to
look for). An InstallShield 6 cabinet extractor with MD5 checks (not published;
libunshield exists). `Analyze-Minidump.py`, which found the recursive DLL load. A
DBWIN listener (not published; the plug-ins turned out to log nothing).
`Watch-PassThrough.ps1`, which found the zero protected area. `Read-SDStatus.ps1`, the
standalone version of that check. Process Monitor, which showed that V5.1 probes the
card only at startup, so attaching later sees nothing. And a launch-under-debugger
tracer for V5.1's startup dialogue, which I haven't tidied up enough to publish.
