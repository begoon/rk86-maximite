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

#ifndef SDCARD_H
#define SDCARD_H

extern int sdcard_init(void);
extern int sdcard_load_rk86_file(const char* name, int offset);
extern void sdcard_load_binary_file(const char* name, char* buf, int const buf_sz);
extern void sdcard_ls(void);

#endif
