#ifndef CVORBIS_H
#define CVORBIS_H

// The one stb_vorbis entry point Clacky uses. Decodes a whole Ogg Vorbis
// file held in memory into interleaved 16-bit PCM. Returns the number of
// frames (samples per channel) or -1 on failure. *output is allocated with
// malloc() and the caller must free() it.
int stb_vorbis_decode_memory(const unsigned char *mem, int len,
                             int *channels, int *sample_rate, short **output);

#endif
