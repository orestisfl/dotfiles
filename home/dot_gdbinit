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

set prompt \001\033[01;31m\002gdb $ \001\033[0m\002

define dtailq
 set $next = $arg0.tqh_first
 while ($next != 0)
  p $next
  p *$next
  set $next = $next.$arg1.tqe_next
 end
end

define dslist
 set $next = $arg0.slh_first
 while ($next != 0)
  p $next
  set $next = $next.$arg1.sle_next
 end
end

set debuginfod enabled on
