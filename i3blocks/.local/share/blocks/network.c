#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define URGENT_THRESHOLD 20

int main(void) {
    const char *device = getenv("BLOCK_INSTANCE");
    if (!device || !*device) {
        device = "nmcli";
    }

    /* If nmcli mode, dynamically get active connection device */
    static char nmcli_device[64];
    if (strcmp(device, "nmcli") == 0) {
        device = NULL;
        FILE *p = popen("nmcli -t -f DEVICE,TYPE connection show --active", "r");
        if (p) {
            char line[128];
            char fallback[64] = {0};
            while (fgets(line, sizeof(line), p)) {
                /* Remove trailing newline */
                const size_t len = strlen(line);
                if (len > 0 && line[len - 1] == '\n') {
                    line[len - 1] = '\0';
                }
                /* Format: DEVICE:TYPE */
                char *colon = strchr(line, ':');
                if (!colon) {
                    continue;
                }
                *colon = '\0';
                const char *dev = line;
                const char *type = colon + 1;
                /* Save first device as fallback */
                if (!fallback[0] && dev[0]) {
                    snprintf(fallback, sizeof(fallback), "%s", dev);
                }
                /* Prefer wireless */
                if (strcmp(type, "802-11-wireless") == 0 ||
                    strcmp(type, "wifi") == 0) {
                    snprintf(nmcli_device, sizeof(nmcli_device), "%s", dev);
                    device = nmcli_device;
                    break;
                }
            }
            pclose(p);
            /* Use fallback if no wireless found */
            if (!device && fallback[0]) {
                snprintf(nmcli_device, sizeof(nmcli_device), "%s", fallback);
                device = nmcli_device;
            }
        }
        if (!device) {
            /* nmcli failed or returned nothing */
            return 0;
        }
    }

    /* Check operstate */
    char path[128];
    snprintf(path, sizeof(path), "/sys/class/net/%s/operstate", device);

    FILE *f = fopen(path, "r");
    if (!f) {
        return 0;
    }

    char state[16];
    if (!fgets(state, sizeof(state), f) || strncmp(state, "up", 2) != 0) {
        fclose(f);
        return 0;
    }
    fclose(f);

    /* Check if wireless */
    snprintf(path, sizeof(path), "/sys/class/net/%s/wireless", device);
    f = fopen(path, "r");
    if (f) {
        fclose(f);
    } else {
        /* Wired and up */
        puts("on");
        return 0;
    }

    /* Parse /proc/net/wireless for signal quality */
    f = fopen("/proc/net/wireless", "r");
    if (!f) {
        puts("W:?");
        return 0;
    }

    char line[256];
    const size_t dev_len = strlen(device);
    int found = 0;

    while (fgets(line, sizeof(line), f)) {
        /* Skip leading whitespace and match device name */
        const char *p = line;
        while (*p == ' ' || *p == '\t') {
            p++;
        }

        if (strncmp(p, device, dev_len) == 0 && p[dev_len] == ':') {
            /* Found device, parse: "device: status link. level. noise ..." */
            p += dev_len + 1;
            int status, link;
            if (sscanf(p, "%d %d", &status, &link) == 2) {
                int quality = link * 100 / 70;
                if (quality > 100) {
                    quality = 100;
                }
                printf("%d%%\n", quality);
                found = 1;
                if (quality <= URGENT_THRESHOLD) {
                    fclose(f);
                    return 33;
                }
            }
            break;
        }
    }

    fclose(f);

    if (!found) {
        puts("W:?");
    }

    return 0;
}
