/*
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <https://www.gnu.org/licenses/>.
 */
#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>

#define RED "#FF7373"
#define ORANGE "#FFA500"

enum {
    STATE_OK,
    STATE_WARNING,
    STATE_CRITICAL,
    STATE_UNKNOWN,
};

typedef struct {
    time_t timestamp;
    unsigned long long pswpin;
    unsigned long long pswpout;
} sample_t;

static long page_size;

static void usage(char *argv[]) {
    printf("Usage: %s [-t period] [-w window] [-W in:out] [-C in:out] [-h]\n", argv[0]);
    printf("\n");
    printf("-t period\trefresh/sample period in seconds (default: 1)\n");
    printf("-w window\twindow size in seconds (default: 30)\n");
    printf("-W bytes:bytes\tSet warning (color orange) for in:out rate in bytes/s (default: none)\n");
    printf("-C bytes:bytes\tSet critical (color red) for in:out rate in bytes/s (default: none)\n");
    printf("-h \t\tthis help\n");
    printf("\n");
}

static void get_values(time_t *const s, unsigned long long *const pswpin, unsigned long long *const pswpout) {
    FILE *f = fopen("/proc/vmstat", "r");
    if (!f) {
        fprintf(stderr, "Can't open /proc/vmstat\n");
        exit(STATE_UNKNOWN);
    }

    char line[256];
    int found = 0;
    *pswpin = 0;
    *pswpout = 0;

    while (fgets(line, sizeof(line), f) != NULL && found < 2) {
        if (strncmp(line, "pswpin ", 7) == 0) {
            sscanf(line + 7, "%llu", pswpin);
            found++;
        } else if (strncmp(line, "pswpout ", 8) == 0) {
            sscanf(line + 8, "%llu", pswpout);
            found++;
        }
    }

    fclose(f);

    if (found < 2) {
        fprintf(stderr, "Can't find pswpin/pswpout in /proc/vmstat\n");
        exit(STATE_UNKNOWN);
    }

    *s = time(NULL);
    if (*s == (time_t)-1) {
        fprintf(stderr, "Can't get Epoch time\n");
        exit(STATE_UNKNOWN);
    }
}

static void display(const char *prefix, double b, int const warning, int const critical) {
    if (critical != 0 && b > critical) {
        printf("<span fallback='true' color='%s'>", RED);
    } else if (warning != 0 && b > warning) {
        printf("<span fallback='true' color='%s'>", ORANGE);
    } else {
        printf("<span fallback='true'>");
    }

    printf("%s", prefix);

    const double one_kb = 1024;
    const double one_mb = 1024 * 1024;
    const double ten_mb = 10 * one_mb;
    const double ohd_mb = 100 * one_mb;

    if (b >= ohd_mb) {
        printf("%.0fM", b / one_mb);
    } else if (b >= ten_mb) {
        printf("%.1fM", b / one_mb);
    } else if (b >= one_mb) {
        printf("%.2fM", b / one_mb);
    } else if (b >= one_kb) {
        printf("%.0fK", b / one_kb);
    } else {
        printf("%.0fB", b);
    }

    printf("</span>");
}

int main(const int argc, char *argv[]) {
    int c;
    int period = 1;
    int window = 30;
    int warning_in = 0, warning_out = 0;
    int critical_in = 0, critical_out = 0;
    char *envvar = NULL;
    char *label = "";

    page_size = sysconf(_SC_PAGESIZE);
    if (page_size == -1) {
        page_size = 4096;  /* fallback to common page size */
    }

    envvar = getenv("PERIOD");
    if (envvar) {
        period = atoi(envvar);
    }
    envvar = getenv("WINDOW");
    if (envvar) {
        window = atoi(envvar);
    }
    envvar = getenv("WARN_IN");
    if (envvar) {
        warning_in = atoi(envvar);
    }
    envvar = getenv("WARN_OUT");
    if (envvar) {
        warning_out = atoi(envvar);
    }
    envvar = getenv("CRIT_IN");
    if (envvar) {
        critical_in = atoi(envvar);
    }
    envvar = getenv("CRIT_OUT");
    if (envvar) {
        critical_out = atoi(envvar);
    }
    envvar = getenv("LABEL");
    if (envvar) {
        label = envvar;
    }

    while (c = getopt(argc, argv, "ht:w:W:C:"), c != -1) {
        switch (c) {
            case 't':
                period = atoi(optarg);
                break;
            case 'w':
                window = atoi(optarg);
                break;
            case 'W':
                sscanf(optarg, "%d:%d", &warning_in, &warning_out);
                break;
            case 'C':
                sscanf(optarg, "%d:%d", &critical_in, &critical_out);
                break;
            default:
            case 'h':
                usage(argv);
                return STATE_UNKNOWN;
        }
    }

    if (period <= 0) {
        period = 1;
    }
    if (window <= 0) {
        window = 30;
    }

    /* Calculate buffer size: we need window/period + 1 samples */
    const int buffer_size = (window / period) + 1;
    sample_t *samples = calloc(buffer_size, sizeof(sample_t));
    if (!samples) {
        fprintf(stderr, "Can't allocate memory for samples\n");
        return STATE_UNKNOWN;
    }

    int head = 0;       /* next write position */
    int count = 0;      /* number of valid samples */

    /* Get initial sample */
    get_values(&samples[head].timestamp, &samples[head].pswpin, &samples[head].pswpout);
    head = (head + 1) % buffer_size;
    count = 1;

    while (1) {
        sleep(period);

        /* Get new sample */
        get_values(&samples[head].timestamp, &samples[head].pswpin, &samples[head].pswpout);

        /* Find oldest sample in our window */
        int oldest_idx;
        if (count < buffer_size) {
            oldest_idx = 0;
            count++;
        } else {
            oldest_idx = (head + 1) % buffer_size;
        }

        /* Calculate rates using oldest and newest samples */
        int newest_idx = head;
        double elapsed = (double)(samples[newest_idx].timestamp - samples[oldest_idx].timestamp);

        if (elapsed > 0) {
            unsigned long long delta_in = samples[newest_idx].pswpin - samples[oldest_idx].pswpin;
            unsigned long long delta_out = samples[newest_idx].pswpout - samples[oldest_idx].pswpout;

            /* Convert pages to bytes and calculate rate */
            double rate_in = (delta_in * page_size) / elapsed;
            double rate_out = (delta_out * page_size) / elapsed;

            printf("%s", label);
            display("↓", rate_in, warning_in, critical_in);
            printf(" ");
            display("↑", rate_out, warning_out, critical_out);
            printf("\n");
            fflush(stdout);
        }

        head = (head + 1) % buffer_size;
    }

    free(samples);
    return STATE_OK;
}
