// libFuzzer calls this millions of times with mutated bytes.
#include "target.h"
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) { decode(data, size); return 0; }
