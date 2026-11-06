# The route that works: SD-Jukebox V5.1 in an XP virtual machine

Tested on 2026-10-27 on a Windows 11 Pro 25H2 (build 26200) laptop with the SV-AV50
on its cradle and a 1 GB CPRM-capable standard SD card. Result: the album checked out
and plays on the camera in [AUDIO] mode. This is the only route in this project that
got music onto the camera.

Windows 11 is the host and does nothing but run the VM and pass the cradle through.
Everything Panasonic runs inside a 32-bit Windows XP SP3 guest, the OS SD-Jukebox was
written for.

## Why a VM after all the native work

Both native routes stop short (windows11-runbook.md). V4.0 refuses a 1 GB card before
sending any CPRM command. V5.1 reads the card's protected area and then declines to
go on. The same card, cradle and V5.1 package inside XP worked first time, so whatever
V5.1's CPRM module dislikes about Windows 11, XP doesn't set it off.

## What you need

- Windows XP Professional or Home, SP3, 32-bit: install media and a licence you own.
  This repository doesn't provide or point to either.
- VirtualBox 7.x, free, from virtualbox.org. I used 7.2.22. VMware Workstation, free
  for personal use since 2024, should work too and has a published D-snap precedent
  (background.md); I haven't tried it. Hyper-V is out: an XP guest must be Generation
  1, which has no USB passthrough.
- SD-Jukebox V5.1 LE from the archive.org item `panasonic-sd-jukebox-v-5.1`, a
  multilingual LE package (English included) whose device list has `SV-AV50/AV25`.
  You need a serial; use one you are entitled to.
- A CPRM-capable standard SD card, 2 GB or less (protected-area.md). Check it first on
  the host with `tools/Read-SDStatus.ps1`: `SIZE_OF_PROTECTED_AREA` must be non-zero.
- The camera, its cradle, the cradle's AC adaptor, and a charged battery.

## 1. Create the VM

| Setting | Value | Why |
|---|---|---|
| Type / version | Windows XP (32-bit), skip unattended install | |
| Memory / CPU | 1024 MB, 1 vCPU | XP guests misbehave with more than one |
| Disk | 10 GB on the default IDE (PIIX4) controller | XP has no SATA/AHCI driver |
| Network | disabled, or cable disconnected | XP gets no security updates; nothing here needs a network |
| USB | USB 2.0 (OHCI + EHCI) | XP has no xHCI driver; the host can be all USB 3, VirtualBox proxies the device |
| USB filter | vendor `04DA`, product `23D3` | hands the cradle to the guest automatically |

With virtualization-based security (Memory Integrity) on in Windows, VirtualBox falls
back to its slower Hyper-V-compatible path, shown as a turtle icon in the status bar.
If the guest crawls, that setting is the usual cause. The XP install and SD-Jukebox
were usable for me as the laptop came.

From the command line, the non-default parts are:

```
VBoxManage modifyvm "XP-SDJukebox" --nic1 none
VBoxManage usbfilter add 0 --target "XP-SDJukebox" --name "AV50 cradle" --vendorid 04DA --productid 23D3
```

## 2. Install XP

Attach your XP media to the VM's CD drive, boot, quick-format NTFS, enter your key,
skip the network and Internet steps. After the first reboot don't press a key at
"Press any key to boot from CD", or setup starts over. Take a snapshot at the desktop.

## 3. Get SD-Jukebox and the music into the guest

With no network, use a CD image. Build an ISO on the host with the extracted V5.1
package and your album in it, and attach it to the VM's CD drive in place of the XP
media. On Windows the built-in IMAPI2 COM object can write an ISO9660/Joliet image
with no extra tools; any ISO tool works.

Inside XP: copy the music to the guest's disk, run the unmodified `Setup.exe` (XP
passes its OS check), choose English, enter your serial, accept the defaults (data
folder `C:\Panasonic\Data\SD-JukeboxV5`). Take a second snapshot before the first
launch, in case the 2018 activation question comes up. It didn't: V5.1 builds its CPRM
library offline, the same way V4.0 does.

None of the Windows 11 workarounds are needed in XP: no DLL relocation, no service
path fix, no elevation layer, no Smart App Control.

Later I automated the delivery: a script on the host that takes an album folder,
refuses anything DRM-protected, converts owned non-MP3 audio to MP3, tags it, builds an
ISO, hot-swaps it into the running VM's CD drive and types a loader command into the
guest. It's tied to my folder layout and isn't in this repo. Import, playlist and
the transfer itself are still manual in SD-Jukebox either way.

## 4. Dock and check out

1. Card in the camera, camera on the cradle with AC and battery, PLAY mode, USB cable
   last. With the VM running, VirtualBox captures the cradle (it disappears from the
   host) and XP installs it as a USB mass-storage drive by itself.
2. Start SD-Jukebox. The device bar shows an SD drive and the transfer pane shows the
   card's size (952 MB total on my 1 GB card). If not, quit, check the camera says
   "PC accessing", and start it again: the app probes cards only at startup.
3. Options, SD tab: Portable Device SV-AV50/AV25. Set the MP3 conversion to AAC
   128 kbps; the camera's recommended rates are 64, 96 and 128 kbps and typical MP3s
   are higher.
4. Import the album. Format the card from SD-Jukebox, not from Windows: only
   SD-Jukebox lays out the SD-Audio structures and the protected-area keys.
5. Select the tracks, or a User playlist in album order, and press start. Wait for the
   camera's access lamp to stop. Quit, undock, switch the camera to [AUDIO].

## 5. On the camera

- Tracks appear in one index, which is the camera's DefaultPlaylist.
- Named playlists are chosen in the AUDIO playback menu under [Playlist] (manual
  pages 19 and 29). To get one, build a User playlist in SD-Jukebox with "Create
  playlists on SD card" ticked and check it out. I haven't verified this on the camera.
- The manual warns that titles, artists or playlist names may not always display.

## Battery warning

The camera doesn't run reliably on cradle AC without the battery, and it charges only
while switched off. After hours docked in PC mode my 20-year-old battery went flat and
the camera hung with a solid red lamp and a black screen. Charge fully before a long
session, and take the camera off the cradle with the LCD closed afterwards.

## Not verified

- Which codec and bit rate the first check-out actually used. AAC 128 kbps was the
  intended setting; I didn't read the files back.
- Named playlists on the camera.
- A 512 MB card, a 2 GB card, a second card model, or VMware instead of VirtualBox.
