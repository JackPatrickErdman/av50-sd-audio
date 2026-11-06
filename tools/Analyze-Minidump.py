r"""Analyze-Minidump.py — no-debugger triage of a Windows minidump (.dmp): exception record,
module list, and a scan of the faulting thread's stack memory for return addresses that fall
inside loaded modules (a poor man's stack walk; good enough to see WHICH modules recurse in a
stack-overflow crash). Pure Python, no pip packages.

  python Analyze-Minidump.py <file.dmp> [max_frames]
"""
import struct, sys, collections

path = sys.argv[1]
maxf = int(sys.argv[2]) if len(sys.argv) > 2 else 60
d = open(path, 'rb').read()
sig, ver, nstreams, stream_rva = struct.unpack_from('<4sIII', d, 0)
assert sig == b'MDMP', 'not a minidump'
streams = {}
for i in range(nstreams):
    stype, size, rva = struct.unpack_from('<III', d, stream_rva + 12 * i)
    streams.setdefault(stype, []).append((rva, size))

def rd_str(rva):
    n = struct.unpack_from('<I', d, rva)[0]
    return d[rva + 4: rva + 4 + n].decode('utf-16le', 'replace')

# ---- modules (stream 4)
mods = []
rva, size = streams[4][0]
n = struct.unpack_from('<I', d, rva)[0]
p = rva + 4
for i in range(n):
    base, msize, cksum, tstamp, name_rva = struct.unpack_from('<QIIII', d, p)
    mods.append((base, msize, rd_str(name_rva)))
    p += 108
mods.sort()

def mod_of(addr):
    for base, msize, name in mods:
        if base <= addr < base + msize:
            return name.split('\\')[-1], addr - base
    return None

# ---- memory ranges (stream 5 = MemoryList, 9 = Memory64List)
mem = []
if 5 in streams:
    rva, size = streams[5][0]
    n = struct.unpack_from('<I', d, rva)[0]
    p = rva + 4
    for i in range(n):
        start, dsize, drva = struct.unpack_from('<QIQ', d, p)[0], struct.unpack_from('<I', d, p + 8)[0], struct.unpack_from('<I', d, p + 12)[0]
        mem.append((start, dsize, drva)); p += 16
if 9 in streams:
    rva, size = streams[9][0]
    n, base_rva = struct.unpack_from('<QQ', d, rva)
    p = rva + 16; off = base_rva
    for i in range(n):
        start, dsize = struct.unpack_from('<QQ', d, p)
        mem.append((start, dsize, off)); off += dsize; p += 16

def read_mem(addr, n):
    for start, dsize, drva in mem:
        if start <= addr < start + dsize:
            k = min(n, start + dsize - addr)
            return d[drva + addr - start: drva + addr - start + k]
    return b''

# ---- system info (stream 7): processor architecture
arch = None
if 7 in streams:
    rva, size = streams[7][0]
    arch = struct.unpack_from('<H', d, rva)[0]  # 0 = x86, 9 = x64
print('arch:', {0: 'x86', 9: 'x64'}.get(arch, arch), '| modules:', len(mods), '| memory ranges:', len(mem))

# ---- exception (stream 6)
if 6 in streams:
    rva, size = streams[6][0]
    tid, _, code, flags, rec, addr = struct.unpack_from('<IIIIQQ', d, rva)
    nparams = struct.unpack_from('<I', d, rva + 32)[0]
    ctx_size, ctx_rva = struct.unpack_from('<II', d, rva + 32 + 8 + 15 * 8)
    print('exception: code 0x%08X at 0x%X (%s) thread %d' % (code, addr, mod_of(addr), tid))
    ctx = d[ctx_rva: ctx_rva + ctx_size]
    if arch == 0:   # x86 CONTEXT: Esp at 0xC4, Eip at 0xB8, Ebp at 0xB4
        esp = struct.unpack_from('<I', ctx, 0xC4)[0]; eip = struct.unpack_from('<I', ctx, 0xB8)[0]; ebp = struct.unpack_from('<I', ctx, 0xB4)[0]
        print('eip 0x%08X %s  esp 0x%08X  ebp 0x%08X' % (eip, mod_of(eip), esp, ebp))
        ptr = 4
    else:           # x64 CONTEXT: Rsp at 0x98, Rip at 0xF8
        esp = struct.unpack_from('<Q', ctx, 0x98)[0]; eip = struct.unpack_from('<Q', ctx, 0xF8)[0]
        print('rip 0x%X %s  rsp 0x%X' % (eip, mod_of(eip), esp)); ptr = 8
    # ---- thread stack range from thread list (stream 3)
    rva3, _ = streams[3][0]
    nt = struct.unpack_from('<I', d, rva3)[0]
    stack_start = stack_size = None
    for i in range(nt):
        t_id = struct.unpack_from('<I', d, rva3 + 4 + 48 * i)[0]
        if t_id == tid:
            stack_start, stack_size = struct.unpack_from('<QI', d, rva3 + 4 + 48 * i + 16)
            break
    print('stack memory in dump: start 0x%X size 0x%X (%d KB)' % (stack_start, stack_size, stack_size // 1024))
    # ---- scan the stack from ESP upward for module addresses
    blob = read_mem(esp, stack_size - (esp - stack_start) if stack_start else 0x20000)
    counts = collections.Counter(); frames = []
    for i in range(0, len(blob) - ptr + 1, ptr):
        v = struct.unpack_from('<I' if ptr == 4 else '<Q', blob, i)[0]
        m = mod_of(v)
        if m:
            counts[m[0]] += 1
            if len(frames) < maxf: frames.append((esp + i, v, m))
    print('\n--- first %d module addresses on the stack (nearest the fault first) ---' % len(frames))
    for sp, v, (name, off) in frames:
        print('  sp 0x%08X -> 0x%08X  %s+0x%X' % (sp, v, name, off))
    print('\n--- module hit counts over the whole dumped stack (%d KB scanned) ---' % (len(blob) // 1024))
    for name, c in counts.most_common(15):
        print('  %6d  %s' % (c, name))

print('\n--- loaded modules (non-Windows first) ---')
for base, msize, name in mods:
    short = name.split('\\')[-1]
    if not name.lower().startswith('c:\\windows'):
        print('  0x%08X %8X  %s' % (base, msize, name))
print('  (+%d modules under C:\\Windows)' % sum(1 for b, s, n in mods if n.lower().startswith('c:\\windows')))
