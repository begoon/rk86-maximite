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

#include "maximite.h"

// USB includes
#include "./USB/Microchip/Include/USB/usb.h"
#include "./USB/Microchip/Include/USB/usb_function_cdc.h"
#include "./USB/HardwareProfile.h"

#include "./USB/Microchip/Include/Compiler.h"
#include "./USB/usb_config.h"
#include "./USB/Microchip/Include/USB/usb_device.h"

extern void USBDeviceTasks(void);

// USB configuration
#define USB_RX_BUFFER_SIZE    128
#define USB_TX_BUFFER_SIZE    64

static char USB_RxBuf[USB_RX_BUFFER_SIZE];
static char USB_TxBuf[2][USB_TX_BUFFER_SIZE];
static volatile int USB_NbrCharsInTxBuf;
static volatile int USB_Current_TxBuf;

#define USB_INP_QUEUE_SIZE    256
static volatile int usb_inp_queue[USB_INP_QUEUE_SIZE];
static volatile int usb_inp_queue_head;
static volatile int usb_inp_queue_tail;

void usb_init(void) {
    USB_NbrCharsInTxBuf = 0;
    USB_Current_TxBuf = 0;

    usb_inp_queue_head = 0;
    usb_inp_queue_tail = 0;

    // Initilise the USB input/output subsystems.

    USBDeviceInit();             // Initialise USB module SFRs and firmware

    // Setup timer 1 to generate a regular interrupt to process
    // any USB activity.

    // Start polling at 100us. The interrupt will adjust this.
    PR1 = 100 * ((BUSFREQ/2)/1000000) - 1;
    T1CON = 0x8010;                                // T1 on, prescaler 1:8
    mT1SetIntPriority(4);                          // Medium priority
    mT1ClearIntFlag();                             // Clear interrupt flag
    mT1IntEnable(1);                               // Enable interrupt 
}

// USB related functions

// Timer 1 interrupt.
// Used to send and get data to or from the USB interface.
void __ISR (_TIMER_1_VECTOR, ipl4) T1Interrupt(void) {
    int i, nr_bytes_read;

    if (U1OTGSTAT & 1) {                                                     // Is there 5V on the USB?
        USBDeviceTasks();                                                    // Do any USB work.
        if (USBGetDeviceState() == DETACHED_STATE)                           // 5V on the USB but nothing happening.
            PR1 = 500 * ((BUSFREQ/8)/1000000) - 1;                           // Probably using USB power only (poll every 500us).
        else if(USBGetDeviceState() != CONFIGURED_STATE)                     // We are enumerating with the host.
            PR1 = 75 * ((BUSFREQ/8)/1000000) - 1;                            // Maximum speed while we are enumerating (poll every 75us).
        else {                                                               // We must have finished enumerating.
            // At this point we are connected and have enumerated.
            // We can now send and receive data.
            PR1 = 250 * ((BUSFREQ/8)/1000000) - 1;                           // Slow speed is only needed (poll every 250us).

            nr_bytes_read = getsUSBUSART(USB_RxBuf, USB_RX_BUFFER_SIZE);     // Check for data to be read.
            for (i = 0; i < nr_bytes_read; i++) {                            // If we have some data, copy it into the keyboard buffer.
                usb_inp_queue[usb_inp_queue_head] = USB_RxBuf[i];            // Add the byte in the keystroke buffer.
                // Increment the head of the queue.
                usb_inp_queue_head = (usb_inp_queue_head + 1) % USB_INP_QUEUE_SIZE;
            }

            // Check for data to be sent.
            if (USB_NbrCharsInTxBuf && mUSBUSARTIsTxTrfReady()) {
                // Send it.
                putUSBUSART(USB_TxBuf[USB_Current_TxBuf], USB_NbrCharsInTxBuf);
                USB_Current_TxBuf = !USB_Current_TxBuf;
                USB_NbrCharsInTxBuf = 0;
            }
            CDCTxService();                                                  // Send anything that needed sending.
        }
    }
    else
        PR1 = 1000 * ((BUSFREQ/8)/1000000) - 1;                              // Nothing is connected to the USB (poll every 1ms).

    mT1ClearIntFlag();                                                       // Clear the interrupt flag.
}

// ***************************************************************************
// BOOL USER_USB_CALLBACK_EVENT_HANDLER
// This function is called from the USB stack to notify a user application
// that a USB event occured. This callback is in interrupt context when the 
// USB_INTERRUPT option is selected.
//
// Args: event - the type of event 
//       *pdata - pointer to the event data
//       size - size of the event data
//
// This function was derived from the demo CDC program provided by Microchip
// ***************************************************************************
BOOL USER_USB_CALLBACK_EVENT_HANDLER(USB_EVENT event, void *pdata, WORD size) {
    switch(event) {
        case EVENT_CONFIGURED: 
            CDCInitEP();
            break;
        case EVENT_SET_DESCRIPTOR:
            break;
        case EVENT_EP0_REQUEST:
            USBCheckCDCRequest();
            break;
        case EVENT_SOF:
            break;
        case EVENT_SUSPEND:
            break;
        case EVENT_RESUME:
            break;
        case EVENT_BUS_ERROR:
            break;
        case EVENT_TRANSFER:
            Nop();
            break;
        default:
            break;
    }      
    return TRUE; 
}

// Send a character out to the USB interface.
void usb_send_char(char c) {
    static int delay_cnt = 0;
    
    // Check USB status
    if ((U1OTGSTAT & 1) == 0 || (USBDeviceState < CONFIGURED_STATE) || (USBSuspendControl == 1)) {
        USB_NbrCharsInTxBuf = 0;
        delay_cnt = 0;
        return;                                                     // Skip if the USB is not connected.
    }    
    
    // If the buffer is full we delay for a maximum of 5mS (at level 2 optimisation).
    // This will only delay once on buffer full and the delay will only be re enabled when something is sent
    while ((USB_NbrCharsInTxBuf >= USB_TX_BUFFER_SIZE) && delay_cnt < 57000) delay_cnt++;
    
    if (USB_NbrCharsInTxBuf < USB_TX_BUFFER_SIZE) {                 // Skip if the buffer is still full (not being drained).
        mT1IntEnable(0);                                            // Disable Timer1 Interrupt
        USB_TxBuf[USB_Current_TxBuf][USB_NbrCharsInTxBuf++] = c;    // Place char into the buffer
        mT1IntEnable(1);                                            // Enable Timer3 Interrupt
        delay_cnt = 0;
    }
}    

// Send a string out to the USB inferface.
void usb_send_string(const char* s) {
    while (*s) usb_send_char(*s++);
}

int usb_inkey(void) {
    int c = -1;
    if (usb_inp_queue_head != usb_inp_queue_tail) {
        c = usb_inp_queue[usb_inp_queue_tail];
        usb_inp_queue_tail = (usb_inp_queue_tail + 1) % USB_INP_QUEUE_SIZE;
        maximite_led_green_flip();
    }
   return c;
}
