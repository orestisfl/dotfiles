/*
 * Network status for i3blocks.
 *
 * BLOCK_INSTANCE selects the interface. Default (or "nmcli") picks the
 * active NetworkManager connection, preferring wireless.
 *
 * Output:
 *   wired up      -> "on"
 *   wireless up   -> "<quality>%" (from `iw dev <dev> link`, fallback nmcli)
 *   unknown wifi  -> "W:?"
 *   down/missing  -> no output
 * Exit 33 (urgent) when wireless quality <= URGENT_THRESHOLD.
 */
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "block_output.h"

#define URGENT_THRESHOLD 20

static int get_nmcli_device(char *buf, size_t buflen) {
    FILE *p = popen("nmcli -t -f DEVICE,TYPE connection show --active 2>/dev/null",
                    "r");
    if (!p)
        return -1;

    char line[128];
    char fallback[64] = {0};
    char wireless[64] = {0};
    while (fgets(line, sizeof(line), p)) {
        const size_t len = strlen(line);
        if (len > 0 && line[len - 1] == '\n')
            line[len - 1] = '\0';
        char *colon = strchr(line, ':');
        if (!colon)
            continue;
        *colon = '\0';
        const char *dev = line;
        const char *type = colon + 1;
        if (!dev[0])
            continue;
        if (!fallback[0])
            snprintf(fallback, sizeof(fallback), "%s", dev);
        if (!wireless[0] && (strcmp(type, "802-11-wireless") == 0 ||
                             strcmp(type, "wifi") == 0))
            snprintf(wireless, sizeof(wireless), "%s", dev);
    }
    pclose(p);

    const char *pick = wireless[0] ? wireless : (fallback[0] ? fallback : NULL);
    if (!pick)
        return -1;
    snprintf(buf, buflen, "%s", pick);
    return 0;
}

static int dbm_to_quality(int dbm) {
    /* Linear mapping often used by NetworkManager/wpa_supplicant:
     *   -50 dBm or better -> 100%
     *   -100 dBm or worse -> 0%
     */
    long q = 2L * (dbm + 100);
    if (q < 0)
        q = 0;
    if (q > 100)
        q = 100;
    return (int)q;
}

static bool parse_iw_signal(const char *device, int *quality) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "iw dev %s link 2>/dev/null", device);
    FILE *p = popen(cmd, "r");
    if (!p)
        return false;

    char line[256];
    bool found = false;
    while (fgets(line, sizeof(line), p)) {
        const char *s = strstr(line, "signal:");
        if (!s)
            continue;
        int dbm;
        if (sscanf(s + 7, "%d", &dbm) == 1) {
            *quality = dbm_to_quality(dbm);
            found = true;
            break;
        }
    }
    pclose(p);
    return found;
}

static bool parse_nmcli_signal(int *quality) {
    FILE *p = popen("nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null", "r");
    if (!p)
        return false;

    char line[128];
    bool found = false;
    while (fgets(line, sizeof(line), p)) {
        if (strncmp(line, "yes:", 4) != 0)
            continue;
        int q;
        if (sscanf(line + 4, "%d", &q) == 1) {
            if (q < 0)
                q = 0;
            if (q > 100)
                q = 100;
            *quality = q;
            found = true;
            break;
        }
    }
    pclose(p);
    return found;
}

int main(void) {
    const char *device = getenv("BLOCK_INSTANCE");
    static char nmcli_device[64];

    if (!device || !*device || strcmp(device, "nmcli") == 0) {
        if (get_nmcli_device(nmcli_device, sizeof(nmcli_device)) != 0)
            return 0;
        device = nmcli_device;
    }

    char path[128];
    snprintf(path, sizeof(path), "/sys/class/net/%s/operstate", device);
    FILE *f = fopen(path, "r");
    if (!f)
        return 0;
    char state[16] = {0};
    if (!fgets(state, sizeof(state), f) || strncmp(state, "up", 2) != 0) {
        fclose(f);
        return 0;
    }
    fclose(f);

    /* On newer kernels /sys/class/net/<dev>/wireless is a directory, on older
     * systems it may be a regular file. Either existence indicates wireless. */
    struct stat st;
    snprintf(path, sizeof(path), "/sys/class/net/%s/wireless", device);
    if (stat(path, &st) != 0) {
        block_output_print_text("on");
        return 0;
    }

    int quality = -1;
    if (!parse_iw_signal(device, &quality))
        (void)parse_nmcli_signal(&quality);

    if (quality < 0) {
        block_output_print_text("W:?");
        return 0;
    }

    char output[16];
    snprintf(output, sizeof(output), "%d%%", quality);
    return block_output_emit(output, quality <= URGENT_THRESHOLD, BLOCK_COLOR_WARNING);
}
