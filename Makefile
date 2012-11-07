all: generate_rom compile link hex

DEVICE = 32MX795F512H

IMAGE = rk86_maximite

DEFINES = -DMAXIMITE -DPIC32MX795F512L_PIM

ifeq ($(OS),Windows_NT)
  XC32_HOME = c:/xc32
else
  XC32_HOME = /Applications/microchip/xc32/v1.11
endif

XC32_PREFIX=$(XC32_HOME)/bin/xc32
CHIPKIT32_PREFIX=/usr/local/pic32-tools/bin/pic32

ifeq ($(CHIPKIT32),1)
  CC_PREFIX=$(CHIPKIT32_PREFIX)
  CC_O=-O3
  SCRIPT=Maximite.ld.chipkit32
else
  CC_PREFIX=$(XC32_PREFIX)
  CC_O=-O3 -fipa-sra \
    -funroll-loops \
    -finline-functions \
    -fstrict-aliasing \
    -fomit-frame-pointer
  SCRIPT=Maximite.ld
endif

CC = $(CC_PREFIX)-gcc

INCLUDES = \
 -I. \
 -IUSB \
 -IUSB/Microchip/Include \
 -Isdcard/Microchip/Include \

CC_OPTS = \
  -mprocessor=$(DEVICE) \
  $(DEFINES) \
  $(INCLUDES) \
  -Wall $(CC_O) -G 2

LINKER = $(CC_PREFIX)-gcc

LINKER_OPTS = \
  -mprocessor=$(DEVICE) \
  -Wl,--script=./$(SCRIPT)

FILES = \
  ./video.c \
  ./keyboard.c \
  ./i8080.c \
  ./i8080_pic32.c \
  ./rk86_keyboard.c \
  ./rk86_video.c \
  ./rk86_memory.c \
  ./usb/usb_descriptors.c \
  ./usb/Microchip/USB/usb_device.c \
  ./usb/Microchip/USB/usb_function_cdc.c \
  ./usb.c \
  ./sdcard/Microchip/mddfs/FSIO.c \
  ./sdcard/Microchip/mddfs/SD-SPI.c \
  ./sdcard.c \
  ./rom/rom_files.c \
  ./rom.c \
  ./console.c \
  ./panic.c \
  ./maximite.c \
  ./selector.c \
  ./main.c \

OBJS = $(subst .c,.o,$(FILES))

%.o : %.c
	$(CC) $(CC_OPTS) -c $< -o $@

compile: $(OBJS)

link:
	$(LINKER) $(OBJS) $(LINKER_OPTS) -o $(IMAGE).out

hex:
	$(CC_PREFIX)-bin2hex $(IMAGE).out

load:
	mphidflash -r -v 04D8 -p FA8D -n -w $(IMAGE).hex

clean:
	-rm $(OBJS)
	-rm $(IMAGE).out $(IMAGE).hex
	cd rom && $(MAKE) clean

generate-files:
	echo "#include <string.h>"
	echo "struct {"
	echo "    char const* const name;"
	echo "    int const start, end, entry;"
	echo "    char const* const image;"
	echo "} files[] = {"
	cat files.c-temp
	echo "{ 0, 0, 0, 0, 0 }"
	echo "};"
	echo "//"
	echo "int file_load(unsigned char* to, const char* name) {"
	echo "    int i;"
	echo "    for (i = 0; files[i].name; ++i) {"
	echo "        if (!strcmp(name, files[i].name)) {"
	echo "            int const size = files[i].end - files[i].start + 1;"
	echo "            memcpy(to + files[i].start, files[i].image, size);"
	echo "            return 1;"
	echo "        }"
	echo "    }";
	echo "    return 0;"
	echo "}"

generate: generate-list
	$(MAKE) -s generate-files >files.c

generate_rom:
	cd rom && $(MAKE) -s
