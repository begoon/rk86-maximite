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

#include "rom.h"
#include "rom_file.h"
#include "console.h"

#include <string.h>

#include "tinfl.c"

extern struct rom_file_t rom_files[];

// This function loaded a file with a given name from ROM storage.
// The file is loaded into "addr + offset" address.
void rom_load_file(const char* name, char* addr, int offset) {
    struct rom_file_t* file;
    for (file = &rom_files[0]; file->name; ++file) {
        if (strcmp(name, file->name)) continue;
        int const expected_sz = file->end - file->start + 1;
        if (offset == -1)
            offset = file->start;
        if (offset + expected_sz > 0x10000) {
            console_printf("ERROR: Offset %04X + file size %04X is "
                           "greater then 0x10000.", offset, expected_sz);
            return;
        }
        if (file->compressed) {
            if (tinfl_decompress_mem_to_mem(addr + offset, expected_sz,
                                            file->image, file->size, 0)
                == TINFL_DECOMPRESS_MEM_TO_MEM_FAILED) {
                console_printf("ERROR: Unable to decompress the file.\r\n");
                return;
            }
        } else {
            // If the given offset is -1, we load to the file start address.
            memcpy(addr + offset, file->image, expected_sz);
        }
        console_printf("File is successfully loaded at %04X-%04X.\r\n",
                       offset, offset + expected_sz - 1);
        return;
    }
    console_printf("ERROR: File not found.\r\n");
}

unsigned char* rom_file_image(const char* name) {
    struct rom_file_t* file;
    for (file = &rom_files[0]; file->name; ++file)
        if (!strcmp(name, file->name)) return (unsigned char*)file->image;
    return 0;
}

// This function prints out names of the files from ROM.
void rom_ls(void) {
    struct rom_file_t* file;
    int i = 0;
    for (file = &rom_files[0]; file->name; ++file) {
        console_printf("%-14s ", file->name);
        i += 1;
        if (i == 5) {
            console_printf("\r\n");
            i = 0;
        }
    }
    if (i)
        console_printf("\r\n");
}
