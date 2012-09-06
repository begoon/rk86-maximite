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
//
// Based on Maximite MMBasic code.
//
// These files are distributed on condition that the following copyright
// notice and credits are retained in any subsequent versions:
//
// Copyright 2011, 2012 Geoff Graham.
//
// Based on code by Lucio Di Jasio in his book "Programming 32-bit
// Microcontrollers in C - Exploring the PIC32".
//
// Non US keyboard support by Fabrice Muller.

#include <p32xxxx.h>
#include <plib.h>
#include "sdcard/SDCARD.h"

#include "console.h"
#include "rk86_memory.h"

// Initialise SD card subsystem. This function must be called before
// any SD card activity because the SD might be re-inserted since last
// access.
// The function teturns 1 on success, and 0 otherwise.
int sdcard_init(void) {
    if (!MDD_MediaDetect()) {
        console_printf("SD card not found\n\r");
        return 0;
    }

    if (!FSInit()) {
        console_printf("Unable to initialize file system, error %d\n\r",
                       FSerror());
        return 0;
    }
    return 1;
}

// This function reads one byte from a given file. No errors are checked.
static unsigned char sdcard_read_char(FSFILE* f) {
    unsigned char ch;    
    FSfread(&ch, 1, 1, f);
    return ch;
}

// This function loads an RK86 file form the SD card.
// Input:
//   name - a file name
//   offset - an offset from 'base_addr' to place the file contents
//            If it is -1, the offset is taken from the file header
//            (the file start address). If it is >= 0, the start address
//            from the file header is ignored and 'offset' is used.
int sdcard_load_rk86_file(const char* name, int offset) {
    char const* memory = (char const*)rk86_memory();
    if (!sdcard_init()) return -1;

    FSFILE* f = FSfopen(name, READ);
    if (f == NULL) {
        console_printf("Unable to open file '%s', error %d\n\r",
                       name, FSerror());
        return -1;
    }

    // Is it the sync-byte (E6)?
    int start = sdcard_read_char(f);
    if (start == 0xe6) start = sdcard_read_char(f); 
    start = (start << 8) | sdcard_read_char(f);

    int const end = (sdcard_read_char(f) << 8) | sdcard_read_char(f);

    int entry = start;
    if (!strcmp(name, "PVO.GAM")) entry = 0x3400;

    int const sz = end - start + 1;

    console_printf("Loading file '%s' to %04X-%04X, size %04X\n\r",
                   name, start, end, sz);

    if (start < 0 || start > 0xffff || end < start || end > 0xffff) {
        console_printf("ERROR: Invalid file parameters\r\n");
        FSfclose(f);
        return -1;
    }

    int loaded = 0;
    while (loaded < sz && !FSfeof(f)) {
        int read = FSfread((void *)(memory + start + loaded), 1, sz - loaded, f);
        if (read == 0) break;
        loaded += read;
    }

    if (loaded < sz)
        console_printf("File '%s' length has to be %04X bytes "
                       "but only %04X were loaded.",
                       name, sz, loaded);
    FSfclose(f);

    console_printf("Loaded successfully, entry point is %04X\n\r", entry);
    return entry;
}

// This function loads a file to an arbitary location. It be use to load
// the monitor and fonts from the SD card to memory.
void sdcard_load_binary_file(const char* name, char* buf, int const buf_sz) {
    if (!sdcard_init()) return;

    FSFILE* f = FSfopen(name, READ);
    if (f == NULL) {
        console_printf("Unable to open file '%s', error %d\n\r", name,
                       FSerror());
        return;
    }

    console_printf("Loading binary file '%s'\n\r", name);

    int loaded = 0;
    while (loaded < buf_sz && !FSfeof(f)) {
        int read = FSfread(buf + loaded, 1, buf_sz - loaded, f);
        if (read == 0) break;
        loaded += read;
    }

    FSfclose(f);
    console_printf("Loaded successfully %04X bytes\r\n", loaded);
}

#define MAX_LS_FILES 300

static int cmp_name(void const* p1, void const* p2) {
    char const* r1 = (char const*)p1;
    char const* r2 = (char const*)p2;
    return strcmp(r1, r2);
}

void sdcard_ls(void) {
    SearchRec file;
    char files[MAX_LS_FILES][13];
    int loaded = 0;
    int i, j = 0;

    if (!sdcard_init()) return;

    i = FindFirst("*.*", ATTR_READ_ONLY | ATTR_ARCHIVE, &file);
    while (i != -1 && loaded < MAX_LS_FILES) {
        int err = FSerror();
        if (err != 0) {
            console_printf("ERROR: %d\n\r", err);
            return;
        }

        if (file.filename[0] != '.') {
            memset(files[loaded], 0, sizeof(files[loaded]));
            strncpy(files[loaded], file.filename, sizeof(files[loaded]) - 1);
            loaded += 1;
        }

        i = FindNext(&file);
    }

    if (i != -1)
        console_printf("Too many files (>%d)\r\n", MAX_LS_FILES);

    qsort(&files[0], loaded, sizeof(files[0]), &cmp_name);

    for (i = 0; i < loaded; ++i) {
        console_printf("%-14s ", files[i]);
        j += 1;
        if (j == 5) {
            console_printf("\r\n");
            j = 0;
        }
    }
    if (j)
        console_printf("\r\n");
}
