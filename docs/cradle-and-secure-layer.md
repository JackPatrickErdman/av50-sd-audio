# The cradle and the secure layer

Everything here was read from the AV50 export disc (archive.org item
`panasonic-svav50-vff0217`, file `SV_AV25_50.ISO`, MD5 `c6998cabc7bbb771db60087329fea870`,
inventory read first from archive.org's ISO browser and then from a hash-verified
download) and confirmed live on Windows 11 in October 2026. Nothing from the disc is
redistributed here.

## Getting the camera into PC mode

The camera enters PC mode only when all of these hold, in this order:

1. Camera off, seated on the cradle.
2. AC adaptor plugged into the cradle's DC-in, and the battery fitted. The manual is
   explicit that both are required.
3. Camera on, mode switch at PLAY. There is no USB menu item; USB mode engages by
   itself when the cable is detected in PLAY mode.
4. USB cable plugged in last, straight into a PC port, no hub.

The LCD is the diagnostic. "PC accessing" means PC mode. "Set to PLAY mode" or
"Connect AC adaptor and battery" means the cable is seen and the message tells you what
is missing. No reaction at all means no 5 V is reaching the camera: reseat it, clean
the contacts, try another cable (a charge-only lead shows exactly this) and another
port. Charging happens with the camera off, so a cradle that charges fine proves only
the power pins.

My first attempt showed nothing on the USB bus at all, and I spent a day reading about
drivers before going back to the manual and meeting all four conditions. Then it
enumerated at once. A silent bus is power, mode or cable, not a driver.

## What Windows 11 sees, with no Panasonic software

| Layer | Value |
|---|---|
| USB device | `USB\VID_04DA&PID_23D3&REV_0100`, compatible IDs `USB\Class_08&SubClass_06&Prot_50` (Mass Storage, SCSI transparent, Bulk-Only) |
| Driver | Microsoft inbox `usbstor.inf` |
| Disk | `USBSTOR\DiskMATSHITASD_Multi_Camera_0100`, "MATSHITA SD Multi Camera USB Device", inbox `disk.inf` |
| INQUIRY reply | `MATSHITA SD Multi Camera 0100` followed by the vendor string `SDSECAPI` |
| Volume | the card, FAT16, removable, with the camera's `DCIM`, `MISC`, `SD_VOICE` and `SD_VIDEO` folders |

Windows opens the folder on its own. No Panasonic software is involved.

The Panasonic SD-USB family, from the INFs embedded in the SD-Jukebox V4 package. No
public USB ID database (usb.ids, the Linux `unusual_devs.h`, the usual lookup sites)
has any of the D-snap entries.

| Device | USB ID | INF |
|---|---|---|
| SV-AV50 | 04DA:23D3 | `svav50u.inf` |
| SV-AS10 | 04DA:23D2 | `svas10u.inf` |
| Panasonic SD USB R/W (BN-SDC series) | 04DA:1B01 | `meisdusb.inf` |
| Panasonic SD USB R/W, Mitsumi-built | 03EE:6414, 03EE:6424 | `meisdusb.inf` |
| SV-AV100 (a different design, see below) | 04DA:2411 | `av100u.inf` |

## The "secure driver" is user-mode code

The disc's "USB Driver" package has two halves.

For Windows 98SE/Me it carries a Panasonic mass-storage class driver,
`SDUSBSTO.sys` ("SD Memory Card USB R/W WDM Driver", 2001), because 98SE shipped
none, plus a 9x port driver. The install section is literally named `USBSTOR_BULK`.
This half is never used on 2000/XP or later.

For 2000/XP, component "2000SDA", it carries `sdpaums.dll`, `SDDEVMGR.dll`,
`sdpasvc.exe` and `sdsrvctl.exe`. There is no kernel driver in this half. This is what
SD-Jukebox needs for CPRM, and this is why the AV50 behaves differently from
Panasonic's card readers (kernel drivers, 32-bit only, unsigned, dead on x64) and from
the SV-AV100 (a Hitachi-written vendor USB driver plus a virtual SCSI miniport, also
unsigned and x86 only).

How the pieces talk, from the imports and strings of the binaries:

