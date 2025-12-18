#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/statvfs.h>

#define URGENT_VALUE 90

static void format_bytes(const unsigned long long bytes, char *out, size_t out_size) {
    if (bytes >= 1099511627776ULL) {
        snprintf(out, out_size, "%.1fT", bytes / 1099511627776.0);
    } else if (bytes >= 1073741824ULL) {
        snprintf(out, out_size, "%.1fG", bytes / 1073741824.0);
    } else if (bytes >= 1048576ULL) {
        snprintf(out, out_size, "%.1fM", bytes / 1048576.0);
    } else if (bytes >= 1024ULL) {
        snprintf(out, out_size, "%.1fK", bytes / 1024.0);
    } else {
        snprintf(out, out_size, "%lluB", bytes);
    }
}

int main(void) {
    const char *instance = getenv("BLOCK_INSTANCE");
    char path[256];
    char display[16] = "free";

    if (!instance || !*instance) {
        const char *home = getenv("HOME");
        snprintf(path, sizeof(path), "%s", home ? home : "/");
    } else {
        /* Parse path;display */
        const char *sep = strchr(instance, ';');
        if (sep) {
            size_t plen = sep - instance;
            if (plen >= sizeof(path)) {
                plen = sizeof(path) - 1;
            }
            memcpy(path, instance, plen);
            path[plen] = '\0';
            if (sep[1]) {
                strncpy(display, sep + 1, sizeof(display) - 1);
            }
        } else {
            strncpy(path, instance, sizeof(path) - 1);
        }
    }

    struct statvfs st;
    if (statvfs(path, &st) != 0) {
        return 1;
    }

    const unsigned long long block_size = st.f_frsize;
    const unsigned long long total = st.f_blocks * block_size;
    const unsigned long long avail = st.f_bavail * block_size;
    const unsigned long long used = total - st.f_bfree * block_size;

    if (total == 0) {
        return 0;
    }

    /* Match df behavior: perc = used / (used + avail) */
    const int perc = used + avail > 0 ? (int)(used * 100 / (used + avail)) : 0;

    char out[32];
    if (strcmp(display, "perc") == 0) {
        printf("%d%%\n", perc);
    } else if (strcmp(display, "used") == 0) {
        format_bytes(used, out, sizeof(out));
        puts(out);
    } else if (strcmp(display, "max") == 0) {
        format_bytes(total, out, sizeof(out));
        puts(out);
    } else { /* free */
        format_bytes(avail, out, sizeof(out));
        puts(out);
    }

    if (perc > URGENT_VALUE) {
        return 33;
    }

    return 0;
}
