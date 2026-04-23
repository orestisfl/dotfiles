#include <stdio.h>

static const char *types[] = {"cpu", "memory", "io"};

int main(void) {
    char path[64];
    char line[128];
    char out[256] = {0};
    char *p = out;
    double avg10, avg60;

    for (int i = 0; i < 3; i++) {
        snprintf(path, sizeof(path), "/sys/fs/cgroup/user.slice/%s.pressure", types[i]);
        FILE *f = fopen(path, "r");
        if (!f) {
            continue;
        }

        if (fgets(line, sizeof(line), f) &&
            sscanf(line, "some avg10=%lf avg60=%lf", &avg10, &avg60) == 2) {
            if (avg10 > 1.0) {
                const char *c10 = avg10 > 5.0 ? "red" : "yellow";
                if (avg60 > 1.0) {
                    const char *c60 = avg60 > 5.0 ? "red" : "yellow";
                    p += snprintf(p, sizeof(out) - (p - out),
                                  " %s: (<span foreground=\"%s\">%.2f</span>,"
                                  "<span foreground=\"%s\">%.2f</span>)",
                                  types[i], c10, avg10, c60, avg60);
                } else {
                    p += snprintf(p, sizeof(out) - (p - out),
                                  " %s: (<span foreground=\"%s\">%.2f</span>,%.2f)",
                                  types[i], c10, avg10, avg60);
                }
            }
        }
        fclose(f);
    }

    if (out[0]) {
        printf(" %s\n %s\n", out + 1, out + 1);
    }

    return 0;
}
