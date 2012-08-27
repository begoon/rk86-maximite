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

#include <p32xxxx.h>                    // Device specific defines.
#include <plib.h>                       // Peripheral libraries.

#include "maximite.h"

// This period is given in microseconds.
#define PANIC_LED_FLASH_PERIOD  (200*1000)
#define PANIC_LED_PAUSE         (700*1000)

void panic(int code) {
    while(1) {
        int i;
        for (i = 0; i < code; ++i) {
            if (maximite_program_button()) maximite_reset();
            delay_us(PANIC_LED_FLASH_PERIOD);
            maximite_led_red(1);
            if (maximite_program_button()) maximite_reset();
            delay_us(PANIC_LED_FLASH_PERIOD);
            maximite_led_red(0);
        }
        delay_us(PANIC_LED_PAUSE);
    }
}
