# https://sourceware.org/gdb/onlinedocs/gdb/

# Pretty print
# https://sourceware.org/gdb/onlinedocs/gdb/Print-Settings.html
set print elements 1000
set print array on
set print pretty on

# Save history, everything in one file
# https://sourceware.org/gdb/onlinedocs/gdb/Command-History.html
set history save on
set history filename ~/.cache/gdb_history

# No pager
# https://sourceware.org/gdb/onlinedocs/gdb/Screen-Size.html
set pagination off
