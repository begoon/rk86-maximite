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

#if !defined(MAXIMITE)
#error Must define the target hardware in the project file
#endif

#include <p32xxxx.h>                    // Device specific defines.
#include <plib.h>                       // Peripheral libraries.
#include <stdlib.h>                     // Standard library functions.
#include <string.h>                     // String functions.

#include "maximite.h"                   // Helpful defines.
#include "configuration.h"              // Config pragmas.

#include "i8080_pic32.h"
#include "keyboard.h"
#include "usb.h"
#include "panic.h"

#include "rk86_video.h"

int main(void) {
    // Initialize LED, sound and the program button pins.
    maximite_init();

    // Initial setup of the I/O ports.
    AD1PCFG = 0xFFFF;               // Default all pins to digital.
    mJTAGPortEnable(0);             // Turn off JTAG.

    // Setup the CPU.
    // System config performance.
    SYSTEMConfigPerformance(CLOCKFREQ);
    // Fix the peripheral bus to the main clock speed.
    mOSCSetPBDIV(OSC_PB_DIV_1);

    INTEnableSystemMultiVectoredInt();  // Allow vectored interrupts.

    usb_init();
    keyboard_init();       // Initialise and startup the keyboard routines.

    rk86_video_init();     // Start the video state machine.

    delay_us(1000);
    while (keyboard_inkey() != -1);

    i8080_pic32_run();

    panic(PANIC_EMULATION_TERMINATED);

    return 0;
}
