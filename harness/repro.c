// Runs ONE file through the exact same code the fuzzer uses.
// This is what you point GDB at: gdb --args ./repro_vuln crash-input
#include "target.h"
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  if (argc != 2) { fprintf(stderr, "usage: %s <file>\n", argv[0]); return 2; }
  FILE *f = fopen(argv[1], "rb");
  fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
  uint8_t *buf = malloc(n);
  fread(buf, 1, n, f); fclose(f);
  decode(buf, (size_t)n);
  free(buf);
  return 0;
}
