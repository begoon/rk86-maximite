all: build load run

IMAGE=test

build:
	asm8080 -l$(IMAGE).lst $(IMAGE).asm

load:
	rk86load $(IMAGE).hex

run:
	CMD="go 0000" rk86load

clean:
	-rm $(IMAGE).hex $(IMAGE).bin
