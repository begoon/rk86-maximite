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

#define GREEN_LED            PORTFbits.RF0
#define GREEN_LED_TRIS       TRISFbits.TRISF0 

#define RED_LED              PORTEbits.RE1
#define RED_LED_TRIS         TRISEbits.TRISE1

#define PROGRAM_BUTTON       PORTCbits.RC13
#define PROGRAM_BUTTON_TRIS  TRISCbits.TRISC13

#define SOUND                PORTBbits.RB4 
#define SOUND_TRIS           TRISBbits.TRISB4

void maximite_init() {
    GREEN_LED_TRIS = 0;
    RED_LED_TRIS = 0;

    maximite_led_green(1); 
    maximite_led_red(0); 

    PROGRAM_BUTTON_TRIS = 1;
    SOUND_TRIS = 0;
}

void maximite_led_green(int on) {
    GREEN_LED = on; 
}

void maximite_led_green_flip(void) {
    GREEN_LED = !GREEN_LED; 
}

void maximite_led_red(int on) {
    RED_LED = on; 
}

void maximite_led_red_flip(void) {
    RED_LED = !RED_LED; 
}

int maximite_program_button(void) {
    return PROGRAM_BUTTON == 0;
}

void maximite_sound(int on) {
    SOUND = on;
}

void maximite_reset(void) {
    SoftReset();
}
