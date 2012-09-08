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

#include "maximite.h"     // maximite_reset()
#include "usb.h"
#include "sdcard.h"
#include "rom.h"
#include "rk86_memory.h"
#include "i8080_pic32.h"  // i8080_pic32_jump()

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

void console_printf(const char* fmt, ...) {
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    usb_send_string(buf);
}

static int hex(const char* s) {
    int r = 0;
    sscanf(s, "%02X", &r);
    return r;
}

void process_console() {
    static char cmd[256] = { 0 };
    static int cmd_i = 0;
    int ch = usb_inkey();
    if (ch == -1) return;
    if (cmd_i == 0 && (ch == '\n' || ch == '\r')) return;
    if (ch != '\r' && ch != '\n') {
        if (ch == '\b' && cmd_i > 0) {
            cmd_i -= 1;
        } else if (cmd_i < sizeof(cmd) - 1) {
            cmd[cmd_i] = ch;
            cmd_i += 1;
        }
        return;
    }
    cmd[cmd_i] = 0;
    // Trim trailing blanks and tabs.
    while (cmd_i > 0 && (cmd[cmd_i - 1] == ' ' || cmd[cmd_i - 1] == '\t')) {
        cmd_i -= 1;
        cmd[cmd_i] = 0;
    }
    if (cmd_i == 0) return;
    cmd_i = 0;

    // The code below is really ugly. It does need to be re-written using
    // a table of commands. The parser should extract the command name
    // from the buffer, then count and extract the arguments if they're
    // provided, and finally try to find an appropriate candiate in the
    // command table and call it passing the arguments into it.
    if (strlen(cmd) > 1 + 2 + 4 + 2 + 2 && cmd[0] == ':') {
        int len = 0, addr = 0, type = -1;
        if (sscanf(cmd, ":%02X%04X%02X", &len, &addr, &type) == 3) {
            if (type == 0) {
                int const end = 9 + len * 2;
                unsigned char sum;
                int i;
                for (sum = 0, i = 1; i < end; sum += hex(cmd + i), i += 2);
                sum = 0x100 - sum;
                if (hex(cmd + end) != sum) {
                    console_printf("ERROR, bad checksum, expected %02X, "
                                   "actual %02X\r\n", hex(cmd + end), sum);
                } else {
                    unsigned char* mem = rk86_memory() + addr;
                    int i;
                    for(i = 9; i < end; i += 2)
                        *mem++ = hex(cmd + i);
                    console_printf("OK\r\n");
                }
                return;
            }
        }
    } else if (!strcmp(cmd, "reset")) {
        maximite_reset();
    } else if (!strcmp(cmd, "?")) {
    } else if (!memcmp(cmd, "load ", 5) && strlen(cmd) > 5) {
        sdcard_load_rk86_file(cmd + 5, -1);
    } else if (!memcmp(cmd, "image ", 6) && strlen(cmd) > 6) {
        char name[128];
        int start_address = 0;
        sscanf(cmd + 6, "%127s %x", name, &start_address);
        console_printf("Start address: %04X\r\n", start_address);
        sdcard_load_binary_file(name, (char*)rk86_memory() + start_address,
                                0x10000 - start_address);
    } else if (!memcmp(cmd, "run ", 4) && strlen(cmd) > 4) {
        int entry = sdcard_load_rk86_file(cmd + 4, -1);
        i8080_pic32_jump(entry);
    } else if (!memcmp(cmd, "go ", 3) && strlen(cmd) > 3) {
        int entry = 0;
        sscanf(cmd + 3, "%x", &entry);
        i8080_pic32_jump(entry);
    } else if (!memcmp(cmd, "ls", 2)) {
        sdcard_ls();
    } else if (!strcmp(cmd, "rom")) {
        rom_ls();
    } else if (!memcmp(cmd, "rom ", 4) && strlen(cmd) > 4) {
        char name[128];
        int start_address = -1;
        sscanf(cmd + 4, "%127s %x", name, &start_address);
        if (start_address == -1)
            console_printf("Using file default start address\r\n");
        else
            console_printf("Start address: %04X\r\n", start_address);
        rom_load_file(name, (char*)rk86_memory(), start_address);
    } else if (!memcmp(cmd, "cpu", 3)) {
        i8080_pic32_print_cpu_info();
    } else if (!memcmp(cmd, "video", 3)) {
        rk86_hardware_print_screen_settings();
    } else console_printf("?");
    console_printf("OK\n\r");
}
