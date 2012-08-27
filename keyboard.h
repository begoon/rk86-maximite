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

// The values returned by the standard control keys.
#define TAB         0x9
#define BKSP        0x8
#define ENTER       0xd
#define ESC         0x1b

// The values returned by the function keys.
#define F1          0x91
#define F2          0x92
#define F3          0x93
#define F4          0x94
#define F5          0x95
#define F6          0x96
#define F7          0x97
#define F8          0x98
#define F9          0x99
#define F10         0x9a
#define F11         0x9b
#define F12         0x9c

// The values returned by special control keys.
#define UP          0x80
#define DOWN        0x81
#define LEFT        0x82
#define RIGHT       0x83
#define INSERT      0x84
#define DEL         0x7f
#define HOME        0x86
#define END         0x87
#define PUP         0x88
#define PDOWN       0x89
#define NUML        0x8a
#define NUM_ENT     ENTER
#define SLOCK       0x8c
#define ALT         0x8b

extern void keyboard_init(void);
extern int keyboard_inkey(void);
