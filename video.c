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

#include <p32xxxx.h>
#include <plib.h>
#include <string.h>

#include "maximite.h"
#include "video.h"

// Video defines PINs.
#define P_VGA_COMP          PORTCbits.RC14          // VGA/Composite jumper
#define P_VGA_SELECT        1                       // State when VGA selected
#define P_VGA_COMP_PULLUP   CNPUEbits.CNPUE0

#define P_VIDEO_SPI         2                       // The SPI peripheral used for video
                                                    // Note: PIN G9 is automatically set as the framing input
#define P_SPI_INPUT         SPI2ABUF                // Input buffer for the SPI peripheral
#define P_SPI_INTERRUPT     _SPI2A_TX_IRQ           // Interrupt used by the video DMA
#define P_VID_OC_OPEN       OpenOC3                 // The function used to open the output compare
#define P_VID_OC_REG        OC3R                    // The output compare register

#define P_VIDEO             PORTGbits.RG8           // Video
#define P_VIDEO_TRIS        TRISGbits.TRISG8

#define P_HORIZ             PORTDbits.RD2           // Horizontal sync
#define P_HORIZ_TRIS        TRISDbits.TRISD2

#define P_VERT_SET_HI       LATFSET = (1 << 1)      // Set vert sync hi
#define P_VERT_SET_LO       LATFCLR = (1 << 1)      // Set vert sync lo
#define P_VERT_TRIS         TRISFbits.TRISF1

// States of the vertical sync state machine.
#define SV_PREEQ    0                                               // Generating blank lines before the vert sync
#define SV_SYNC     1                                               // Generating the vert sync
#define SV_POSTEQ   2                                               // Generating blank lines after the vert sync
#define SV_LINE     3                                               // Visible lines, send the video data out

static int vert_resolution, horiz_resolution;                       // Global vert and horiz resolution in pixels on the screen

// Define the video buffer.
// Note that this can differ from the pixel resolution, for example for
// composite horiz_resolution is not an even multiple of 32 where
// horiz_buf is.
static int vert_buf, horiz_buf;                                     // Global vert and horiz resolution of the video buffer

static int *video_memory = NULL;                                    // Image buffer. Contains the bitmap video image.

volatile static int vcount;                                         // Counter for the number of lines in a frame
volatile static int vstate;                                         // The state of the state machine

static int VS[4] = { SV_SYNC, SV_POSTEQ, SV_LINE, SV_PREEQ };       // The next state table
static int VC[4];                                                   // The next counter table (initialise in video_init() below)

// Round up to the nearest page size.
#define PAGESIZE          256
#define PAGE_ROUND_UP(a)  (((a) + (PAGESIZE - 1)) & (~(PAGESIZE - 1)))

extern unsigned int _splim;

#define VGA_LINE_N      525     // number of lines in VGA frame
#define VGA_LINE_T      2540    // Tpb clock in a line (31.777us)
#define VGA_VSYNC_N     2       // V sync lines
#define VGA_PIX_T       4       // Tpb clock per pixel
#define VGA_HSYNC_T     300     // Tpb clock width horizontal pulse
#define VGA_BLANKPAD    5       // number of zero bytes before sending data

static void video_clear_screen(void);

