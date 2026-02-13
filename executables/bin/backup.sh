#!/bin/bash
set -euo pipefail

echo "backup.sh: no host-specific backup configured for this machine." >&2
echo "Expected an rcm-style host-specific file (e.g. backup.sh##Linux.laptop or backup.sh##Laptop.desktop)." >&2
exit 1