```
sd-jukebox.exe
  SDCore.dll / SDCardMgr.dll / SDFileSys.dll / SDAudioCheckOut.dll / NSecureDB.dll / SDCprm.dll
    SDDEVMGR.dll          Toshiba "SD Card Manager API Library" (2000)
      loads plug-ins:     <SystemDir>\sda\SD*.dll   (skips only <SystemDir>\sddevmgr.dll)
      sdpaums.dll         Matsushita "SD Secure API DLL for Device Manager" (2001)
        exports DDReadMKB / DDSecureIdentify / DDSecureRead / DDSecureWrite
        talks over the named pipe \\.\pipe\sdphysrv to
        sdpasvc.exe       Windows service SDPASVC, runs as LocalSystem
          opens \\.\PhysicalDriveN or \\.\X: and issues
          IOCTL_SCSI_PASS_THROUGH_DIRECT to the USBSTOR disk
```

Every one of these is 32-bit user-mode code, which WOW64 runs on 64-bit Windows.
`sdpaums.dll` imports only kernel32. Version strings: `sdpaums.dll` 1.00.1.0062,
`sdpasvc.exe` 1.00.0.0008, `SDDEVMGR.dll` 1.0.1.10228 (Toshiba), all from 2000 and
2001. The same trio shipped with Panasonic's BN-SDC USB readers of that era, which is
why the file names are shared. The V5.1 LE package carries byte-identical copies.

## The CPRM key library is generated locally

The SD-Jukebox V4.0 installer runs `Cfg.exe` (imports only kernel32, so it cannot use
the network) against a 5 MB opaque blob on the disc called `SDCpA` and a per-machine
file `HO`, checks a hash, and writes `SDCprm.dll` into
`Common Files\Panasonic\SDApf\`. That is the per-machine CPRM library bound to the PC,
the piece the manual's "CPU and hard disk identity" warning refers to, and the piece
later versions fetched online at first launch. On the V4.0 disc it never touches the
network. In practice the install completed offline and the library appeared, about
1.7 MB. The V5.1 LE installer does the same with a 26 MB `SDCpA` and produced a
1.3 MB `SDCprm.dll`.

The `.text` section of the resulting `SDCprm.dll` has an entropy of about 7.97 bits
per byte, so it is encrypted or packed. Everything that decides whether a card is
acceptable runs inside it. I did not open it.

## SD-Jukebox V4.0L40 package facts

The export disc's SD-Jukebox is build V4.0L40, files dated 2004-03-26, English,
French and German, product GUID `{82625564-5A7A-11D7-AECE-00105A5D0C38}`. From its
InstallShield 6 header and the unpacked files:

- A 32-bit MFC application; DirectShow filters for decrypt, read and encode; the SD
  layer above; Gracenote CDDB; the Windows Media Format 9 redistributable; the Intel
  IPP runtime.
- The only kernel driver in the whole package is `audsub3.sys`, an NEC helper for CD
  digital audio extraction. It does not load on x64 and has nothing to do with card
  check-out.
- `Device.ini` has an `SV-AV50/AV25` profile: `CodecFlg=6` (MP3 and AAC, no WMA),
  default output AAC.
- The installer asks for a serial number from the CD case, has an OS check that is a
  continue-anyway prompt on anything that is not 2000/XP, and stores the serial in
  `HKLM\Software\CNC\SD-JukeboxV4\Settings`. The application reads that value back
  for its About box and never re-validates it.
- It registers `sdpasvc.exe -service` as the service `SDPASVC`, installs the secure
  files, and runs `Cfg.exe` as above.
- Its release note says the package contains the 1999 "Intel Software Integrity
  System" tamper layer. In practice V4.0 did not object to Windows 11.
- The still-live English updater (V4.0L20/L40 to V4.0L60 LE) fixes MP3 import and
  check-out failures. The 1 GB card fix is only in the Japanese V4.1 LE differential,
  which does not apply to the export build. I applied neither.

## SD-Jukebox V5.1 LE package facts

From the archive.org package (multilingual, English included, release notes dated
2006-03-03, build V5.1 L014 LE): the same offline CPRM build (`Cfg.exe` and `SDCpA`),
the same secure trio byte-identical to the AV50 disc, `Device.ini` lists
`SV-AV50/AV25` with AAC default, a card-watcher helper `SDResidence.exe`, and the only
URL in the package is an update-check XML on a host that no longer exists. No
activation step. The readme warns against installing older versions over 5.1 and
against reusing V4's folder.
