# Makefile for basic_arinc

CC	:= gcc
CFLAGS	:= -Wall
LDFLAGS	:= -lxenctrl -lxenlight -luuid
TARGET	:= basic_arinc
SRC	:= basic_arinc.c

.PHONY:	all clean

all:	$(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)

clean:
	rm -f $(TARGET)
