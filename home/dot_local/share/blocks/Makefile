CC ?= gcc
CFLAGS ?= -O2 -Wformat -Wformat-security -Wall -Wextra -Wstrict-prototypes -Wmissing-prototypes \
          -Wsuggest-attribute=pure -Wsuggest-attribute=const -Wsuggest-attribute=format \
          -Wshadow -Wdouble-promotion -Wnull-dereference -Wcast-qual -Wundef \
          -Wduplicated-cond -Wduplicated-branches -Wlogical-op \
          -fno-common -fstack-protector-strong -D_FORTIFY_SOURCE=3 -std=gnu17

# Use EXTRA_CFLAGS to append flags, CFLAGS to override entirely
# Example: make EXTRA_CFLAGS="-g" or make CFLAGS="-O0 -g"
ALL_CFLAGS = $(CFLAGS) $(EXTRA_CFLAGS) -Werror

SRCS = $(wildcard *.c)
BINS = $(SRCS:.c=)

all: $(BINS)

%: %.c
	$(CC) $(ALL_CFLAGS) -o $@ $<

clean:
	rm -f $(BINS)

.PHONY: all clean
