# vorbis-cve

A coverage-guided fuzzing and root-cause-analysis lab built against a real,
published CVE in a widely-used C library.

Targets `stb_vorbis.c` (Sean Barrett's single-file Ogg Vorbis decoder, used in
many games and audio apps) at the exact commit before its 2019 security fix.
Builds the vulnerable source with AddressSanitizer and UndefinedBehaviorSanitizer,
fuzzes it with libFuzzer until it reproduces a real memory-safety bug, confirms
the official patch resolves it, and uses a local LLM (via Ollama) to perform
independent root-cause triage on the crash — no cloud API required, no data
leaves the machine.

## What it does

- Checks out two versions of `stb_vorbis.c` from its real git history: the
  commit immediately before the fix, and the fix commit itself
- Builds a libFuzzer harness against the vulnerable version, instrumented with
  ASan (memory-safety violations) and UBSan (undefined behaviour)
- Fuzzes from one valid seed `.ogg` file until it finds a crashing input
- Reproduces the crash standalone (outside the fuzzer) for clean, readable
  sanitizer output and GDB debugging
- Re-runs the same crashing input against the patched version to confirm the
  fix actually closes the hole
- Sends the crash report and source snippet to a local LLM and asks it to
  independently classify the bug class, CWE and root cause

## The vulnerability

| | |
|---|---|
| CVE | CVE-2019-13218 |
| CWE | CWE-787 (Out-of-bounds Write) |
| Function | `compute_codewords()` |
| Bug class | Stack buffer overflow |
| Found by | ForAllSecure (Mayhem), 2019 — reproduced here independently |

```c
uint32 available[32];
for (i=1; i <= len[k]; ++i)
   available[i] = 1U << (32-i);   // len[k] is read from the file, unchecked
```
`len[k]` is a codeword length decoded straight from attacker-controlled file
bytes. Nothing validates it before this loop indexes `available[]`, so a
codeword length of 32 or more writes past the end of the array. The upstream
fix adds a single bounds check in the caller, before this function is ever
reached: `if (current_length >= 32) return error(f, VORBIS_invalid_setup);`

## How the pipeline works

```
fetch_and_build.sh
        |
        v
  git checkout (vuln commit, fix commit)  ->  vuln_stb_vorbis.c, fixed_stb_vorbis.c
        |
        v
  clang -fsanitize=fuzzer,address,undefined
        |
        v
  fuzz_vuln  <-- corpus/seed.ogg (valid file, generated with ffmpeg)
        |
        | (libFuzzer mutates bytes, guided by coverage instrumentation)
        v
  crash found -> crashes/crash-<hash>
        |
        v
  repro_vuln crash-<hash>   -> ASan/UBSan report (file, line, stack trace)
        |
        v
  repro_fixed crash-<hash>  -> confirms patch fixes it (clean exit)
        |
        v
  ai/triage.py  -> local LLM (Ollama) independently classifies bug class + CWE
```

## Setup

```bash
sudo apt update && sudo apt install -y clang llvm libclang-rt-18-dev gdb git ffmpeg python3 python3-pip
```
(If `libclang-rt-18-dev` isn't found, run `clang --version` and substitute
that version number, e.g. `libclang-rt-17-dev`.)

### Ollama setup (for the AI triage step)

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.1
pip3 install requests --break-system-packages
```

## Usage

```bash
# 1. Fetch both versions of the source and build the binaries
./fetch_and_build.sh

# 2. Generate a valid seed file and fuzz until a crash is found (~2 min)
ffmpeg -loglevel error -f lavfi -i "sine=frequency=440:sample_rate=22050:duration=0.3" \
       -c:a libvorbis -q:a 2 corpus/seed.ogg
ASAN_OPTIONS=detect_leaks=0 ./fuzz_vuln corpus -max_len=8192 -timeout=5 \
       -artifact_prefix=crashes/ -max_total_time=120

# 3. Reproduce and read the crash report
./repro_vuln crashes/<crash-file>

# 4. Confirm the official patch fixes it (clean exit = fixed)
./repro_fixed crashes/<crash-file>

# 5. Debug it directly (optional)
gdb --args ./repro_vuln crashes/<crash-file>

# 6. Ask a local model to independently triage the same crash
python3 ai/triage.py
```

## Output

```
AddressSanitizer: stack-buffer-overflow ... WRITE of size 4
    #0 compute_codewords vuln_stb_vorbis.c:1058
    #1 start_decoder     vuln_stb_vorbis.c:3764
    #2 stb_vorbis_open_memory vuln_stb_vorbis.c:5018
```
`ai/triage.py` prints the local model's bug-class/CWE/root-cause judgement
next to the verified answer (CVE-2019-13218, CWE-787) for direct comparison.

## Repo layout

```
fetch_and_build.sh      fetches both source versions, builds 3 binaries
harness/
  target.h              the decode() call under test, shared by fuzzer and reproducer
  fuzz.c                libFuzzer entry point
  repro.c               standalone single-input reproducer (for GDB)
vuln_stb_vorbis.c        the library as it existed before the 2019 fix
fixed_stb_vorbis.c       the library as patched
corpus/seed.ogg          one valid Ogg Vorbis file used to seed the fuzzer
crash_report.txt          a verified crash from this project's own run
crash_input.bin           the exact input that produces it
crash_source.txt          the source lines around the crash
ai/triage.py              sends a crash to a local LLM for independent triage
REPORT.md                 write-up template
```

## Research context

The underlying bugs (CVE-2019-13217 through CVE-2019-13223) were originally
found by ForAllSecure's Mayhem fuzzer in 2019 and fixed in a single upstream
commit. This project reproduces that discovery process independently —
coverage-guided fuzzing plus sanitizer instrumentation to find real
memory-safety defects — and extends it with an LLM-assisted triage step to
evaluate how well a local model can classify a vulnerability's root cause
from raw crash evidence alone.