#ifndef BLOCK_OUTPUT_H
#define BLOCK_OUTPUT_H

#include <stdbool.h>
#include <stdio.h>

#define BLOCK_OUTPUT_I3BLOCKS 1
#define BLOCK_OUTPUT_IRONBAR 2

#define BLOCK_COLOR_WARNING "#f0c674"
#define BLOCK_COLOR_CRITICAL "#cc6666"

/* i3blocks signals urgency to the bar via this process exit code. */
#define BLOCK_EXIT_URGENT 33

#ifndef BLOCK_OUTPUT_MODE
#define BLOCK_OUTPUT_MODE BLOCK_OUTPUT_I3BLOCKS
#endif

static inline bool block_output_is_i3blocks(void) {
    return BLOCK_OUTPUT_MODE == BLOCK_OUTPUT_I3BLOCKS;
}

static inline void block_output_print_text(const char *text) {
    printf("%s\n", text);
}

/* In i3blocks mode prints `full` and `short_text` on consecutive lines; if
 * `short_text` is NULL the full text is reused. In ironbar mode only the
 * full text is emitted (ironbar has no short variant). */
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

static inline int block_output_status(bool urgent) {
    return urgent && block_output_is_i3blocks() ? BLOCK_EXIT_URGENT : 0;
}

/* Print a block and return the exit code to propagate from main().
 *
 * In i3blocks mode urgency is communicated via the exit code; in ironbar
 * mode (long-lived blocks where exit codes are meaningless) urgency is
 * rendered inline as Pango markup using `urgent_color`. The color is only
 * consulted when `urgent` is true. */
static inline int block_output_emit(const char *text, bool urgent,
                                    const char *urgent_color) {
    if (urgent && !block_output_is_i3blocks()) {
        block_output_print_markup(text, urgent_color);
        return 0;
    }
    block_output_print_text(text);
    return block_output_status(urgent);
}

#endif
