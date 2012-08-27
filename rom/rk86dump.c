// This file is part of Radio-86RK on Maximite project.
//
// Copyright (C) 2012 Alexander Demin <alexander@demin.ws>
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

int total_sz = 0;
int total_compressed_sz = 0;

#include "miniz.c"
#include "../rom_file.h"

void dump_c_string(const char* s, size_t sz) {
  int i = 0;
  printf("\"");
  while (sz--) {
    printf("\\x%02X", (unsigned char)*s++);
    ++i;
    if (i >= 16) {
      i = 0;
      if (sz) printf("\"\n\"");
    }
  }
  printf("\"\n},\n");
}

int dump_file(const char* name) {
  char dump_name[1024];
  FILE* f;
  int start, end, entry, sz;
  int disable_compression = 0;
  unsigned char ch;
  char* period;
  int i;

  strcpy(dump_name, name);

  period = strchr(dump_name, '.');
  assert(period != NULL);

  f = fopen(name, "rb+");
  if (!f) {
    fprintf(stderr, "unable to open file [%s]\n", name);
    exit(1);
  }

  if (!memcmp(name, "mon", 3) && !strcmp(period, ".bin")) {
    long sz;
    assert(fseek(f, 0L, SEEK_END) == 0);
    sz = ftell(f);
    assert(sz > -1L);

    end = 0xffff;
    start = end - sz + 1;
    entry = 0xf800;

    assert(fseek(f, 0L, SEEK_SET) == 0);
  } else if (!strcmp(name, "rk86_font.bin") || !strcmp(name, "rk_font.bin")) {
    long sz;
    assert(fseek(f, 0L, SEEK_END) == 0);
    sz = ftell(f);
    assert(sz > -1L);

    start = 0;
    end = sz - 1;
    entry = 0;
    disable_compression = 1;

    assert(fseek(f, 0L, SEEK_SET) == 0);
  } else {
    // Is it the sync-byte (E6)?
    fread(&ch, 1, 1, f);
    if (ch == 0xe6) fread(&ch, 1, 1, f); 

    // start address
    start = ch << 8;
    fread(&ch, 1, 1, f); start |= ch;

    // end address
    fread(&ch, 1, 1, f); end = ch << 8;
    fread(&ch, 1, 1, f); end |= ch;

    entry = start;

    if (!strcmp(dump_name, "PVO.GAM"))
      entry = 0x3400;
  }

  printf("{\n");
  printf("/* name       */ \"%s\",\n", dump_name);
  printf("/* start      */ 0x%04x,\n", start);
  printf("/* end        */ 0x%04x,\n", end);
  printf("/* entry      */ 0x%04x,\n", entry);

  int image_sz = end - start + 1;

  char* image = malloc(image_sz);
  char* compressed = malloc(image_sz);

  for (i = start; i <= end; ++i) {
    assert(!feof(f));
    fread(&ch, 1, 1, f);
    image[i - start] = ch;
  }

  fclose(f);

  int compressed_sz = !disable_compression ?
    tdefl_compress_mem_to_mem(compressed, image_sz, image, image_sz, 0) :
    0;

  // The field int the header:
  //   name+1, start(int), end(int), entry(int), compr(char), image_sz(int).
  int header_sz = sizeof(struct rom_file_t) + strlen(dump_name) + 1;

  total_sz += header_sz + image_sz;

  printf("/* compressed */ 0x%02x,\n", compressed_sz > 0);

  if (compressed_sz > 0) {
      free(image);
      image = compressed;
      image_sz = compressed_sz;
  } else {
      free(compressed);
  }

  total_compressed_sz += header_sz + image_sz;

  printf("/* size       */ 0x%04x,\n", image_sz);

  printf("/* image      */\n");

  dump_c_string(image, image_sz);

  free(image);

  return 0;
}

int main(int argc, char* argv[]) {
  int processed_files = 0;
  if (argc == 2) return dump_file(argv[1]);


  while (!feof(stdin)) {
    char line[1024] = {0};
    int sz;
    char* p;

    fgets(line, sizeof(line), stdin);
    sz = strlen(line);
    if (!sz) break;
    p = line + strlen(line) - 1;
    while (p != line && (*p == '\r' || *p == '\n')) *p-- = 0;

    dump_file(line);
    processed_files += 1;
  }

  fprintf(stderr, "Total size: %d (%08X)\n", total_sz, total_sz);
  fprintf(stderr, "Compressed: %d (%08X)\n", total_compressed_sz, total_compressed_sz);
  fprintf(stderr, "Radio     : %f\n", 1.0 * total_compressed_sz / total_sz);
  fprintf(stderr, "Processed : %d\n", processed_files);

  return 0;
}
