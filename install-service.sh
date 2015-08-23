#!/bin/bash

name="$1"

if (($#==0)); then
  echo "${0##*/}: a script file is not specified." >&2
  echo "usage: ${0##*/} script file to start service."
  exit 1
elif [[ ! -f $1 ]]; then
  echo "${0##*/}: the script file \`$1' is not found." >&2
  exit 1
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
  s|%{sshw}|$HOME/.mwg/libexec/sshward-padparadscha|
  s|%{user}|$USER|
  s|%{prefix}|$HOME/.mwg/share/sshward|
" service.sh > "$sshw.service"
chmod +x "$sshw.service"

{
  echo cp "$sshw.service" "/etc/init.d/$name"
  echo chkconfig --add "$name"
  echo chkconfig --level 2345 "$name" on
  echo chkconfig --list "$name"
} | sudo sh
