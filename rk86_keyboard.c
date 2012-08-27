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

#include "rk86_keyboard.h"
#include "rk86_memory.h"

#include <string.h>

static unsigned char keyboard_state[8];
static unsigned char keyboard_modifiers;

static struct {
  unsigned short ps2_code;
  unsigned char row, mask;
} table[] = {
    { 0xE06C, 0, 0x01 }, //  \\  -> HOME
    { 0xE069, 0, 0x02 }, // CTP  -> END
    { 0xE070, 0, 0x04 }, // AP2  -> INS
    { 0x0005, 0, 0x08 }, //  Ф1 -> F1
    { 0x0006, 0, 0x10 }, //  Ф2 -> F2
    { 0x0004, 0, 0x20 }, //  Ф3 -> F3
    { 0x000C, 0, 0x40 }, //  Ф4 -> F4
                         
    { 0x000D, 1, 0x01 }, // TAB 
    { 0xE05A, 1, 0x02 }, //  ПС -> EXT ENTER
    { 0x005A, 1, 0x04 }, //  BK -> ENTER
    { 0x0066, 1, 0x08 }, //  ЗБ -> BS
    { 0xE06B, 1, 0x10 }, //  <- 
    { 0xE075, 1, 0x20 }, //  UP
    { 0xE074, 1, 0x40 }, //  -> 
    { 0xE072, 1, 0x80 }, //  DOWN
                         
    { 0x0045, 2, 0x01 }, //   0 
    { 0x0016, 2, 0x02 }, //   1 
    { 0x001E, 2, 0x04 }, //   2 
    { 0x0026, 2, 0x08 }, //   3 
    { 0x0025, 2, 0x10 }, //   4 
    { 0x002E, 2, 0x20 }, //   5 
    { 0x0036, 2, 0x40 }, //   6 
    { 0x003D, 2, 0x80 }, //   7 
                         
    { 0x003E, 3, 0x01 }, //   8 
    { 0x0046, 3, 0x02 }, //   9 
    { 0x007C, 3, 0x04 }, //   * 
    { 0x004C, 3, 0x08 }, //   ; 
    { 0x0041, 3, 0x10 }, //   , 
    { 0x004E, 3, 0x20 }, //   - 
    { 0x0049, 3, 0x40 }, //   . 
    { 0x004A, 3, 0x80 }, //   / 
                         
    { 0xE04A, 4, 0x01 }, //   @ -> EXT /  
    { 0x001C, 4, 0x02 }, //   A 
    { 0x0032, 4, 0x04 }, //   B 
    { 0x0021, 4, 0x08 }, //   C 
    { 0x0023, 4, 0x10 }, //   D 
    { 0x0024, 4, 0x20 }, //   E 
    { 0x002B, 4, 0x40 }, //   F 
    { 0x0034, 4, 0x80 }, //   G 
                         
    { 0x0033, 5, 0x01 }, //   H 
    { 0x0043, 5, 0x02 }, //   I 
    { 0x003B, 5, 0x04 }, //   J 
    { 0x0042, 5, 0x08 }, //   K 
    { 0x004B, 5, 0x10 }, //   L 
    { 0x003A, 5, 0x20 }, //   M 
    { 0x0031, 5, 0x40 }, //   N 
    { 0x0044, 5, 0x80 }, //   O 
                         
    { 0x004D, 6, 0x01 }, //   P 
    { 0x0015, 6, 0x02 }, //   Q 
    { 0x002D, 6, 0x04 }, //   R 
    { 0x001B, 6, 0x08 }, //   S 
    { 0x002C, 6, 0x10 }, //   T 
    { 0x003C, 6, 0x20 }, //   U 
    { 0x002A, 6, 0x40 }, //   V 
    { 0x001D, 6, 0x80 }, //   W 
                         
    { 0x0022, 7, 0x01 }, //   X 
    { 0x0035, 7, 0x02 }, //   Y 
    { 0x001A, 7, 0x04 }, //   Z 
    { 0x0054, 7, 0x08 }, //   [ 
    { 0x005D, 7, 0x10 }, //   \ (back slash)
    { 0x004A, 7, 0x20 }, //   ] 
    { 0x000E, 7, 0x40 }, //   ^   -> `
    { 0x0029, 7, 0x80 }, // SPC 
    { 0x0000, 0, 0x00 },
};

const int SS = 0x20;
const int US = 0x40;
const int RL = 0x80;

void rk86_keyboard_init(void) {
    memset(keyboard_state, 0xff, sizeof keyboard_state);
    keyboard_modifiers = 0xff;
}

void rk86_keyboard(int code, int key_E0, int key_up_code) {
    if (key_E0)
        code |= 0xE000;
    if (!key_up_code) {
        int i;
        // L-SHIFT and R-SHIFT for SS.
        if (code == 0x12 || code == 0x59) {
            keyboard_modifiers &= ~SS;
        }
        // L-CTRL and R-CTRL for US.
        if (code == 0x14) {
            keyboard_modifiers &= ~US; 
        }
        // CAPS for RL.
        if (code == 0x58) keyboard_modifiers &= ~RL;
        for (i = 0; table[i].ps2_code; ++i) {
            if (table[i].ps2_code == code) {
                keyboard_state[table[i].row] &= ~table[i].mask;
                break;
            }
        }
    } else {
        int i;
        // L-ShIFT and R-SHIFT for SS.
        if (code == 0x12 || code == 0x59) {
            keyboard_modifiers |= SS;
        }
        // L-CTRL and R-CTRL for US.
        if (code == 0x14 || code == 0xE014) {
            keyboard_modifiers |= US;
        }
        // CAPS for RL.
        if (code == 0x58) keyboard_modifiers |= RL;
        for (i = 0; table[i].ps2_code; ++i) {
            if (table[i].ps2_code == code) {
                keyboard_state[table[i].row] |= table[i].mask;
                break;
            }
        }
    }
}

unsigned char* rk86_keyboard_state(void) {
    return keyboard_state;
}

unsigned char rk86_keyboard_modifiers(void) {
    return keyboard_modifiers;
}
