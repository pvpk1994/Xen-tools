# Makefile for basic_arinc

CC	:= gcc
CFLAGS	:= -Wall
LDFLAGS	:= -lxenctrl -lxenlight -luuid -lcjson

# Config option to enable/disable dumping userspace schedules
ENABLE_DUMP	?= 0	# set this to 1 to enable dumping

ifeq ($(ENABLE_DUMP), 1)
	CFLAGS	+= -DENABLE_DUMP
endif

TARGET	:= basic_arinc
ARG	:= SCHED_GET
SRC	:= basic_arinc.c

.PHONY:	all clean

all:	$(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)

run:	$(TARGET)
	./$(TARGET) $(ARG)

clean:
	rm -f $(TARGET) sched.json
