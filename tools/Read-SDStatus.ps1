# Read-SDStatus.ps1 — standalone, no SD-Jukebox needed. Run ELEVATED (any bitness).
# Opens the AV50 cradle's disk and sends the same two SCSI commands SD-Jukebox sends on
# Format: INQUIRY (12h, 58 bytes) and the Panasonic vendor "get SD_STATUS" (C1h, 65 bytes).
# Decodes SIZE_OF_PROTECTED_AREA: zero = the card has no CPRM area and can never hold SD-Audio.
# Output: console + read_sdstatus_log.txt next to this script. Read-only: nothing is written.
param([string]$Drive = 'D')
$log = Join-Path $PSScriptRoot 'read_sdstatus_log.txt'
function Say($s) { $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $s; Write-Host $line; Add-Content $log $line }
function Hex($b) { ($b | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' }

Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class Spt {
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  public static extern IntPtr CreateFile(string n, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr t);
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern bool DeviceIoControl(IntPtr h, uint code, IntPtr inb, uint inlen, IntPtr outb, uint outlen, out uint ret, IntPtr ov);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
  // SCSI_PASS_THROUGH_DIRECT laid out by hand (bitness-safe), followed by a 32-byte sense buffer.
  public static int PtrSize = IntPtr.Size;
  public static int OffDataBuffer = (IntPtr.Size == 8) ? 24 : 20;
  public static int OffSenseOffset = (IntPtr.Size == 8) ? 32 : 24;
  public static int OffCdb = (IntPtr.Size == 8) ? 36 : 28;
  public static int StructLen = (IntPtr.Size == 8) ? 56 : 44;
}
"@
$IOCTL_SCSI_PASS_THROUGH_DIRECT = 0x4D014

function Send-Cdb([IntPtr]$h, [byte[]]$cdb, [int]$xfer, [int]$timeoutSec = 10) {
    $senseLen = 32; $total = [Spt]::StructLen + $senseLen
    $buf = [Runtime.InteropServices.Marshal]::AllocHGlobal($total)
    $data = [Runtime.InteropServices.Marshal]::AllocHGlobal([Math]::Max($xfer, 1))
    try {
        for ($i = 0; $i -lt $total; $i++) { [Runtime.InteropServices.Marshal]::WriteByte($buf, $i, 0) }
        for ($i = 0; $i -lt $xfer; $i++) { [Runtime.InteropServices.Marshal]::WriteByte($data, $i, 0) }
        [Runtime.InteropServices.Marshal]::WriteInt16($buf, 0, [int16][Spt]::StructLen)   # Length
        [Runtime.InteropServices.Marshal]::WriteByte($buf, 6, [byte]$cdb.Length)          # CdbLength
        [Runtime.InteropServices.Marshal]::WriteByte($buf, 7, [byte]$senseLen)            # SenseInfoLength
        [Runtime.InteropServices.Marshal]::WriteByte($buf, 8, 1)                          # DataIn = SCSI_IOCTL_DATA_IN
        [Runtime.InteropServices.Marshal]::WriteInt32($buf, 12, $xfer)                    # DataTransferLength
        [Runtime.InteropServices.Marshal]::WriteInt32($buf, 16, $timeoutSec)              # TimeOutValue
        [Runtime.InteropServices.Marshal]::WriteIntPtr($buf, [Spt]::OffDataBuffer, $data)
        [Runtime.InteropServices.Marshal]::WriteInt32($buf, [Spt]::OffSenseOffset, [Spt]::StructLen)
        for ($i = 0; $i -lt $cdb.Length; $i++) { [Runtime.InteropServices.Marshal]::WriteByte($buf, [Spt]::OffCdb + $i, $cdb[$i]) }
        [uint32]$ret = 0
        $ok = [Spt]::DeviceIoControl($h, $IOCTL_SCSI_PASS_THROUGH_DIRECT, $buf, $total, $buf, $total, [ref]$ret, [IntPtr]::Zero)
        $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        $scsi = [Runtime.InteropServices.Marshal]::ReadByte($buf, 2)
        $got = [Runtime.InteropServices.Marshal]::ReadInt32($buf, 12)
        $sense = New-Object byte[] $senseLen; [Runtime.InteropServices.Marshal]::Copy([IntPtr]($buf.ToInt64() + [Spt]::StructLen), $sense, 0, $senseLen)
        $out = New-Object byte[] ([Math]::Max($xfer,1)); [Runtime.InteropServices.Marshal]::Copy($data, $out, 0, $out.Length)
        return @{ ok = $ok; err = $err; scsi = $scsi; got = $got; sense = $sense; data = $out }
    } finally {
        [Runtime.InteropServices.Marshal]::FreeHGlobal($buf); [Runtime.InteropServices.Marshal]::FreeHGlobal($data)
    }
}

$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole('Administrators')) { Say "NOT ELEVATED - SCSI pass-through needs admin. Aborting."; exit 9 }

Say "---- Read-SDStatus start (drive $Drive`:, $([Spt]::PtrSize*8)-bit) ----"
# Find the cradle's volume ourselves (the letter can move); fall back to -Drive.
$cradleDisk = Get-Disk -ErrorAction SilentlyContinue | Where-Object { $_.BusType -eq 'USB' -and $_.FriendlyName -match 'MATSHITA' } | Select-Object -First 1
if ($cradleDisk) {
    $part = Get-Partition -DiskNumber $cradleDisk.Number -ErrorAction SilentlyContinue | Where-Object DriveLetter | Select-Object -First 1
    if ($part) { $Drive = [string]$part.DriveLetter }
    Say ("cradle disk #{0} '{1}' {2:N0} bytes, volume {3}:" -f $cradleDisk.Number, $cradleDisk.FriendlyName, $cradleDisk.Size, $Drive)
} else {
    Say "NO CRADLE: no USB disk named MATSHITA is present. Dock the camera (AC in cradle, battery in, PLAY mode, cable last, LCD 'PC accessing') and rerun."
    exit 3
}
$vol = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$Drive`:'" -ErrorAction SilentlyContinue
if ($vol) { Say ("volume {0}: FS={1} label='{2}' serial={3} size={4:N0} free={5:N0}" -f $Drive, $vol.FileSystem, $vol.VolumeName, $vol.VolumeSerialNumber, $vol.Size, $vol.FreeSpace) }
else { Say "volume $Drive`: not found (no drive letter?); trying the handle anyway" }

$h = [Spt]::CreateFile("\\.\$Drive`:", 3221225472, 3, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)
if ($null -eq $h -or $h.ToInt64() -eq -1) { Say ("CreateFile failed, error {0}" -f [Runtime.InteropServices.Marshal]::GetLastWin32Error()); exit 2 }
try {
  try {
    $inq = Send-Cdb $h ([byte[]](0x12,0,0,0,0x3A,0)) 58
    Say ("INQUIRY: ok={0} err={1} ScsiStatus=0x{2:X2} got={3}" -f $inq.ok, $inq.err, $inq.scsi, $inq.got)
    Say ("  data: " + (Hex $inq.data))
    $txt = -join ($inq.data[8..57] | ForEach-Object { if ($_ -ge 32 -and $_ -lt 127) { [char]$_ } else { '.' } })
    Say ("  text: '$txt'" + $(if ($txt -match 'SDSECAPI') { '  <<< cradle advertises SD Secure API' } else { '  <<< NO SDSECAPI string' }))

    $st = Send-Cdb $h ([byte[]](0xC1,0,0,0,0x41,0)) 65
    Say ("SD_STATUS (C1): ok={0} err={1} ScsiStatus=0x{2:X2} got={3} sense={4}" -f $st.ok, $st.err, $st.scsi, $st.got, (Hex $st.sense[0..17]))
    Say ("  data: " + (Hex $st.data))
    if ($st.ok -and $st.got -ge 16) {
        $d = $st.data
        $busWidth = ($d[0] -shr 6); $secured = ($d[0] -shr 5) -band 1
        $cardType = ($d[2] -shl 8) -bor $d[3]
        $prot = ([uint32]$d[4] -shl 24) -bor ([uint32]$d[5] -shl 16) -bor ([uint32]$d[6] -shl 8) -bor [uint32]$d[7]
        $speed = $d[8]; $perf = $d[9]; $au = ($d[10] -shr 4)
        Say ("  DAT_BUS_WIDTH={0} SECURED_MODE={1} SD_CARD_TYPE=0x{2:X4} SPEED_CLASS={3} PERFORMANCE_MOVE={4} AU_SIZE={5}" -f $busWidth, $secured, $cardType, $speed, $perf, $au)
        Say ("  SIZE_OF_PROTECTED_AREA = 0x{0:X8} ({0} units)" -f $prot)
        if ($prot -eq 0) { Say "  VERDICT: NO protected area. This card has no CPRM region; SD-Jukebox will never format it for SD-Audio. Wrong card." }
        else { Say "  VERDICT: protected area present. CPRM-capable card; the Format failure is somewhere else (layout or app)." }
    } else { Say "  C1 command failed or short reply; the cradle may not be in PC mode, or the handle is wrong." }
  } catch { Say ("EXCEPTION: " + $_.Exception.ToString()) }
} finally { [Spt]::CloseHandle($h) | Out-Null }
Say "---- done ----"

