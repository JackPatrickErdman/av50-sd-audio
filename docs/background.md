# Background

## The camera

The Panasonic SV-AV50 is a 2004 "D-snap" SD hybrid: 1.2 MP stills, MPEG-4 video in
ASF, voice memos, and an [AUDIO] mode that plays music. It takes standard SD cards
only (SD 1.x/2.0, 2 GB at most); it predates SDHC and can't initialise an SDHC card.
It comes with a cradle that provides charging, USB and composite AV-out, and on the
Japanese model AV-in too. The camera has no USB socket of its own.

## What the manual settles about music

From the US operating instructions (pages 28, 43, 45, 52, 61, 63):

- [AUDIO] mode plays MPEG-2 AAC and MP3, recommended at 64, 96 or 128 kbps. No WMA.
- Only tracks transferred with the bundled SD-Jukebox Ver.4 play. Files copied to the
  card "may not playback properly or at all". The camera can't record or delete
  tracks itself.
- Music lives in the hidden folder `SD_AUDIO\` as `AOB001.SA1` and so on. The card's
  "missing" capacity is the CPRM protected area.
- SD-Jukebox V4 requirements: Windows 98SE / Me / 2000 / XP, DirectX 9.0b, Windows
  Media Format 9, a serial number printed on the CD case, a CD-ROM drive with digital
  audio extraction. Licensed from ARIS, SOLANA and 4C (4C is the CPRM licensing body).
- The PC-side library is encrypted and bound to the CPU and hard-disk identity. Swap
  either and the library is lost; cards already checked out keep playing.
- MP3s made elsewhere go in through SD-Jukebox's Import function.

So there's no DRM-free music mode on this camera. Later D-snap audio players with a
line-in had a plain-MP3 folder trick; the AV50 doesn't.

## How SD-Audio works, and why there's no third way

Sources: Matsushita patent US7930478B2, the 4C CPRM specifications, the SD
Association's pages, the Realtek CPRM pass-through code in the Linux staging tree.

- The user area (`SD_AUDIO\`) holds `AOBxxx.SA1` audio objects, each encrypted with
  its own title key, plus `SD_AUDIO.PLM` (playlist manager) and `SD_AUDIO.TKM` (track
  manager). Limits: 999 tracks, 99 playlists.
- The protected area, hidden and enforced by the card controller, holds `AOBSA1.KEY`,
  one encrypted title key per track. It can only be reached after mutual
  authentication (AKE) between the host software and the card.
- The card's system area holds the Media ID and the Media Key Blocks (MKB). The host
  processes the MKB with its licensed secret device keys to derive the media key, then
  authenticates to the card. The cipher is 4C's C2 (56-bit key). The SD security
  command set is in SD Part 3, which is NDA-only.
- Over USB, the reader or camera stays a class-compliant mass-storage device and
  accepts vendor-specific SCSI pass-through commands that tunnel raw SD commands. The
  AKE runs in the host software against the card through that tunnel. The Linux
  driver for Realtek readers shows this shape in public source; Panasonic's own
  opcodes aren't public.

Consequences:

- Any card reader shows the user area. Only a device whose firmware tunnels SD
  security commands, plus Panasonic's host-side secure layer, plus the licensed device
  keys inside SD-Jukebox, can write SD-Audio.
- No open-source or third-party SD-Audio writer exists. The Linux kernel has only raw
  CPRM pass-through for Realtek readers. The device keys have never leaked, unlike DVD
  CPRM. The licensed third-party writers (Toshiba Audio Manager, MOOCS PLAYER,
  SD-MobileImpact) are all discontinued and had the same requirements.
- Every SD-Jukebox version from 1 to 7 writes only CPRM check-outs. "Do not convert"
  keeps the codec but still encrypts. There's no unencrypted output mode.
- The card must have a CPRM protected area. CPRM was mandatory on every SD card until
  SD specification 6.10 in March 2018, but in practice many cards made after about
  2010 ship with a zero-size protected area. A card with none can't be made to work by
  any software, because the camera reads the title keys from that area at playback.

## Why the camera itself is the enforcer

A "bypass" on the PC side doesn't exist because the PC side isn't where the check
happens. The card controller hides and unlocks the protected area; the camera firmware
reads the keys from it and decrypts the audio. Faking either would need the licensed
device keys (and still a card with the area), or a firmware patch for a 2004 SoC with
no update path. I didn't go down either road.

## The SV-AV50 is an official writer

Panasonic's SD-Jukebox V4 operating-environment page lists "SD audio devices: SV-AS10,
SV-AV50, SV-AV35, SV-AV30", each needing its bundled dedicated driver. The SD-Audio
device list gives the SV-AV50 a tick for AAC, MP3, MP3 VBR and "USB card reader/writer
function". So the cradle is a supported check-out target, not a hack.

## SD-Jukebox versions

| Version | Release | Official OS | Notes |
|---|---|---|---|
| 1.x, 2.x | 2000 | 98 to XP (2.3+) | |
| 3.0 | 2002 | 98SE to XP | bundled with SV-AV30 |
| 4.0 / 4.1 | 2003 / 2004 | 98SE, Me, 2000, XP | 4.0 LE bundled with the SV-AV50; the Japanese 4.1 update adds a "some 1 GB cards not recognised" fix; export discs got no 4.1 |
| 5.0 to 5.3 | 2005 | 2000, XP | installer refuses anything newer; "64-bit not supported" |
| 6.0 to 6.95 | 2006 to 2009 | 2000, XP, Vista, 7 (32-bit) | first launch may download a module (dead since 2018) |
| 7.x | 2010, 2013 | XP to 8.1 | car-navigation bundle only |

Download sales ended 2016-09-30, support ended 2017-12. From April 2018 Panasonic
stopped distributing the "security program for copyright protection" that newer
versions fetch at first launch, and warns that a new install may then fail to start.
The V4 manual has no such step, and on both the V4.0 and V5.1 discs the CPRM library
is generated locally by the installer (see cradle-and-secure-layer.md). Panasonic
states that SD-Jukebox doesn't run on Windows 10 and never mentions Windows 11.

## Every published attempt I found

As of October 2026. None involves the SV-AV50, and none has Windows 11 working.

| Who / when | Software | OS | Writer | Result |
|---|---|---|---|---|
| subiebear.com, 2023 | V6.95 LE (used CD) | native 32-bit Windows 7 and Windows 10 1507 LTSB | BN-SDCGP3 / BN-SDCJP3 readers with their CD driver | works; V5.1 LE refused anything newer than XP even in compatibility mode |
| blog.wurlyhub.com, 2024 | V6.95 | Windows 10 64-bit host, VirtualBox, Windows 7 guest | BN-SDCMP3 passed through | works: CPRM traffic survives VirtualBox USB passthrough |
| archive.org uploader, 2023 | V6.0 LE | Japanese XP SP3 in VMware 15.5 | SV-SD800N player itself over USB | works: a player on USB is a valid writer inside a VM |
| isobe.exblog.jp (site down) | ? | Windows 7 XP Mode | SD-Audio device via XP Mode USB | card seen; laborious. Second-hand |
| Yahoo Chiebukuro, 2023 | ? | native Windows 11 | Panasonic CPRM reader | fails at the SD write step |
| Yahoo Chiebukuro, undated | ? | Windows 10 | SV-SD400V | Windows sees the card, SD-Jukebox doesn't |

The successes have three things in common: 32-bit Windows no newer than 7, native or
in a VM; a Panasonic CPRM device on USB; an install from CD. Mine fits: XP in a VM, the
camera's own cradle as the device, an archived CD image.

## Sources

- archive.org, the SV-AV25/AV50 export software disc: https://archive.org/details/panasonic-svav50-vff0217
- archive.org, SD-Jukebox V5.1 LE (multilingual): https://archive.org/details/panasonic-sd-jukebox-v-5.1
- archive.org, SD-Jukebox V6.0 LE in an XP VM with a D-snap player: https://archive.org/details/panasonic-sd-jukebox-v-6.0-le-jpn-version
- archive.org, SV-AV100 USB driver package: https://archive.org/details/svav-100-firmware-japan
- Panasonic SD-Jukebox version/OS matrix: https://av.jpn.support.panasonic.com/support/software/sdjb/prod/versions.html
- Panasonic V4 operating environment (SV-AV50 listed as writer): https://av.jpn.support.panasonic.com/support/software/sdjb/prod/v4/env.html
- Panasonic SD-Audio device list: https://av.jpn.support.panasonic.com/support/software/sdjb/connect/sd_audio.html
- Panasonic 2018 shutdown notices: https://av.jpn.support.panasonic.com/support/software/info/sdjb_notice.html and https://av.jpn.support.panasonic.com/support/software/info/sdjb_notice3.html
- Panasonic V4 updaters: https://av.jpn.support.panasonic.com/support/global/cs/soft/download/sdjupV40L60.html and https://av.jpn.support.panasonic.com/support/software/sdjb/download/v41LEsabun.html
- Panasonic global FAQ (D-snap uses the CD driver): https://av.jpn.support.panasonic.com/support/global/cs/soft/faq/sdjuke_answer.html
- Panasonic "do not install in compatibility mode": https://av.jpn.support.panasonic.com/support/software/sdjb/faq/top10/top10_3.html
- Panasonic Windows 10 statement: https://av.jpn.support.panasonic.com/support/info/win10/index.html
- Panasonic SV-AV50 product and FAQ pages: https://av.jpn.support.panasonic.com/support/d_snap/product/sv_av50.html and https://av.jpn.support.panasonic.com/support/d_snap/faq/sv_av50.html
- SD-Jukebox V4 manual (Japanese PDF): https://panasonic.jp/manualdl/p-db/sd/sd_jukeboxv4.pdf
- SD-Jukebox V6 manual (first-launch module download): https://panasonic.jp/manualdl/p-db/sd/sd_jukeboxv6.pdf
- Matsushita patent on SD-Audio structures, US7930478B2: https://patents.google.com/patent/US7930478B2/en
- 4C CPRM Introduction and Common Cryptographic Elements rev 1.10: https://wiki.hackmanhattan.com/images/3/31/Cprm-base110-20101215.pdf
- 4C CPRM SD binding part: https://static.wikitide.net/keitaiwikiwiki/1/17/Cprm-sd-bind-part-092-2005-1212.pdf
- Realtek CPRM pass-through, Linux staging: https://raw.githubusercontent.com/torvalds/linux/v3.10/drivers/staging/rts5139/sd_cprm.c
- LKML 2007, no open-source CPRM: https://lkml.iu.edu/hypermail/linux/kernel/0707.3/2629.html
- SD Association, content protection: https://www.sdcard.org/developers/sd-standard-overview/content-protection/
- subiebear, SD-Jukebox on Win7 / Win10 1507 (2023): https://subiebear.com/2023/11/01/sd-jukebox/
- wurlyhub, VirtualBox Win7 guest with BN-SDCMP3: https://blog.wurlyhub.com/2024/02/12/post-1112/
- Chiebukuro, Windows 11 failure (2023): https://detail.chiebukuro.yahoo.co.jp/qa/question_detail/q14289628614
- Chiebukuro, SV-SD400V on Windows 10: https://detail.chiebukuro.yahoo.co.jp/qa/question_detail/q12320318547
- Hyper-V Generation 1 has no USB passthrough: https://learn.microsoft.com/en-au/answers/questions/5807924/win-11-hypervisor-vm-has-borked-interoperability
- VirtualBox 7.0 changelog (EHCI/xHCI in the base package): https://www.virtualbox.org/wiki/Changelog-7.0
- VirtualBox XP guests slow under Hyper-V / VBS: https://forums.virtualbox.org/viewtopic.php?t=110712
- D-snap and SD-Jukebox wiki (Japanese): https://wikiwiki.jp/dsnap/SD-Jukebox%E9%96%A2%E9%80%A3
