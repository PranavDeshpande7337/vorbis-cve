// The single thing we fuzz: open an Ogg Vorbis file from memory, decode all
// of it. VORBIS_FILE is set by the compiler (-D) to pick vuln or fixed source.
#include <stdint.h>
#include <stddef.h>
#define STB_VORBIS_NO_STDIO
#include VORBIS_FILE   // including the .c file compiles it WITH our sanitizer flags

static void decode(const uint8_t *data, size_t size) {
  if (size == 0 || size > 1 << 20) return;
  int err = 0;
  stb_vorbis *v = stb_vorbis_open_memory(data, (int)size, &err, NULL);
  if (!v) return;
  float **out; int n; long total = 0;
  while ((n = stb_vorbis_get_frame_float(v, NULL, &out)) > 0 && total < (1 << 20))
    total += n;
  stb_vorbis_close(v);
}
