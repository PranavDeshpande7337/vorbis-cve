# CVE-2019-13218 — Stack Buffer Overflow in stb_vorbis

**Target:** `stb_vorbis.c` (single-file C Ogg Vorbis decoder, github.com/nothings/stb)
**Method:** libFuzzer + AddressSanitizer + UndefinedBehaviorSanitizer
**Vulnerable commit:** the commit just before `98fdfc6` ("Fix seven bugs discovered and fixed by ForAllSecure")

## What I did

Built a fuzzing harness around `stb_vorbis_open_memory` / `stb_vorbis_get_frame_float`,
seeded it with one valid Ogg Vorbis file, and ran libFuzzer against the
pre-patch version of the library. It found a crash in under two minutes.

## The crash

```
<paste the contents of crash_report.txt here>
```

## Root cause

`compute_codewords()` writes into a fixed-size 32-element stack array:

```c
uint32 available[32];
...
for (i=1; i <= len[k]; ++i)
   available[i] = 1U << (32-i);
```

`len[k]` is a codeword length decoded directly from the input file — nothing
validates it before this loop runs. A crafted file with a codeword length of
32 or more makes the loop write past the end of `available`, corrupting the
stack. This is CWE-787 (Out-of-bounds Write), published as CVE-2019-13218.

## Confirming the fix

Running the exact same crashing input against the patched version of
`stb_vorbis.c` produces no crash. The upstream fix adds a bounds check in the
caller, `start_decoder()`, before `compute_codewords()` is ever reached:

```c
if (current_length >= 32) return error(f, VORBIS_invalid_setup);
```

## AI-assisted triage

Asked a local Ollama model (`llama3.1`) to classify the bug from the ASan
report and source snippet alone, with no knowledge of the CVE.

**Model's answer:**
```
<paste the JSON output from ai/triage.py here>
```

**Real answer:** CVE-2019-13218, stack buffer overflow, CWE-787.

**Assessment:** <your own sentence — did it get the bug class/CWE right? Did
its root-cause explanation actually name the missing bounds check, or just
restate the crash line?>

## What this demonstrates

- Building and running a sanitizer-instrumented C fuzzing harness
- Reading and debugging C, including stack traces and ASan reports
- Root-causing a real memory-safety bug, not just reporting a crash
- Using a local LLM to assist (not replace) vulnerability triage
