#ifndef BLOCK_OUTPUT_H
#define BLOCK_OUTPUT_H

#include <stdio.h>

#define BLOCK_OUTPUT_I3BLOCKS 1
#define BLOCK_OUTPUT_IRONBAR 2

#define BLOCK_COLOR_WARNING "#f0c674"
#define BLOCK_COLOR_CRITICAL "#cc6666"

#ifndef BLOCK_OUTPUT_MODE
#define BLOCK_OUTPUT_MODE BLOCK_OUTPUT_I3BLOCKS
#endif

static inline int block_output_is_i3blocks(void) {
    return BLOCK_OUTPUT_MODE == BLOCK_OUTPUT_I3BLOCKS;
}

static inline void block_output_print_text(const char *text) {
    printf("%s\n", text);
}

static inline void block_output_print_full_short(const char *full,
                                                 const char *short_text) {
    if (block_output_is_i3blocks()) {
        printf("%s\n%s\n\n", full, short_text ? short_text : full);
    } else {
        block_output_print_text(full);
    }
}

static inline void block_output_print_markup(const char *text,
                                             const char *color) {
    printf("<span foreground=\"%s\">%s</span>\n", color, text);
}

static inline int block_output_status(int urgent) {
    return urgent && block_output_is_i3blocks() ? 33 : 0;
}

#endif
