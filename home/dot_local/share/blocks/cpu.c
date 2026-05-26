#include <stdio.h>

#include "block_output.h"

#define STATE_FILE "/tmp/.cpu"
#define URGENT_THRESHOLD 90

int main(void) {
    unsigned long long prev_total = 0, prev_idle = 0;

    /* Read previous state (two lines: total, idle) */
    FILE *f = fopen(STATE_FILE, "r");
    if (f) {
        if (fscanf(f, "%llu\n%llu", &prev_total, &prev_idle) != 2) {
            prev_total = prev_idle = 0;
        }
        fclose(f);
    }

    /* Read current CPU stats */
    f = fopen("/proc/stat", "r");
    if (!f) {
        return 1;
    }

    unsigned long long user, nice, system, idle;
    if (fscanf(f, "cpu %llu %llu %llu %llu", &user, &nice, &system, &idle) != 4) {
        fclose(f);
        return 1;
    }
    fclose(f);

    const unsigned long long total = user + nice + system + idle;

    /* Save state for next run (two lines: total, idle) */
    f = fopen(STATE_FILE, "w");
    if (f) {
        fprintf(f, "%llu\n%llu\n", total, idle);
        fclose(f);
    }

    if (prev_total == 0) {
        block_output_print_text("?");
        return 0;
    }

    const unsigned long long diff_total = total - prev_total;
    const unsigned long long diff_idle = idle - prev_idle;
    if (diff_total == 0) {
        return 0;
    }

    const int usage_pct = (int)((1000 * (diff_total - diff_idle) / diff_total + 5) / 10);
    char output[16];
    snprintf(output, sizeof(output), "%d%%", usage_pct);
    return block_output_emit(output, usage_pct > URGENT_THRESHOLD, BLOCK_COLOR_CRITICAL);
}
