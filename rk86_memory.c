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

#include <string.h>

#include "rk86_memory.h"
#include "rom.h"
#include "console.h"
#include "rk86_keyboard.h"
#include "rk86_video.h"

static int vg75_c001_00_cmd;

// Used to keep temporary values of the screen dimenstions when
// receiving the VG75 C001-00 command. 
static int screen_size_x_buf, screen_size_y_buf;

static int ik57_e008_80_cmd;

static int vg75_c001_80_cmd;

// Used to keep temporary values of the cursor position when receiving
// the VG75 C001-80 command.
static int cursor_x_buf, cursor_y_buf;

// This flag is set when the Monitor has stopped video and DMA before
// sending or received bytes to/from the tape.
static int tape_8002_as_output;

static int video_memory_base_buf;
static int video_memory_size_buf;

static unsigned char memory[0x10000];

// Used to keep the parameters of the RK video memory area.
// These variable are distict from video_memory_base_buf and
// video_memory_size_buf because they are assigned only after
// the DMA start channel command is received.

static int video_memory_base, video_memory_size;
static int video_screen_size_x, video_screen_size_y;
static int video_screen_cursor_x, video_screen_cursor_y;

int rk86_memory_read_byte(int addr) {
    if (addr == 0x8002) 
        return rk86_keyboard_modifiers();

    if (addr == 0x8001) {
       unsigned char const* const keyboard_state = rk86_keyboard_state();
       int ch = 0xff;
       // The "kbd_scanline" variable says which particular scanline is
       // being queried. This invariant is taken out from the loop the
       // sake of opmization.
       unsigned char const kbd_scanline = ~memory[0x8000];
       int i;
       for (i = 0; i < 8; i++)
           if ((1 << i) & kbd_scanline)
               ch &= keyboard_state[i];
      return ch;
   }

   if (addr == 0xC001)
      return 0xff;

   return memory[addr & 0xffff];
}

void rk86_memory_write_byte(int addr, int byte) {
    static int last = -1;
    int peripheral_reg;

    addr &= 0xffff;
    byte &= 0xff;

    if (addr >= 0xF800) return;

    // If the address is less than 0x8000, we skip all checks for peripherals.
    // We must include 0x8000 address because this cell holds the RK86
    // keyboard scanline.
    if (addr <= 0x8000) {
        if (addr >= video_memory_base && addr <= video_memory_base + video_memory_size - 1) {
            const int offset = addr - video_memory_base;
            const int x = offset % video_screen_size_x;
            const int y = offset / video_screen_size_x;
            rk86_video_draw_char(x, y, byte);
        }
        memory[addr] = byte;
    }

    // We mask out bits which aren't related to RK86 peripherals.
    // The "peripheral_reg" variable holds the address of a register
    // belonging to a RK86 peripheral (0x80xx, 0xC0xx, 0xE0xx).
    peripheral_reg = addr & 0xeffff;

    /*
     * RUS/LAT indicator
     */
    if (peripheral_reg == 0x8003) {
        if (byte == last) return;
        // The indicator status can is "byte & 0x01".
        last = byte;
        return;
    }

   /*
    * The cursor control sequence.
    */
   if (peripheral_reg == 0xc001 && byte == 0x80) {
       vg75_c001_80_cmd = 1;
       return;
   }

   if (peripheral_reg == 0xc000 && vg75_c001_80_cmd == 1) {
       vg75_c001_80_cmd += 1;
       cursor_x_buf = byte + 1;
       return;
   }

   if (peripheral_reg == 0xc000 && vg75_c001_80_cmd == 2) {
       cursor_y_buf = byte + 1;
       rk86_video_set_cursor(cursor_x_buf - 1, cursor_y_buf - 1);
       video_screen_cursor_x = cursor_x_buf;
       video_screen_cursor_y = cursor_y_buf;
       vg75_c001_80_cmd = 0;
       return;
   }

   /*
    * The screen format command sequence.
    */
    if (peripheral_reg == 0xc001 && byte == 0) {
        vg75_c001_00_cmd = 1;
        return;
    }

    if (peripheral_reg == 0xc000 && vg75_c001_00_cmd == 1) {
        screen_size_x_buf = (byte & 0x7f) + 1;
        vg75_c001_00_cmd += 1;
        return;
    }

    if (peripheral_reg == 0xc000 && vg75_c001_00_cmd == 2) {
        screen_size_y_buf = (byte & 0x3f) + 1;
        vg75_c001_00_cmd = 0;
    }

    // The screen area parameters command sequence.

    if (peripheral_reg == 0xe008 && byte == 0x80) {
        ik57_e008_80_cmd = 1;
        tape_8002_as_output = 1;
        return;
    }

    if (peripheral_reg == 0xe004 && ik57_e008_80_cmd == 1) {
        video_memory_base_buf = byte;
        ik57_e008_80_cmd += 1;
        return;
    }

    if (peripheral_reg == 0xe004 && ik57_e008_80_cmd == 2) {
        video_memory_base_buf |= byte << 8;
        ik57_e008_80_cmd += 1;
        return;
    }

    if (peripheral_reg == 0xe005 && ik57_e008_80_cmd == 3) {
        video_memory_size_buf = byte;
        ik57_e008_80_cmd += 1;
        return;
    }

    if (peripheral_reg == 0xe005 && ik57_e008_80_cmd == 4) {
        video_memory_size_buf = ((video_memory_size_buf | byte << 8) & 0x3fff) + 1;
        ik57_e008_80_cmd = 0;
    }

    /*
     * Settings for video memory boundaries and the screen format
     * only take an effect after the DMA command 0xA4 (start the channel).
     */
    if (peripheral_reg == 0xe008 && byte == 0xa4) {
        if (screen_size_x_buf && screen_size_y_buf) {
            // Only apply screen settings after the DMA start
            // channel command.

            // Only re-configure the display if the screen dimentions differ.
            // The RK86 Monitor always turns off the DMA controller by
            // writing 0x08 to [0xE008] before reading or writing each
            // byte from/to the tape. After processing the byte it re-starts
            // the video controller and re-configures the DMA. So this code
            // here will be called many times. We should avoid calling
            // rk86_video_configure_screen() frequently because this function
            // is slow. It is not clean how it works on the real RK86 hardware,
            // but it seems it works okay re-setting VG75 (video) and IK55
            // (DMA) for each byte, but it doesn't work for us.

            if (video_screen_size_x != screen_size_x_buf ||
                video_screen_size_y != screen_size_y_buf) {
                // Save ("apply") the screen dimentions.
                video_screen_size_x = screen_size_x_buf;
                video_screen_size_y = screen_size_y_buf;
                // Re-configure video.
                rk86_video_configure_screen(video_screen_size_x, video_screen_size_y);
                // Save ("apply") the video area parameters.
                video_memory_base = video_memory_base_buf;
                video_memory_size = video_memory_size_buf;
                rk86_memory_refresh_video_area();
            } else {
                // The screen dimentions aren't change, so we don't
                // re-configure the VGA. But the RK86 video area
                // parameters can be changed, and in this case we
                // have to re-draw the entire screen.
                if (video_memory_base != video_memory_base_buf ||
                    video_memory_size != video_memory_size_buf) {
                    video_memory_base = video_memory_base_buf;
                    video_memory_size = video_memory_size_buf;
                    rk86_memory_refresh_video_area();
                }
            }

            tape_8002_as_output = 0;
            return;
        }
    }

    if (addr == 0x8002) {
        // Tape I/O isn't implemented yet.
        // if (tape_8002_as_output)
        //    tape_write_bit(byte & 0x01);
        return;
    }

}

