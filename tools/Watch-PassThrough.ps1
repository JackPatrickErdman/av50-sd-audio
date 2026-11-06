# Watch-PassThrough.ps1 — run in 32-bit PowerShell, ELEVATED (the target is elevated). Attaches
# a tiny debugger to sd-jukebox.exe, breakpoints kernel32!DeviceIoControl, and for every
# IOCTL_SCSI_PASS_THROUGH_DIRECT prints the CDB, direction and length, then on return prints
# ScsiStatus, the sense bytes and the first bytes of the data buffer. Detaches when -Seconds elapse
# (DebugSetProcessKillOnExit(false), so the app survives). Output: passthrough_log.txt next to this script.
# Note: SD-Jukebox V4.0 sends its card commands when you click Format, so this catches them. V5.1
# probes the card once at startup and never again, so attaching to V5.1 afterwards sees nothing.
param([int]$Seconds = 75)
$log = Join-Path $PSScriptRoot 'passthrough_log.txt'
function Say($s) { $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $s; Write-Host $line; Add-Content $log $line }
if ([Environment]::Is64BitProcess) { Say "must run in 32-bit PowerShell"; exit 9 }
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class Dbg {
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool DebugActiveProcess(uint pid);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool DebugActiveProcessStop(uint pid);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool DebugSetProcessKillOnExit(bool kill);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool WaitForDebugEvent(IntPtr ev, uint ms);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool ContinueDebugEvent(uint pid, uint tid, uint status);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint a, bool i, uint pid);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenThread(uint a, bool i, uint tid);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr h, IntPtr a, byte[] b, int n, out int r);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool WriteProcessMemory(IntPtr h, IntPtr a, byte[] b, int n, out int w);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool FlushInstructionCache(IntPtr h, IntPtr a, uint n);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetThreadContext(IntPtr t, IntPtr ctx);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetThreadContext(IntPtr t, IntPtr ctx);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Ansi)] public static extern IntPtr GetModuleHandleA(string n);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Ansi)] public static extern IntPtr GetProcAddress(IntPtr m, string n);
}
"@
$pid_ = (Get-Process -Name sd-jukebox -ErrorAction SilentlyContinue | Select-Object -First 1).Id
if (-not $pid_) { Say "sd-jukebox.exe not running"; exit 2 }
$addr = [Dbg]::GetProcAddress([Dbg]::GetModuleHandleA('kernel32.dll'), 'DeviceIoControl')
Say ("target pid $pid_ ; DeviceIoControl at 0x{0:X8}" -f $addr.ToInt32())
$hProc = [Dbg]::OpenProcess(0x1F0FFF, $false, [uint32]$pid_)
if ($hProc -eq [IntPtr]::Zero) { Say "OpenProcess failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"; exit 3 }
[Dbg]::DebugSetProcessKillOnExit($false) | Out-Null
if (-not [Dbg]::DebugActiveProcess([uint32]$pid_)) { Say "DebugActiveProcess failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"; exit 4 }
Say "attached"
function RdMem($a, $n) { $b = New-Object byte[] $n; $r = 0; [Dbg]::ReadProcessMemory($hProc, [IntPtr]$a, $b, $n, [ref]$r) | Out-Null; if ($r -lt $n) { $b = $b[0..([Math]::Max($r,1)-1)] }; return ,$b }
function WrByte($a, [byte]$v) { $b = [byte[]]@($v); $w = 0; [Dbg]::WriteProcessMemory($hProc, [IntPtr]$a, $b, 1, [ref]$w) | Out-Null; [Dbg]::FlushInstructionCache($hProc, [IntPtr]$a, 1) | Out-Null }
function Hex($b) { ($b | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' }
$orig = (RdMem $addr.ToInt32() 1)[0]
WrByte $addr.ToInt32() 0xCC
Say ("breakpoint set (orig byte 0x{0:X2})" -f $orig)
# debug event buffer: DEBUG_EVENT (32-bit) = 4+4+4 + union(80) ; CONTEXT x86 = 716 bytes
$ev = [Runtime.InteropServices.Marshal]::AllocHGlobal(256)
$ctx = [Runtime.InteropServices.Marshal]::AllocHGlobal(1024)
$pending = @{}   # tid -> @{ ret=retaddr; inbuf=ptr; hdev=..; code=.. }
$retBps = @{}    # retaddr -> orig byte
$stepping = @{}  # tid -> addr to re-arm
$deadline = (Get-Date).AddSeconds($Seconds); $nCalls = 0
Say "watching for $Seconds s: click Format in SD-Jukebox now"
while ((Get-Date) -lt $deadline) {
    if (-not [Dbg]::WaitForDebugEvent($ev, 500)) { continue }
    $code = [Runtime.InteropServices.Marshal]::ReadInt32($ev, 0); $epid = [Runtime.InteropServices.Marshal]::ReadInt32($ev, 4); $tid = [Runtime.InteropServices.Marshal]::ReadInt32($ev, 8)
    $status = 0x00010002  # DBG_CONTINUE
    if ($code -eq 1) {  # EXCEPTION_DEBUG_EVENT
        $exCode = [Runtime.InteropServices.Marshal]::ReadInt32($ev, 12); $exAddr = [Runtime.InteropServices.Marshal]::ReadInt32($ev, 24); $first = [Runtime.InteropServices.Marshal]::ReadInt32($ev, 92)
        $hT = [Dbg]::OpenThread(0x1F03FF, $false, [uint32]$tid)
        [Runtime.InteropServices.Marshal]::WriteInt32($ctx, 0, 0x10007)   # CONTEXT_FULL
        [Dbg]::GetThreadContext($hT, $ctx) | Out-Null
        $eip = [Runtime.InteropServices.Marshal]::ReadInt32($ctx, 0xB8); $esp = [Runtime.InteropServices.Marshal]::ReadInt32($ctx, 0xC4); $eax = [Runtime.InteropServices.Marshal]::ReadInt32($ctx, 0xB0); $efl = [Runtime.InteropServices.Marshal]::ReadInt32($ctx, 0xC0)
        if ($exCode -eq 0x80000003 -and ($eip - 1) -eq $addr.ToInt32()) {
            # entry: args at [esp+4]...
            $st = RdMem $esp 36
            $ret = [BitConverter]::ToInt32($st, 0); $hdev = [BitConverter]::ToInt32($st, 4); $ioctl = [BitConverter]::ToUInt32($st, 8); $inbuf = [BitConverter]::ToInt32($st, 12); $inlen = [BitConverter]::ToInt32($st, 16)
            $nCalls++
            if ($ioctl -eq 0x4D014 -or $ioctl -eq 0x4D004) {
                $spt = RdMem $inbuf 44
                $cdbLen = $spt[6]; $dataIn = $spt[8]; $xfer = [BitConverter]::ToUInt32($spt, 12); $dbuf = [BitConverter]::ToInt32($spt, 20); $senseOff = [BitConverter]::ToUInt32($spt, 24); $senseLen = $spt[7]
                $cdb = $spt[28..(28 + [Math]::Max($cdbLen,1) - 1)]
                Say ("CALL #{0} tid {1} IOCTL 0x{2:X} hdev 0x{3:X} CDB[{4}] = {5}  DataIn={6} ({7})  len={8}  inlen={9}" -f $nCalls, $tid, $ioctl, $hdev, $cdbLen, (Hex $cdb), $dataIn, @('OUT(write to device)','IN(read from device)','NONE')[[int]$dataIn], $xfer, $inlen)
                if ($dataIn -eq 0 -and $xfer -gt 0) { Say ("   data OUT: " + (Hex (RdMem $dbuf ([Math]::Min($xfer, 96))))) }
                $pending[$tid] = @{ ret = $ret; inbuf = $inbuf; dbuf = $dbuf; senseOff = $senseOff; senseLen = $senseLen; xfer = $xfer; n = $nCalls }
                if (-not $retBps.ContainsKey($ret)) { $retBps[$ret] = (RdMem $ret 1)[0]; WrByte $ret 0xCC }
            } else {
                Say ("CALL #{0} tid {1} IOCTL 0x{2:X} hdev 0x{3:X} inlen {4} (not pass-through)" -f $nCalls, $tid, $ioctl, $hdev, $inlen)
            }
            # step over: restore byte, eip = addr, set TF, re-arm after step
            WrByte $addr.ToInt32() $orig
            [Runtime.InteropServices.Marshal]::WriteInt32($ctx, 0xB8, $addr.ToInt32()); [Runtime.InteropServices.Marshal]::WriteInt32($ctx, 0xC0, ($efl -bor 0x100))
            [Dbg]::SetThreadContext($hT, $ctx) | Out-Null
            $stepping[$tid] = $addr.ToInt32()
        } elseif ($exCode -eq 0x80000003 -and $retBps.ContainsKey($eip - 1)) {
            $p = $pending[$tid]
            if ($p) {
                $spt = RdMem $p.inbuf 44
                $scsi = $spt[2]; $xferOut = [BitConverter]::ToUInt32($spt, 12)
                $sense = RdMem ($p.inbuf + $p.senseOff) ([Math]::Max([int]$p.senseLen, 1))
                $data = RdMem $p.dbuf ([Math]::Min([Math]::Max([int]$xferOut, 1), 128))
                Say ("RET  #{0} DeviceIoControl returned eax={1}  ScsiStatus=0x{2:X2}  transferred={3}  sense: {4}" -f $p.n, $eax, $scsi, $xferOut, (Hex $sense))
                Say ("     data: " + (Hex $data))
                $pending.Remove($tid)
            }
            $ra = $eip - 1; WrByte $ra $retBps[$ra]
            [Runtime.InteropServices.Marshal]::WriteInt32($ctx, 0xB8, $ra); [Runtime.InteropServices.Marshal]::WriteInt32($ctx, 0xC0, ($efl -bor 0x100))
            [Dbg]::SetThreadContext($hT, $ctx) | Out-Null
            $stepping[$tid] = $ra
        } elseif ($exCode -eq 0x80000004 -and $stepping.ContainsKey($tid)) {
            WrByte $stepping[$tid] 0xCC; $stepping.Remove($tid)
        } elseif ($exCode -eq 0x80000003) {
            # someone else's breakpoint (initial attach breakpoint) - just continue
        } else {
            $status = 0x80010001   # DBG_EXCEPTION_NOT_HANDLED
        }
        [Dbg]::CloseHandle($hT) | Out-Null
    }
    [Dbg]::ContinueDebugEvent([uint32]$epid, [uint32]$tid, $status) | Out-Null
}
# cleanup: remove all breakpoints, detach
WrByte $addr.ToInt32() $orig
foreach ($k in @($retBps.Keys)) { WrByte $k $retBps[$k] }
[Dbg]::DebugActiveProcessStop([uint32]$pid_) | Out-Null
Say "detached; $nCalls DeviceIoControl calls seen"
