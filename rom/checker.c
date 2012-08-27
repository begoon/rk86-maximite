#include <stdlib.h>
#include <stdio.h>
#include <assert.h>

#include "../tinfl.c"
#include "../rom_file.h"

extern struct rom_file_t rom_files[];

int main() {
    struct rom_file_t* file;
    for (file = &rom_files[0]; file->name; ++file) {
        const int expected_sz = file->end - file->start + 1;
        printf("%16s, %04X-%04X (%04X), %d, %04X\n", 
               file->name, file->start, file->end, expected_sz,
               file->compressed, file->size);
        if (file->compressed) {
            size_t r;
            char* image = malloc(expected_sz);
            assert(image != NULL);
            r = tinfl_decompress_mem_to_mem(image, expected_sz,
                                            file->image, file->size, 0);
            assert(r != TINFL_DECOMPRESS_MEM_TO_MEM_FAILED);
            free(image);
        } else {
            assert(expected_sz == file->size);
        }
    }
    return 0;
}
