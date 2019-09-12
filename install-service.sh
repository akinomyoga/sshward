#!/bin/bash

name=$1
prog=${0##*/}

if (($#==0)); then
  echo "$prog: a script file is not specified." >&2
  echo "usage: $prog <script file to start service>"
  exit 1
elif [[ ! -f $1 ]]; then
  echo "$prog: the script file \`$1' is not found." >&2
  exit 1
elif ! type chkconfig &>/dev/null; then
  echo "$prog: the command \`chkconfig' is not found." >&2
  exit 2
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

sshw="$HOME/.mwg/libexec/$name"
mkdf "$sshw"
cp "$name" "$sshw"
chmod +x "$sshw"

sed "
  s|%{name}|$name|g
  s|%{sshw}|$sshw|
  s|%{user}|$USER|
  s|%{prefix}|$HOME/.mwg/share/sshward|
" service.sh > "$sshw.service"
chmod +x "$sshw.service"

{
  printf 'cp %q %q\n'                     "$sshw.service" "/etc/init.d/$name"
  printf 'chkconfig --add %q\n'           "$name"
  printf 'chkconfig --level 2345 %q on\n' "$name"
  printf 'chkconfig --list %q\n'          "$name"
} | sudo sh
