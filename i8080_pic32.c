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

#include "i8080.h"

#include "maximite.h"
#include <p32xxxx.h>
#include <plib.h>

#include "console.h"
#include "rk86_memory.h"
#include "rk86_keyboard.h"

static volatile int hard_reset;
static volatile int soft_reset;

static int emulator_advance;

#define I8080_FREQ          1780000                  // Not exactly 2MHz.
#define I8080_CYCLE_PERIOD  (BUSFREQ / I8080_FREQ)   // 80MHz / 2MHz = 40

void i8080_pic32_hard_reset() {
    hard_reset = 1;
}

void i8080_pic32_soft_reset() {
    soft_reset = 1;
}

void i8080_pic32_run() {
    int pic_ticks;
    hard_reset = 1;
    soft_reset = 0;
    OpenTimer2(T2_ON | T2_PS_1_1, 0xFFFF);
    while (1) {
        WriteTimer2(0);
        process_console();
        if (hard_reset) {
            rk86_memory_init();
            hard_reset = 0;
            soft_reset = 1;
        }
        if (soft_reset) {
            rk86_keyboard_init();  // Clear Radio-86RK keyboard.
            rk86_hardware_init();  // Reset VG75 and DMA contoller settings.
            i8080_init();
            soft_reset = 0;
        }
        pic_ticks = i8080_instruction() * I8080_CYCLE_PERIOD;
        emulator_advance = pic_ticks - (int)ReadTimer2();
        maximite_led_red(emulator_advance >= 0 ? 0 : 1);
        while ((int)ReadTimer2() < pic_ticks);
    }
}

void i8080_pic32_print_cpu_info() {
    console_printf("I8080 FREQUENCY    : %d\n\r"
                   "PIC32 FREQUENCY    : %d\n\r"
                   "I8080 CYCLE PERIOD : %d\n\r"
                   "EMULATOR ADVANCE   : %d (%X)\n\r",
                   I8080_FREQ,
                   BUSFREQ,
                   I8080_CYCLE_PERIOD,
                   emulator_advance, emulator_advance);
}

void i8080_pic32_jump(int addr) {
    i8080_jump(addr);
}
