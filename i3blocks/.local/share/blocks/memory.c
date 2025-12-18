#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define URGENT_MEM 90
#define URGENT_SWAP 50

static void format_bytes(const unsigned long long kb, char *out, const size_t out_size) {
    const double bytes = (double)kb * 1024.0;
    if (bytes >= 1099511627776.0) {
        snprintf(out, out_size, "%.3ftb", bytes / 1099511627776.0);
    } else if (bytes >= 1073741824.0) {
        snprintf(out, out_size, "%.2fgb", bytes / 1073741824.0);
    } else if (bytes >= 1048576.0) {
        snprintf(out, out_size, "%.1fmb", bytes / 1048576.0);
    } else {
        snprintf(out, out_size, "%.0fkb", bytes / 1024.0);
    }
}

int main(void) {
    const char *instance = getenv("BLOCK_INSTANCE");
    if (!instance || !*instance) {
        instance = "mem;free";
    }

    /* Parse source;display */
    char source[16] = "mem";
    char display[16] = "free";
    const char *sep = strchr(instance, ';');
    if (sep) {
        const size_t slen = sep - instance;
        if (slen > 0 && slen < sizeof(source)) {
            memcpy(source, instance, slen);
            source[slen] = '\0';
        }
        if (sep[1]) {
            strncpy(display, sep + 1, sizeof(display) - 1);
        }
    } else {
        strncpy(source, instance, sizeof(source) - 1);
    }

    const int urgent_value = strcmp(source, "swap") == 0 ? URGENT_SWAP : URGENT_MEM;
    const bool is_swap = strcmp(source, "swap") == 0;

    /* Read /proc/meminfo */
    FILE *f = fopen("/proc/meminfo", "r");
    if (!f) {
        return 1;
    }

    unsigned long long mem_total = 0, mem_available = 0;
    unsigned long long swap_total = 0, swap_free = 0;
    char line[128];

    while (fgets(line, sizeof(line), f)) {
        unsigned long long val;
        if (sscanf(line, "MemTotal: %llu kB", &val) == 1) {
            mem_total = val;
        } else if (sscanf(line, "MemAvailable: %llu kB", &val) == 1) {
            mem_available = val;
        } else if (sscanf(line, "SwapTotal: %llu kB", &val) == 1) {
            swap_total = val;
        } else if (sscanf(line, "SwapFree: %llu kB", &val) == 1) {
            swap_free = val;
        }
    }
    fclose(f);

    unsigned long long total, avail;
    if (is_swap) {
        total = swap_total;
        avail = swap_free;
    } else {
        total = mem_total;
        avail = mem_available;
    }

    if (total == 0) {
        return 0;
    }

    const unsigned long long used = total - avail;
    const int perc = (int)(used * 100 / total);

    char out[32];
    if (strcmp(display, "perc") == 0) {
        printf("%d%%\n", perc);
    } else if (strcmp(display, "used") == 0) {
        format_bytes(used, out, sizeof(out));
        puts(out);
    } else if (strcmp(display, "total") == 0) {
        format_bytes(total, out, sizeof(out));
        puts(out);
    } else { /* free */
        format_bytes(avail, out, sizeof(out));
        puts(out);
    }

    if (perc > urgent_value) {
        return 33;
    }

    return 0;
}
