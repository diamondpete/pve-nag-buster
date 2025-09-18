#!/bin/sh
# shellcheck disable=SC2064
set -eu

# pve-nag-buster (v04) https://github.com/foundObjects/pve-nag-buster
# Copyright (C) 2019 /u/seaQueue (reddit.com/u/seaQueue)
#
# Removes Proxmox VE 6.x+ license nags automatically after updates
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# ensure a predictable environment
PATH=/usr/sbin:/usr/bin:/sbin:/bin
\unalias -a

# initialize variables
_init() {
  path_apt_conf="/etc/apt/apt.conf.d/86pve-nags"
  path_apt_sources_proxmox="/etc/apt/sources.list.d/proxmox.sources"
  path_apt_sources_ceph="/etc/apt/sources.list.d/ceph.sources"
  path_apt_sources_debian="/etc/apt/sources.list.d/debian.sources"
  path_buster="/usr/share/pve-nag-buster.sh"
}

# installer main body:
_main() {
  # ensure $1 exists so 'set -u' doesn't error out
  { [ "$#" -eq "0" ] && set -- ""; } > /dev/null 2>&1

  _init

  case "$1" in
    "--uninstall")
      # uninstall, requires root
      assert_root
      _uninstall
      ;;
    "--install" | "")
      # install dpkg hooks, requires root
      assert_root
      _install "$@"
      ;;
    *)
      # unknown flags, print usage and exit
      _usage
      ;;
  esac
  exit 0
}

_uninstall() {
  set -x
  [ -f "$path_apt_conf" ] &&
    rm -f "$path_apt_conf"
  [ -f "$path_buster" ] &&
    rm -f "$path_buster"

  echo "Script and dpkg hooks removed, please manually remove sources lists if desired:"
  echo "\t$path_apt_sources_proxmox"
  echo "\t$path_apt_sources_ceph"
  echo "\t$path_apt_sources_debian"
}

_install() {
  # create hooks and no-subscription repo list, install hook script, run once

  VERSION_CODENAME=''
  ID=''
  . /etc/os-release
  if [ -n "$VERSION_CODENAME" ]; then
    RELEASE="$VERSION_CODENAME"
  else
    RELEASE=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release)
  fi

  # create the pve-no-subscription source
  echo "Creating Proxmox pve-no-subscription repo source ..."
  emit_proxmox_sources > "$path_apt_sources_proxmox"

  # create the ceph no-subscription source
  echo "Creating Ceph no-subscription repo source ..."
  emit_ceph_sources > "$path_apt_sources_ceph"

  # create the debian source
  echo "Creating Debian repo source ..."
  emit_debian_sources > "$path_apt_sources_debian"

  # create dpkg pre/post install hooks for persistence
  echo "Creating dpkg hooks in /etc/apt/apt.conf.d ..."
  emit_buster_conf > "$path_apt_conf"

  # install the hook script
  temp="$(mktemp)" && trap "rm -f $temp" EXIT
  emit_buster > "$temp"
  echo "Installing hook script as $path_buster"
  install -o root -m 0550 "$temp" "$path_buster"

  echo "Running patch script"
  "$path_buster"

  return 0
}

assert_root() { [ "$(id -u)" -eq '0' ] || { echo "This action requires root." && exit 1; }; }
_usage() { echo "Usage: $(basename "$0") (--install|--uninstall)"; }
emit_proxmox_sources() {
    cat <<EOFPROXMOX
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg

EOFPROXMOX
}

emit_ceph_sources() {
    cat <<EOFCEPH
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg

EOFCEPH
}

emit_debian_sources() {
    cat <<EOFDEBIAN
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

EOFDEBIAN
}

emit_buster_conf() {
    cat <<'EOFCONF'
DPkg::Pre-Install-Pkgs {
	"while read -r pkg; do case $pkg in *proxmox-widget-toolkit* | *pve-manager*) touch /tmp/.pve-nag-buster && exit 0; esac done < /dev/stdin";
};

DPkg::Post-Invoke {
	"[ -f /tmp/.pve-nag-buster ] && { /usr/share/pve-nag-buster.sh; rm -f /tmp/.pve-nag-buster; }; exit 0";
};

EOFCONF
}

emit_buster() {
    cat <<'EOFBUSTER'
#!/bin/sh
#
# pve-nag-buster.sh (v04) https://github.com/foundObjects/pve-nag-buster
# Copyright (C) 2019 /u/seaQueue (reddit.com/u/seaQueue)
#
# Removes Proxmox VE 6.x+ license nags automatically after updates
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

NAGTOKEN="data.status.toLowerCase() !== 'active'"
NAGFILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
SCRIPT="$(basename "$0")"

# disable license nag: https://johnscs.com/remove-proxmox51-subscription-notice/

if grep -qs "$NAGTOKEN" "$NAGFILE" > /dev/null 2>&1; then
  echo "$SCRIPT: Removing Nag ..."
  sed -i.orig "s/$NAGTOKEN/false/g" "$NAGFILE"
  systemctl restart pveproxy.service
fi

# disable paid repo list

ENTERPRISE_BASE="/etc/apt/sources.list.d/pve-enterprise"
CEPH_BASE="/etc/apt/sources.list.d/ceph"

CEPH_URI="http:\/\/download.proxmox.com\/debian\/ceph-squid"

if [ -f "$ENTERPRISE_BASE.sources" ]; then
  echo "$SCRIPT: Disabling PVE enterprise repo sources..."
  echo "Enabled: false" >> $ENTERPRISE_BASE.sources
fi

if [ -f "$CEPH_BASE.sources" ]; then
  echo "$SCRIPT: Disabling Ceph enterprise repo sources..."
  sed -i "s/URIs:.*$/URIs: "$CEPH_URI"/" $CEPH_BASE.sources
  sed -i "s/Components:.*$/Components: no-subscription/" $CEPH_BASE.sources
fi

EOFBUSTER
}

_main "$@"
