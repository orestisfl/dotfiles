/*
 * Battery monitor for i3blocks (interval mode).
 *
 * Reads /sys/class/power_supply/<BAT>/{capacity,energy_*,charge_*,status}.
 * The percentage is taken from `capacity` when present, otherwise derived
 * from energy_now/energy_full, falling back to charge_now/charge_full.
 *
 * Environment variables:
 *   BAT       battery name       (default: BAT0)
 *   URGENT    urgent threshold % (default: 10)
 *   LABEL     prefix label       (default: "")
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "block_output.h"

static int read_int(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f)
        return -1;
    int val;
    if (fscanf(f, "%d", &val) != 1)
        val = -1;
    fclose(f);
    return val;
}

static int read_line(const char *path, char *buf, size_t len) {
    FILE *f = fopen(path, "r");
    if (!f)
        return -1;
    if (!fgets(buf, (int)len, f)) {
        fclose(f);
        return -1;
    }
    fclose(f);
    buf[strcspn(buf, "\n")] = '\0';
    return 0;
}

static int read_ratio_pct(const char *bat, const char *now_key,
                          const char *full_key) {
    char path[256];
    snprintf(path, sizeof(path), "/sys/class/power_supply/%s/%s", bat, now_key);
    int now = read_int(path);
    snprintf(path, sizeof(path), "/sys/class/power_supply/%s/%s", bat, full_key);
    int full = read_int(path);
    if (now < 0 || full <= 0)
        return -1;
    long pct = (long)now * 100 / full;
    if (pct < 0)
        pct = 0;
    if (pct > 100)
        pct = 100;
    return (int)pct;
}

int main(void) {
    int urgent = 10;
    const char *bat = "BAT0";
    const char *label = "";
    char *envvar;
    char output[32];

    envvar = getenv("URGENT");
    if (envvar)
        urgent = atoi(envvar);
    envvar = getenv("BAT");
    if (envvar && *envvar)
        bat = envvar;
    envvar = getenv("LABEL");
    if (envvar)
        label = envvar;

    char path[256];
    snprintf(path, sizeof(path), "/sys/class/power_supply/%s/capacity", bat);
    int pct = read_int(path);

    if (pct < 0)
        pct = read_ratio_pct(bat, "energy_now", "energy_full");
    if (pct < 0)
        pct = read_ratio_pct(bat, "charge_now", "charge_full");
    if (pct < 0)
        return 0;
    if (pct > 100)
        pct = 100;

    char status[32];
    snprintf(path, sizeof(path), "/sys/class/power_supply/%s/status", bat);
    if (read_line(path, status, sizeof(status)) < 0)
        return 0;

    if (strcmp(status, "Charging") == 0) {
        snprintf(output, sizeof(output), "%s%d%%+", label, pct);
    } else if (strcmp(status, "Discharging") == 0) {
        snprintf(output, sizeof(output), "%s%d%%-", label, pct);
    } else {
        snprintf(output, sizeof(output), "%s%d%%", label, pct);
    }

    const int is_urgent = strcmp(status, "Discharging") == 0 && pct <= urgent;
    if (is_urgent && !block_output_is_i3blocks()) {
        block_output_print_markup(output, BLOCK_COLOR_CRITICAL);
        return 0;
    }

    block_output_print_text(output);
    return block_output_status(is_urgent);
}
