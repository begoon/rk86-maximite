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

// PIC32MX795F512H or PIC32MX695F512H configuration switches.

#ifndef CONFIGURATION_H
#define CONFIGURATION_H

// Oscillator Selection:
// PRI      is Primary oscillator (XT, HS, EC)
// PRIPLL   is Primary oscillator (XT, HS, EC) w/ PLL
// SOSC     is Secondary oscillator
// LPRC     is Low power RC oscillator
// FRC      is Fast RC oscillator
// FRCPLL   is Fast RC oscillator w/ PLL
// FRCDIV16 is Fast RC oscillator with divide by 16
// FRCDIV   is Fast RC oscillator with divide
#pragma config FNOSC = PRIPLL

// Primary Oscillator Selection:
// HS       is HS oscillator
// EC       is EC oscillator
// XT       is XT oscillator
// OFF      is Disabled
#pragma config POSCMOD = HS

// IMPORTANT: If any of these are changed you must update CLOCKFREQ
// in Maximite.h

// PLL Input Divide by 1, 2, 3, 4, 5, 6 or 10
#pragma config FPLLIDIV = DIV_2
// PLL Multiply by 15, 16, 17, 18, 19, 20, 21 or 24
#pragma config FPLLMUL = MUL_20
// PLL Output Divide by 1, 2, 4, 8, 16, 32, 64, or 256
#pragma config FPLLODIV = DIV_1

// IMPORTANT: THIS HAS NO EFFECT.
// Peripheral Bus Clock Divide by 1, 2, 4 or 8
#pragma config FPBDIV = DIV_2

// Secondary oscillator OFF or ON.
#pragma config FSOSCEN = OFF
// Internal External Switchover (Two-Speed Start-up) OFF or ON.
#pragma config IESO = OFF
// CLKO output signal active on the OSCO pin. Select ON or OFF.
#pragma config OSCIOFNC = OFF

// Clock Switching and Monitor Selection:
// CSECME   is Clock Switching Enabled, Clock Monitoring Enabled
// CSECMD   is Clock Switching Enabled, Clock Monitoring Disabled
// CSDCMD   is Clock Switching Disabled, Clock Monitoring Disabled
#pragma config FCKSM = CSDCMD

#ifdef __DEBUG
#pragma config DEBUG = ON           // Background Debugger ON or OFF
#else
#pragma config DEBUG = OFF          // Background Debugger ON or OFF
#endif

// USB PLL ON or OFF
#pragma config UPLLEN = ON
// USB PLL Input Divide by 1, 2, 3, 4, 5, 6, 10 or 12
#pragma config UPLLIDIV = DIV_2

// USB VBUS_ON pin control:
// OFF      is by the Port Function
// ON       is by the USB Module
#pragma config FVBUSONIO = ON

// USB USBID pin control:
// OFF      is by the Port Function
// ON       is by the USB Module
#pragma config FUSBIDIO = OFF

#if defined(__32MX795F512H__) || defined(__32MX795F512L__)
// CAN IO Pins. OFF = Alternate, ON = Default.
#pragma config FCANIO = ON
#endif

// Ethernet IO Pins. OFF = Alternate, ON = Default.
#pragma config FETHIO = ON
// Ethernet MII Enable. OFF = RMII enabled, ON = MII enabled.
#pragma config FMIIEN = OFF

// SRS Interrupt Priority in the range of 0 to 7.
#pragma config FSRSSEL = PRIORITY_7

// Watchdog Timer ON or OFF
#pragma config FWDTEN = OFF
// Watchdog Timer Postscale from 1:1 to 1:1,048,576.
#pragma config WDTPS = PS1

// Code Protect Enable ON or OFF (prevents ANY read/write).
#pragma config CP = OFF
// Boot Flash Write Protect ON or OFF.
#pragma config BWP = OFF

// Program Flash Write Protect ON, OFF or PWP4K to PWP512K
// in steps of 6.
#pragma config PWP = OFF

// ICE/ICD Communications Channel Select
#if defined(MAXIMITE) || defined(DUINOMITE)
// ICS_PGx1 is ICE pins are shared with PGC1, PGD1.
#pragma config ICESEL = ICS_PGx1
#endif

#if defined(UBW32)
// ICS_PGx2 is ICE pins are shared with PGC2, PGD2.
#pragma config ICESEL = ICS_PGx2
#endif

#endif
