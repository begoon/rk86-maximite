all: build load run

IMAGE=dumped

build:
	asm8080 $(IMAGE).asm

load:
	rk86load $(IMAGE).hex

run:
	CMD="go 3000" rk86load

clean:
	-rm $(IMAGE).hex $(IMAGE).bin
