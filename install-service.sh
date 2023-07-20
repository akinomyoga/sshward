#!/bin/bash

flags=
type=
name=$1
prog=${0##*/}

function error {
  # prog=sshward/install-service
  flags=E$flags
  printf '%s: %s\n' "$prog" "$*" >&2
}

function read-arguments {
  while (($#)); do
    local arg=$1; shift
    if [[ $flags != *L* && $arg == -?* ]]; then
      if [[ $arg == --* ]]; then
        case $arg in
        (--help) flags=H$flags ;;
        (*) error "unknown option '$arg'."
            return 2 ;;
        esac
      else
        local i c
        for ((i=1;i<${#arg};i++)); do
          c=${arg:i:1}
          case $c in
          (-) flags=L$flags ;;
          (t) if (($#)); then
                type=$1; shift
              else
                error "option argument to '-$c' is missing."
                return 2
              fi ;;
          (*) error "unknown option '-$c'."
              return 2 ;;
          esac
        done
      fi
    else
      if [[ $flags == *1* ]]; then
        error "service script file already specified"
        return 2
      elif [[ ! $arg ]]; then
        error "empty argument '' is specified"
        return 2
      fi
      name=$arg
      flags=1$flags
    fi
  done

  if [[ $flags != *1* ]]; then
    error "a script file is not specified."
    echo "usage: $prog <script file to start service>" >&2
    return 2
  fi
}
read-arguments "$@" || return 2

if [[ $flags == *H* ]]; then
  printf '%s\n' \
         "usage: $prog [-t TYPE] SCRIPT" >&2
  return 0
fi

if [[ ! -f $name ]]; then
  echo "$prog: the script file \`$1' is not found." >&2
  exit 1
fi

if [[ ! $type ]]; then
  if type systemctl &>/dev/null; then
    type=systemd
  elif type chkconfig &>/dev/null; then
    type=sysv
  else
    echo "$prog: the command \`chkconfig' is not found." >&2
    exit 2
  fi
fi

function mkd {
  while (($#)); do
    [[ -d $1 ]] || mkdir -p "$1"
    shift
  done
}
function mkdf {
  while (($#)); do
    [[ $1 = */* ]] && mkd "${1%/*}"
    shift
  done
}

prefix=$HOME/.mwg/share/sshward
sshw=$HOME/.mwg/libexec/$name
mkdf "$sshw"
cp "$name" "$sshw"
chmod +x "$sshw"

sed "
  s|%{name}|$name|g
  s|%{sshw}|$sshw|
  s|%{user}|$USER|
  s|%{prefix}|$prefix|
" template/init.sh > "$sshw.init.sh"
chmod +x "$sshw.init.sh"

case $type in
(sysv)
  {
    printf 'set -e'
    printf 'cp %q %q\n'                     "$sshw.init.sh" "/etc/init.d/$name"
    printf 'chkconfig --add %q\n'           "$name"
    printf 'chkconfig --level 2345 %q on\n' "$name"
    printf 'chkconfig --list %q\n'          "$name"
  } | sudo sh ;;
(systemd-init)
  set -e
  sudo mkdir -p /etc/init.d
  sudo cp "$sshw.init.sh" /etc/init.d/
  sudo systemctl enable "$name" ;;
(systemd)
  if [[ ! -d /usr/lib/systemd/system ]]; then
    echo 'sshward/install-service: The directory /usr/lib/systemd/system not found.' >&2
    return 1
  fi

  sed "
    s|%{name}|$name|g
    s|%{sshw}|$sshw|
    s|%{user}|$USER|
    s|%{prefix}|$prefix|
  " template/systemd.service > "$sshw.systemd.service"

  sed "
    s|^pidfile=$|&$prefix/run/$name.pid|
  " "$sshw" > "$sshw.systemd.start"
  chmod +x "$sshw.systemd.start"

  set -e
  sudo cp "$sshw.systemd.service" "/usr/lib/systemd/system/$name.service"
  sudo systemctl daemon-reload
  sudo systemctl enable "$name" ;;
esac
