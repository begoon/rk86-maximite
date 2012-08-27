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

void process_console() {
    static char cmd[256] = { 0 };
    static int i = -1;
    int ch = usb_inkey();
    if (ch == -1) return;
    if (i == -1) {
        // First time character is received from USB, so we print
        // out the prompt.
        usb_send_string("RADIO-86RK CONSOLE\n\r\n\r> ");
        i = 0;
        return;
    }
    if (ch != '\r') {
        usb_send_char(ch);
        if (ch == '\b' && i > 0) {
            i -= 1;
        } else if (i < sizeof(cmd) - 1) {
            cmd[i] = ch;
            i += 1;
        }
        return;
    }
    console_printf("\n\r");
    cmd[i] = 0;
    // Trim trailing blanks and tabs.
    while (i > 0 && (cmd[i - 1] == ' ' || cmd[i - 1] == '\t')) {
        i -= 1;
        cmd[i] = 0;
    }
    i = 0;

    // The code below is really ugly. It does need to be re-written using
    // a table of commands. The parser should extract the command name
    // from the buffer, then count and extract the arguments if they're
    // provided, and finally try to find an appropriate candiate in the
    // command table and call it passing the arguments into it.
    if (!strcmp(cmd, "reset")) {
        maximite_reset();
    } else if (!strcmp(cmd, "?")) {
        console_printf("?");
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
    } else usb_send_string("?");
    console_printf("> ");
}
