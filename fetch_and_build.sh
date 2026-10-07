#!/usr/bin/env bash
# Gets the vulnerable and fixed versions of stb_vorbis.c, then builds four binaries:
#   fuzz_vuln   - the fuzzer, built against the VULNERABLE source
#   repro_vuln  - runs ONE input file through the vulnerable source (for GDB)
#   repro_fixed - runs ONE input file through the FIXED source (to prove the patch works)
set -euo pipefail
cd "$(dirname "$0")"

# This commit fixes 7 real CVEs (CVE-2019-13217 .. CVE-2019-13223) in one go -
# so whatever we find is a verifiable, real, named vulnerability.
FIX_COMMIT=98fdfc6df88b1e34a736d5e126e6c8139c8de1a6

if [ ! -d stb/.git ]; then
  git clone --quiet https://github.com/nothings/stb.git
fi
cd stb
VULN_COMMIT=$(git rev-parse "$FIX_COMMIT^")
git show "$VULN_COMMIT:stb_vorbis.c" > ../vuln_stb_vorbis.c
git show "$FIX_COMMIT:stb_vorbis.c"  > ../fixed_stb_vorbis.c
cd ..

# -g                    debug symbols, so crashes show file:line
# -fsanitize=address    ASan: pinpoints the exact bad memory access
# -fsanitize=undefined  UBSan: catches integer overflow / bad shifts (several of these CVEs are this)
# -fsanitize=fuzzer     only on the fuzzer binary: adds libFuzzer's engine
FLAGS="-g -O1 -fsanitize=address,undefined -Iharness -I."
clang $FLAGS -fsanitize=fuzzer -DVORBIS_FILE=\"vuln_stb_vorbis.c\"  harness/fuzz.c  -lm -o fuzz_vuln
clang $FLAGS                   -DVORBIS_FILE=\"vuln_stb_vorbis.c\"  harness/repro.c -lm -o repro_vuln
clang $FLAGS                   -DVORBIS_FILE=\"fixed_stb_vorbis.c\" harness/repro.c -lm -o repro_fixed
echo "built: fuzz_vuln repro_vuln repro_fixed"
