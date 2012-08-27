// This file is part of Radio-86RK on Maximite project.
//
// Copyright (C) 2009 Alexander Demin <alexander@demin.ws>
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

#ifndef RK86_MEMORY_H
#define RK86_MEMORY_H

extern void rk86_memory_init(void);
extern void rk86_hardware_init(void);

extern int rk86_memory_read_word(int addr);
extern void rk86_memory_write_word(int addr, int word);

extern int rk86_memory_read_byte(int addr);
extern void rk86_memory_write_byte(int addr, int byte);

extern int rk86_io_input(int port);
extern void rk86_io_output(int port, int value);

extern unsigned char* rk86_memory(void);

extern void rk86_memory_refresh_video_area();

extern void rk86_hardware_print_screen_settings(void);

#endif
