all: build check

IMAGE=monitor32

build:
	asm8080 -l$(IMAGE).lst $(IMAGE).asm

check:
	diff $(IMAGE).bin ../rom/files/mon32.bin

clean:
	-rm $(IMAGE).hex $(IMAGE).bin $(IMAGE).lst
