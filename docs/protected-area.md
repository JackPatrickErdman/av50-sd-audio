# Why "Format failed": modern SD cards have no CPRM protected area

## Symptom

With the library loaded and `SD(D:)` showing in SD-Jukebox V4.0 on Windows 11,
dragging tracks to the card produced "Different file system. Open the settings and
format SD." The app's own Format then failed instantly with "Format failed." and wrote
nothing. The card was a 1 GB Class 10 standard SD, the card I had been using for photos.

Things that changed nothing: a Windows quick-format to FAT16 with 16 KB clusters;
shrinking the volume to 500 MB to rule out a 1 GB limit; a `chkdsk` repair of the
card's FAT, which turned out to be cross-linked anyway.

## Investigation

1. Process Monitor. On Format, the app obtains a read/write handle to the volume
   through `sdpasvc`, issues exactly two `IOCTL_SCSI_PASS_THROUGH_DIRECT` calls (both
   succeed at the OS level), looks for `SD_AUDIO\`, and gives up. No dismount, no raw
   write, no access denied. Windows refused nothing.
2. USB event tracing showed the 31-byte command blocks on the wire but not their
   contents.
3. `tools/Watch-PassThrough.ps1`, written for this: a short attach debugger in
   PowerShell and C# that puts an `int 3` on `kernel32!DeviceIoControl` inside the
   32-bit elevated `sd-jukebox.exe`, reads the `SCSI_PASS_THROUGH_DIRECT` structure
   from the caller's stack, single-steps over the original instruction, and on return
   dumps the SCSI status, the sense data and the data buffer. It detaches cleanly so
   the app survives.

## The two commands

| CDB | Meaning | Reply |
|---|---|---|
| `12 00 00 00 3A 00` | INQUIRY, 58 bytes | `MATSHITA SD Multi Camera 0100` plus the vendor bytes `SDSECAPI`: the cradle advertises Panasonic's SD Secure API, so the secure path is real |
| `C1 00 00 00 41 00` | Panasonic vendor "get SD_STATUS", 65 bytes | the card's SD_STATUS register, below; SCSI status 0, no sense |

The reply to `C1` is the card's 512-bit SD_STATUS register, as defined in the SD
Physical Layer specification. The first 16 bytes from my first card:

```
80 00 00 00  00 00 00 00  04 02 70 00  01 05 00 00
```

| Field | Bytes | Value | Meaning |
|---|---|---|---|
| DAT_BUS_WIDTH | 0, bits 7-6 | 10 | 4-bit bus |
| SECURED_MODE | 0, bit 5 | 0 | not in secured mode |
| SD_CARD_TYPE | 2-3 | 0x0000 | regular read/write card |
| SIZE_OF_PROTECTED_AREA | 4-7 | 0x00000000 | no protected area |
| SPEED_CLASS | 8 | 4 | Class 10 |
| PERFORMANCE_MOVE | 9 | 2 | 2 MB/s |
| AU_SIZE | 10, high nibble | 7 | 4 MB |
| ERASE_SIZE | 11-12 | 1 | |

## Verdict

A Class 10 card is a post-2010 part, and this one was made with no CPRM protected area
at all. Zero protected area means there's nowhere to put the title keys, so SD-Jukebox
refuses to format or check out, and it's right to. For this card, nothing about
Windows 11 was in the way.

A second 1 GB card, bought as a replacement and sold as an older branded part, failed
Format the same way. Its register, read with `tools/Read-SDStatus.ps1`, is identical:
Class 10, `SIZE_OF_PROTECTED_AREA = 0`. "Branded" and "1 GB" tell you nothing about
when a card was made.

## A card that does have the area

A third 1 GB standard SD card reports this:

```
80 00 00 00  00 00 00 38  00 00 00 00  00 00 00 00
```

`SIZE_OF_PROTECTED_AREA = 0x38` (56 units), and SPEED_CLASS, PERFORMANCE_MOVE and
AU_SIZE all zero. No speed class at all is itself the tell of a card older than the
speed-class era, so roughly pre-2006. This card:

- V4.0 on Windows 11: still "Format failed", after the same two commands and no CPRM
  command (windows11-runbook.md, section 6).
- V5.1 on Windows 11: no SD drive listed, after 22 commands including secure reads of
  this very area (windows11-runbook.md, section 7).
- V5.1 in an XP guest: formats, checks out, and the camera plays the result
  (xp-vm-route.md).

So the zero-area finding explains the first two cards completely, and the third card
shows the other half of the problem: with a card that has the area, what remains is
whether the SD-Jukebox build accepts it on the OS it's running on.

## What card to use

- Standard SD, 2 GB or less. Not SDHC, which the camera can't initialise.
- Made by a licensed maker in the CPRM-mandatory era, roughly 2004 to 2009: Panasonic
  RP-SD series, SanDisk SDSDB-512 / SDSDB-1024 / SDSDB-002G, Toshiba, Kingston, Lexar
  of that era.
- 512 MB to 1 GB. The camera manual's tables stop at 512 MB; V4.0 refused my 1 GB
  cards and V5.1 accepted one in XP. 2 GB is within the camera's limit but I haven't
  tried one.
- No speed-class marking on the label. A Class 10, U1 or "C" circle means a post-2010
  part. Avoid anything marked "Non-CPRM", and the unbranded "1 GB / 2 GB Class 4 SLC"
  cards sold online, which are the same no-CPRM category.
- Cards pulled from old Panasonic phones, Lumix cameras or D-snaps are good candidates.

## Verify before you buy twice

`tools/Read-SDStatus.ps1`, run elevated with the camera docked in PC mode, sends the
same INQUIRY and `C1` command to the cradle without SD-Jukebox and prints
`SIZE_OF_PROTECTED_AREA`. It's read-only. Non-zero means the card can hold SD-Audio;
zero means no software will ever make it work. There's no PC-side bypass for a
missing area: the card controller enforces it, and the camera reads its keys from it.
