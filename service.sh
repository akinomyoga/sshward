#!/bin/bash
#
# %{name}
#
# chkconfig: 2345 70 30
# description: %{name}
# processname: %{name}
#

name="%{name}"
sshw="%{sshw}"
sshw_user="%{user}"
sshw_prefix="%{prefix}"

SYSTEMCTL_SKIP_REDIRECT=1
. /etc/rc.d/init.d/functions

lock_file="/var/lock/subsys/${name}"
pid_file="$sshw_prefix/run/${name}.pid"

is_tty=
[[ -t 2 ]] && is_tty=1

function sshward/start {
  if [[ -f $lock_file ]]; then
    echo $"Service $name: the service is already running." >&2
    return 1
  else
    echo $"Service $name: starting..." >&2
    daemon --user="$sshw_user" --pidfile="$pid_file" "$sshw" --pidfile="$pid_file" &&
      touch "$lock_file"
    echo $"Service $name: started." >&2
  fi
}

function sshward/stop {
  if [[ -f $lock_file ]]; then
    echo $"Service $name: stopping..." >&2
    killproc -p "$pid_file" "$sshw"
    rm -f "$lock_file"
    echo $"Service $name: stopped." >&2
  else
    echo $"Service $name: the service is not running." >&2
    return 1
  fi
}

function sshward/status {
  if [[ ! -f $lock_file ]]; then
    echo $"Service $name: ${is_tty:+[37;90m●[m }not running." >&2
    return 1
  elif [[ ! -f $pid_file ]]; then
    echo $"Service $name: ${is_tty:+[31;91m●[m }failed to start." >&2
    return 1
  fi

  local pid="$(< "$pid_file")"
  if ! kill -0 "$pid" 2>/dev/null; then
    echo $"Service $name: ${is_tty:+[31;91m●[m }pid=$pid crashed." >&2
    rm -f "$pid_file"
    return 1
  fi

  echo $"Service $name: ${is_tty:+[32m●[m }pid=$pid running."
}

case "${1}" in
(start)
  sshward/start ;;
(stop)
  sshward/stop  ;;
(restart)
  sshward/stop
  sleep 2
  sshward/start ;;
(status)
  sshward/status ;;
(*)
  echo $"Usage: ${0} {start,stop,restart,status}" >&2
  ;;
esac
