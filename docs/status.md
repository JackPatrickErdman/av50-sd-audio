# Status

As of 2026-11-06.

## Verified

Music plays on the SV-AV50. On 2026-10-27 I imported an album I own into SD-Jukebox
V5.1 LE running in a Windows XP SP3 VirtualBox guest on a Windows 11 host, formatted a
1 GB CPRM-capable card from SD-Jukebox, checked the tracks out through the camera's
cradle passed through over USB, and the camera played them in [AUDIO] mode. Several
plays over that afternoon. Runbook: xp-vm-route.md.

Also verified, reproducibly:

- The SV-AV50 on its cradle enumerates on Windows 11 as plain USB mass storage with no
  driver, when the dock conditions are met. VirtualBox USB passthrough of the cradle to
  an XP guest works, CPRM traffic included.
- SD-Jukebox V4.0L40 installs on 64-bit Windows 11 from the export disc, offline, and
  builds its CPRM library locally. The 2018 activation shutdown does not affect it.
  With the secure files in the right folders, the service path corrected, CDDB off and
  the app elevated, it runs and shows the card. Its Format refuses my 1 GB cards after
  reading only INQUIRY and SD_STATUS.
- SD-Jukebox V5.1 LE also builds its CPRM library offline. In an XP guest it formats a
  1 GB card and checks out to it.
- Two 1 GB Class 10 cards report `SIZE_OF_PROTECTED_AREA = 0` and can never hold
  SD-Audio. A pre-2006 1 GB card with no speed class reports 0x38 units and works.
- The camera's clips are MPEG-4 part 2 with G.726 audio in ASF, and ffmpeg can produce
  a file with the same stream layout.

## Verified, and a dead end

SD-Jukebox V5.1 natively on Windows 11. It takes an installer whose Windows 2000/XP
check is widened, Smart App Control off, the SDPASVC service path fix, and elevation.
Then it runs and at startup sends 22 SCSI commands to the cradle, all with good status,
including secure reads of the card's protected area, and stops before any
authentication with no SD drive listed. The decision is inside its encrypted CPRM
module and I did not look further. The same card works with the same software in XP.

## Not verified

- V4.0 with a 512 MB card, the size Panasonic tested, natively on Windows 11. If that
  works, no VM is needed. I have not bought one.
- Why V4.0 refuses the 1 GB card that has a protected area. The 1 GB pre-check is my
  best explanation, not a proven one.
- Which codec and bit rate the successful check-out used (AAC 128 kbps intended).
- Named playlists on the camera.
- The video route (video-route.md): one file encoded, never played.
- A second batch of six albums checked out later on 2026-10-27 through the same VM
  route. The camera failed before I could confirm they played; see below.
- VMware instead of VirtualBox; a 2 GB card; a second card model.

## The camera, as of now

On the evening of 2026-10-27, after the music had been playing, the camera developed a
hardware fault. First the record (camera) mode hung at start-up or on taking a photo
while playback modes still worked, then the whole unit stopped responding: black
picture with the on-screen display, buttons dead, with or without a card, after a rest
and with a battery that measures 4.16 V. It fails exactly the same with no card in it,
so the music and the card are not the cause, and there is no firmware path for the PC
software to have touched. My guess is an age-related component failure in a 22-year-old
unit, possibly brought on by hours docked and warm. The battery came out of the hung
camera warm, which points at a heavy current draw somewhere.

So I cannot re-test anything on the camera until it is repaired or I find a second
SV-AV50. The card, the VM and the workflow carry over. The dates above are when things
were last verified.

## Ruled out on purpose

- Writing an SD-Audio writer of my own. It would need the licensed CPRM device keys
  inside SD-Jukebox's library. That is key extraction from a licensed DRM module. Not
  doing it.
- Patching or bypassing anything inside SD-Jukebox's CPRM library, including its card
  checks. Same reason. I traced V4.0's format call chain far enough to see that the
  card verdict comes from inside that encrypted module, and stopped there.
- Publishing the installer's serial-number check or a generator for it.
- Making a 4 GB or larger card work. All such cards are SDHC or SDXC; the camera's 2004
  host controller cannot initialise them.
- Patching the camera firmware. No update path exists.
- Ripping music I do not own for the card.

## Tooling, in order of appearance

A USB arrival logger (not published; Windows' own Device Manager does the job once you
know what to look for); an InstallShield 6 cabinet extractor with MD5 verification
(not published; libunshield exists); `Analyze-Minidump.py`, which found the recursive
DLL load; a DBWIN listener (not published; the plug-ins turned out to log nothing);
`Watch-PassThrough.ps1`, which found the zero protected area; `Read-SDStatus.ps1`, the
standalone version of that check; Process Monitor, which showed that V5.1 probes the
card only at startup so attaching later sees nothing; and a launch-under-debugger
tracer for the V5.1 startup dialogue, which I have not cleaned up for publishing.
