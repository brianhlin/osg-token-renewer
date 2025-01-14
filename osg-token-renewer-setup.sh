#!/bin/bash
set -e

fail () { echo "$@" >&2; exit 1; }

usage () {
  echo "usage: $(basename "$0") [options] CLIENT_NAME"
  echo
  echo "   eg: $(basename "$0") myclient123"
  echo
  echo "Options:"
  echo "  --pw-file /path/to/pwfile    Specify a password file"
  echo "  --manual                     Manual client registration"
  exit 1
}
pwfile=
manual=
while [[ $1 = -* ]]; do
case $1 in
  --pw-file ) pwfile=$2; shift 2 ;;
  --manual  ) manual='--manual'; shift 1 ;;
   -*       ) usage ;;
esac
done

[[ $1 ]] || usage
[[ $2 ]] && usage

client_name=$1
[[ $pwfile ]] || pwfile=/etc/osg/tokens/$client_name.pw

cleanup () {
  oidc-agent -k >/dev/null
  if [[ $OIDC_SOCK = /tmp/oidc-*/oidc-agent.* ]]; then
    [[ -e $OIDC_SOCK ]] && rm -f "$OIDC_SOCK"
    [[ -d ${OIDC_SOCK%/*} ]] && rmdir "${OIDC_SOCK%/*}"
  fi
}

[[ -e $pwfile ]] ||
fail "please create /etc/osg/tokens/$client_name.pw with encryption password"

if [[ $UID = 0 ]]; then
  # open $pwfile as root, then re-run this script under service account
  exec su osg-token-svc -s /bin/bash -c '"$@"' -- - \
  "$0" $manual --pw-file /dev/fd/9 "$client_name"
fi 9<"$pwfile"

eval $(oidc-agent)
trap cleanup EXIT

oidc-gen -w device $manual --pw-cmd="cat '$pwfile'" "$client_name"

echo
echo
echo "Add the following section to /etc/osg/token-renewer/config.ini :"
echo
echo "[account $client_name]"
echo
echo "password_file = /etc/osg/tokens/$client_name.pw"
echo


