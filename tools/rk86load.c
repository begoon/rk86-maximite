#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <ctype.h>
#include <unistd.h>
#include <assert.h>

int open_canon_mode(char const* const dev) {
  int const baudrate = B115200;
  struct termios tio;

  int fd = open(dev, O_RDWR | O_NOCTTY); 
  if (fd < 0) {
    perror(dev);
    exit(-1);
  }

  bzero(&tio, sizeof(tio));
  tio.c_cflag = baudrate | CS8 | CLOCAL | CREAD;
  tio.c_iflag = IGNPAR | ICRNL;
  tio.c_oflag = 0;
  tio.c_lflag = ICANON;
  tio.c_cc[VEOF] = 4;   /* CTRL-D */
  tio.c_cc[VMIN] = 1;   /* Blocking read until 1 character arrives. */

  tcflush(fd, TCIFLUSH);
  tcsetattr(fd, TCSANOW, &tio);

  return fd;
}

int run(char const* const cmd, int fd) {
  static char buf[256];
  write(fd, cmd, strlen(cmd));
  while (1) {
    int const nb = read(fd, buf, sizeof(buf) - 1); 
    buf[nb] = 0;
    if (strstr(buf, "OK\n") || strstr(buf, "OK\r")) return 1;
    printf("%s", buf);
    if (strstr(buf, "ERROR, ")) return 0;
  }
  return 0;
}

int main(int argc, char* argv[]) {
  char const* dev = "/dev/cu.usbmodem621";
  int usb = open_canon_mode(dev);
  assert(usb != -1);
  assert(run("?\n", usb));
  char const* cmd = getenv("CMD");
  if (cmd != NULL) {
    char cmd_crlf[1024];
    strcpy(cmd_crlf, cmd);
    strcat(cmd_crlf, "\n");
    run(cmd_crlf, usb);
  } else {
    assert(argc > 1);
    FILE* in = fopen(argv[1], "r+");
    assert(in != NULL);
    while (!feof(in)) {
      char line[1024];
      int len, addr, type;
      if (fgets(line, sizeof(line) - 1, in) == NULL) break;
      printf("%s", line);
      assert(sscanf(line, ":%02X%04X%02X", &len, &addr, &type));
      if (type != 0) continue;
      run(line, usb);
    }
    fclose(in);
  }
  return 0;
}
