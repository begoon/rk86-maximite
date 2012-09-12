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
#include <string.h>

#include "rk86_video.h"
#include "maximite.h"
#include "video.h"
#include "rom.h"
#include "panic.h"

// Define the blink rate for the cursor.
#define CURSOR_OFF       350
#define CURSOR_ON        650

#define CURSOR_HIDDEN    0
#define CURSOR_STANDARD  1
#define CURSOR_INSERT    2

volatile static unsigned int cursor_timer;

static volatile int cursor_x = 0, cursor_y = 0;
static int screen_size_x = 0, screen_size_y = 0;

// Cursor control variables.
static int cursor_shape = CURSOR_STANDARD;

// RK character
const static int char_width = 6;
const static int char_height = 8;
const static int char_height_gap = 2;

static char* rk86_font;

static void rk86_video_update_cursor(int show);

// Initialise the video components.
void rk86_video_init(void) {
    rk86_font = (char*)rom_file_image("rk86_font.bin");
    if (rk86_font == 0)
        panic(PANIC_UNABLE_TO_LOAD_RK86_FONT);
    rk86_video_configure_screen(80, 30);
}

void rk86_video_init_cursor_timer(void) {
    // Setup timer 4.
    PR4 = 1 * ((BUSFREQ/2)/1000) - 1;
    T4CON = 0x8010;
    mT4SetIntPriority(1);
    mT4ClearIntFlag();
    mT4IntEnable(1);
}

// Timer 4 interrupt processor. This fires every millisecond.
void __ISR (_TIMER_4_VECTOR, ipl1) T4Interrupt(void) {
    if (++cursor_timer > CURSOR_OFF + CURSOR_ON) cursor_timer = 0;
    rk86_video_update_cursor(1);
    // Clear the interrupt flag.
    mT4ClearIntFlag();
}

// This function configures the RK86 screen emulation on VGA.
// Input:
//    size_x, size_y - the screen dimentions in RK86 characters
void rk86_video_configure_screen(int size_x, int size_y) {
    int const vga_hres = size_x * char_width;
    int const vga_vres = size_y * (char_height + char_height_gap);
    video_start(vga_hres, vga_vres);
    rk86_video_init_cursor_timer();
    // We keep the screen dimentions for further retrieval.
    screen_size_x = size_x;
    screen_size_y = size_y;
}

// This function draws a character based on using a bitmap font.
// I wanted to make this function to be fast, so I manually moved out
// the invariants from the loops. The compiler may also do this but 
// the free version of XC32 1.0 only allows -O1 optimization.
void rk86_video_draw_char(int x, int y, int c) {
    char const* bitmap = rk86_font + (c & 0x7f) * 8;
    int offset_y = y * (char_height + char_height_gap);
    int const offset_x = x * char_width;
    int xx, yy, byte, mask;
    for (yy = 0; yy < char_height; ++yy, ++offset_y, ++bitmap) {
        byte = *bitmap;
        mask = 0x01 << (char_width - 1);
        for (xx = offset_x; mask != 0; ++xx, mask >>= 1)
            video_draw_pixel(xx, offset_y, !(byte & mask));
    }
}

static void rk86_video_draw_cursor(int mode) {
    int x = cursor_x * char_width;
    int const y = cursor_y * (char_height + char_height_gap) + char_height;
    int const xx = x + char_width;
    for (x = x; x < xx; ++x)
        video_draw_pixel(x, y, mode);
}

static void rk86_video_update_cursor(int show) {
    static int visible = 0;
    static int last_shape = CURSOR_HIDDEN;
    int shape = CURSOR_HIDDEN;

    if (cursor_timer > CURSOR_ON) show = 0;
    if (!visible && !show) return;                                   // Not showing and not required so skip the rest.
    if (visible && show && last_shape == cursor_shape) return;       // Cursor is on and the correct type so skip the rest.

    if (visible && !show)
        shape = last_shape;                   // This will turn the cursor off.
    else if (!visible && show)
        shape = last_shape = cursor_shape;    // This will turn it on with the current cursor.
    else if (last_shape != cursor_shape)
        shape = last_shape;                   // This will turn it off ready for the next entry where it will turn on with the new cursor.

    rk86_video_draw_cursor(-1);
    visible = !visible;
}

void rk86_video_set_cursor(int x, int y) {
    rk86_video_draw_cursor(0);
    cursor_x = x;
    cursor_y = y;
}

int rk86_video_screen_size_x(void) {
    return screen_size_x;
}

int rk86_video_screen_size_y(void) {
    return screen_size_y;
}