int rk86_memory_read_word(int addr) {
    return rk86_memory_read_byte(addr) | (rk86_memory_read_byte(addr + 1) << 8);
}

void rk86_memory_write_word(int addr, int word) {
    rk86_memory_write_byte(addr, word & 0xff);
    rk86_memory_write_byte(addr + 1, word >> 8);
}

void rk86_memory_refresh_video_area(void) {
    int i;
    for (i = video_memory_base; i <= video_memory_base + video_memory_size; ++i)
        rk86_memory_write_byte(i, rk86_memory_read_byte(i));
}

int rk86_io_input(int port) {
    return 0;
}

void rk86_io_output(int port, int value) {
}

void rk86_memory_init(void) {
    memset(memory, 0, sizeof memory);
    rom_load_file("mon32.bin", (char *)memory, 0xF800);
    rom_load_file("DEBUG.PKI", (char *)memory, -1);
}

void rk86_hardware_init(void) {
    vg75_c001_00_cmd = 0;
    vg75_c001_80_cmd = 0;

    ik57_e008_80_cmd = 0;

    screen_size_x_buf = 0;
    screen_size_y_buf = 0;
    video_memory_base_buf = 0;
    video_memory_size_buf = 0;

    tape_8002_as_output = 0;

    video_memory_base = 0;
    video_memory_size = 0;
    video_screen_size_x = 0;
    video_screen_size_y = 0;
    video_screen_cursor_x = 0;
    video_screen_cursor_y = 0;
}

unsigned char* rk86_memory(void) {
    return &memory[0];
}

void rk86_hardware_print_screen_settings() {
    console_printf("RK86 screen size: %d x %d\r\n"
                   "RK86 video area : %04X-%04X (%04X)\r\n"
                   "Cursor position : X=%d Y=%d\r\n",
                   video_screen_size_x, video_screen_size_y,
                   video_memory_base,
                   video_memory_base + video_memory_size - 1,
                   video_memory_size,
                   video_screen_cursor_x, video_screen_cursor_y);
}

