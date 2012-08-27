all: build generate check

ifeq ($(OS),Windows_NT)
  CC = c:/tcc/tcc
  EXE = .exe
else
  CC = cc
endif

IMAGE = rk86dump$(EXE)

FILES = rk86dump.c
OBJS = $(subst .c,.o,$(FILES))

build:
	$(CC) -o $(IMAGE) $(FILES)

dump:
	cd files && \
		ls -1 > ../files.list && \
		../rk86dump <../files.list >../files.c-temp

generate: dump
	$(MAKE) -s join-files >rom_files.c

join-files:
	echo "struct {"
	echo "    char const* const name;"
	echo "    int const start, end, entry;"
	echo "    char compressed;"
	echo "    int size;"
	echo "    char const* const image;"
	echo "} rom_files[] = {"
	cat files.c-temp
	echo "{ 0, 0, 0, 0, 0, 0 }"
	echo "};"

check:
	$(CC) -o checker$(EXE) checker.c rom_files.c
	./checker

clean:
	-rm $(IMAGE) $(OBJS) files.list files.c-temp rom_files.c checker$(EXE)