void video_start(const int VGA_HRES, const int VGA_VRES) {
    mT3IntEnable(0);        // Disable Timer3 Interrupt.
    
    // Setup the I/O pins used by the video.
    CNCONbits.ON = 1;       // Turn on Change Notification module.
    P_VGA_COMP_PULLUP = 1;  // Turn on the pullup for pin C14 also called CN0.

    // Parameters for VGA video with 31.5KHz horizontal scanning and 60Hz
    // vertical refresh.

    // Nbr of blank lines.
    int const VGA_VBLANK_N = VGA_LINE_N - VGA_VRES - VGA_VSYNC_N;
    // Nbr blank lines at the bottom of the screen.
    int const VGA_PREEQ_N = VGA_VBLANK_N/2 - 12;
    // Nbr blank lines at the top of the screen
    int const VGA_POSTEQ_N = VGA_VBLANK_N - VGA_PREEQ_N;

    P_VIDEO_TRIS = 0;   // Video output
    P_HORIZ_TRIS = 0;   // Horiz sync output
    P_VERT_TRIS = 0;    // Vert sync output used by VGA

    vert_buf = vert_resolution = VGA_VRES;
    horiz_resolution = VGA_HRES;
    horiz_buf = ((VGA_HRES + 31) / 32) * 32;
    // Setup the table used to count lines.
    VC[0] = VGA_VSYNC_N;
    VC[1] = VGA_POSTEQ_N;
    VC[2] = VGA_VRES;
    VC[3] = VGA_PREEQ_N;
    // Enable the SPI channel which will clock the video data out.
    // Set master and framing mode. The last argument sets the speed.
    SpiChnOpen(P_VIDEO_SPI, SPICON_ON | SPICON_MSTEN | SPICON_MODE32 |
                            SPICON_FRMEN | SPICON_FRMSYNC | SPICON_FRMPOL,
               VGA_PIX_T);
    // Enable the output compare which is used to time the width of the
    // horiz sync pulse.
    P_VID_OC_OPEN(OC_ON | OC_TIMER3_SRC | OC_CONTINUE_PULSE, 0, VGA_HSYNC_T);
    // Enable timer 3 and set to the horizontal scanning frequency.
    OpenTimer3(T3_ON | T3_PS_1_1 | T3_SOURCE_INT, VGA_LINE_T-1);

    video_memory = (int *)(PAGE_ROUND_UP((unsigned int)&_splim));
    video_clear_screen();

    vstate = SV_PREEQ;     // Initialise the state machine.
    vcount = 1;            // Set the count so that the first interrupt 
                           // will increment the state.

    // Setup DMA 1 to send data to SPI channel 2.
    DmaChnOpen(1, 1, DMA_OPEN_DEFAULT);
    DmaChnSetEventControl(1, DMA_EV_START_IRQ_EN |
                             DMA_EV_START_IRQ(P_SPI_INTERRUPT));

    DmaChnSetTxfer(1, (void *)video_memory, (void *)&P_SPI_INPUT,
                   horiz_buf/8, 4, 4);

    mT3SetIntPriority(7);   // Set priority level 7 for the timer 3 
                            // interrupt to use shadow register set.
    mT3IntEnable(1);        // Enable Timer3 Interrupt.
}

// Timer 3 interrupt.
// Used to generate the horiz and vert sync pulse under control of the state machine.
void __ISR(_TIMER_3_VECTOR, ipl7) T3Interrupt(void) {
    static int *vptr;

    switch (vstate) {                                               // Vertical state machine.
        case SV_PREEQ:  // 0
            vptr = video_memory;                                    // Prepare for the new frame.
            break;

        case SV_SYNC:   // 1
            P_VERT_SET_LO;                                          // Start the vertical sync pulse for VGA.
            break;

        case SV_POSTEQ: // 2
            P_VERT_SET_HI;                                          // End of the vertical sync pulse for VGA.
            break;

        case SV_LINE:   // 3
            P_SPI_INPUT = 0;                                        // Preload the SPI with 4 zero bytes to pad the start of the video.
            DCH1SSA = KVA_TO_PA((void*) (vptr));                    // Update the DMA1 source address (DMA1 is used for VGA data).
            vptr += horiz_buf/32;                                   // Move the pointer to the start of the next line.
            DmaChnEnable(1);                                        // Arm the DMA transfer.
            break;
   }

    if (--vcount == 0) {                                            // Count down the number of lines.
        vcount = VC[vstate & 3];                                    // Set the new count.
        vstate = VS[vstate & 3];                                    // And advance the state machine.
    }

    mT3ClearIntFlag();                                              // Clear the interrupt flag
}

// Clear the screen.
static void video_clear_screen(void) {
    memset(video_memory, 0, vert_buf*(horiz_buf/8));
}

// Turn on or off a single pixel in the graphics buffer.
void video_draw_pixel(int x, int y, int b) {
    int const offset = y * (horiz_buf/32) + x/32;
    int const value = 0x80000000 >> (x & 0x1f);

    if (b == 0)
        video_memory[offset] &= ~value;        // Turn off the pixel
    else if (b == -1)
        video_memory[offset] ^= value;         // Invert the pixel. Thanks to Alan Williams for the contribution.
    else
        video_memory[offset] |= value;         // Turn on the pixel.
}
