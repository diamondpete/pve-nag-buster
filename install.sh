#!/bin/sh
# shellcheck disable=SC2064
set -eu

# pve-nag-buster (v05) https://github.com/foundObjects/pve-nag-buster
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

# installer main body:
_main() {
  # ensure $1 exists so 'set -u' doesn't error out
  { [ "$#" -eq "0" ] && set -- ""; } > /dev/null 2>&1

  case "$1" in
    "--emit")
      # call the emit_script() function to stdout and exit, use this to verify
      # that the base64 encoded script below isn't doing anything malicious
      # does not require root
      emit_script
      ;;
    "--uninstall")
      # uninstall, requires root
      assert_root
      _uninstall
      ;;
    "--install" | "--offline" | "")
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
  [ -f "/etc/apt/apt.conf.d/86pve-nags" ] &&
    rm -f "/etc/apt/apt.conf.d/86pve-nags"
  [ -f "/usr/share/pve-nag-buster.sh" ] &&
    rm -f "/usr/share/pve-nag-buster.sh"

  echo "Script and dpkg hooks removed, please manually remove /etc/apt/sources.list.d/pve-no-subscription.list if desired"
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

  # create the pve-no-subscription list
  echo "Creating PVE no-subscription repo list ..."
  cat <<- EOF > "/etc/apt/sources.list.d/pve-no-subscription.list"
	# .list file automatically generated by pve-nag-buster at $(date)
	#
	# If pve-nag-buster is installed again this file will be overwritten
	#

	deb http://download.proxmox.com/debian/pve $RELEASE pve-no-subscription
	deb http://download.proxmox.com/debian/ceph-quincy $RELEASE no-subscription
	EOF

  # create dpkg pre/post install hooks for persistence
  echo "Creating dpkg hooks in /etc/apt/apt.conf.d ..."
  cat <<- 'EOF' > "/etc/apt/apt.conf.d/86pve-nags"
	DPkg::Pre-Install-Pkgs {
	    "while read -r pkg; do case $pkg in *proxmox-widget-toolkit* | *pve-manager*) touch /tmp/.pve-nag-buster && exit 0; esac done < /dev/stdin";
	};

	DPkg::Post-Invoke {
	    "[ -f /tmp/.pve-nag-buster ] && { /usr/share/pve-nag-buster.sh; rm -f /tmp/.pve-nag-buster; }; exit 0";
	};
	EOF

  # install the hook script
  temp=''
  if [ "$1" = "--offline" ]; then
    # packed script requested
    temp="$(mktemp)" && trap "rm -f $temp" EXIT
    emit_script > "$temp"
  elif [ -f "pve-nag-buster.sh" ]; then
    # local copy available
    temp="pve-nag-buster.sh"
  else
    # fetch from github
    echo "Fetching hook script from GitHub ..."
    tempd="$(mktemp -d)" &&
      trap "echo 'Cleaning up temporary files ...'; rm -f $tempd/*; rmdir $tempd" EXIT
    temp="$tempd/pve-nag-buster.sh"
    wget https://raw.githubusercontent.com/diamondpete/pve-nag-buster/master/pve-nag-buster.sh \
      -q --show-progress -O "$temp"
  fi
  echo "Installing hook script as /usr/share/pve-nag-buster.sh"
  install -o root -m 0550 "$temp" "/usr/share/pve-nag-buster.sh"

  echo "Running patch script"
  /usr/share/pve-nag-buster.sh

  return 0
}

# emit a stored copy of pve-nag-buster.sh offline -- this is intended to be used during
# offline provisioning where we don't have access to github or a full cloned copy of the
# project

# run 'install.sh --emit' to dump stored script to stdout

# Important: if you're not me you should probably decode this and read it to make sure I'm not doing
#            something malicious like mining dogecoin or stealing your valuable cat pictures

# pve-nag-buster.sh (v05) encoded below:

emit_script() {
  base64 -d << 'YEET' | unxz
/Td6WFoAAATm1rRGAgAhARYAAAB0L+Wj4AahA8ldABGIQkY99BY0cwoNj8U0dcgowbs41qLC+aej
mGQYj9kDeUYQYXlb2YqhoJLO08e8hIe8MoGJqvcVxM5VQehFNPqq4OH1KhbHgYGz5QSdcYFBPv2D
jY49io85pCEdBXRw6wLkkTOpm7NoQQs6ZJ5F+vtHWz70HmnRfNhHpjrb16GcK0ERg/VLAx58EUIU
t9OVgypxnKVdJL7/XxL/nUYLT65sn6ZQvKn4HpuPvK5eKgjZfBYJ3Q0CPDeFlXWIew43sqJTwmlX
drWBSOlU6yMbmhWTJvfLpK9UfBAh6Qwp6UJ6i0Hbwe+d8qKO/SQ1Ciz6qDbM/cLTIENPYvVjlqzV
jDmBtzdGMfqXXuFbtNB1uIJVUd3o1rRgH0Pau7yYXZVjDxJ5a32NnSwbbxsYqvcDc5QARfe321vH
ICPQMtds3p/nuCpmMNex8SorApU6X0jvw18w9uMIF7dE2tk0Ge58qiIOH/+V2uVZzAUAUpTa7Gb8
0aKWiai6f4bMXfLwvUOiDOucGAW2mMzXClpI7m4jrBy+TjSjPSR1JvS2e9ppcVH2vwcXdUOxxybB
aDCozlkd9DecONOygFJz7J+V323Oe/kocpUmrZjsQTv0kIveFoPKTTkVYX7JPhePK4FJ884pSafp
D+KYD3iGv3QqUt0rJBFP1IHhCKsRBNAGgDEaWUUCpT7XVRgGnhXcbQYyegBik+zenQOKvjH/x1Wf
I9iGgk5bumGJ4Za9fKyIAqJ+NNdrjyuV9VcFzctxdsKjIIe8Yp6vVvA3qG0kZy8pUUp5KA97734O
xJDV5eTUtY44FTL5jiIvfOsGm2raf9ihjPV5DYvHO6kbp6EdavQ0pIt6i1wfd1XB0/LeekwXCnof
9GnsjFghMXAkgYDKDK4zkYAGThY/HmJf6ehk8qNJnkJ2zKDr8KhrWFaYIRFb05F6YCUxax8VSUPt
Au6nJjxijtl2Qqy8pt0dqpr6A9SqN6jz7P5FxctEynJIrdvjO8zXmtGhRFs59dapvtYdOYqCPFNn
WgCdjhyNX74C+0JXuSl3M+JDOi3M1Lb7qvtYRftPThHbYnqTegTW3Qh0e4OP09YPXWWZDOBt4bQG
jy1sCydFl4SX44SJulFr+/q+wHR0ulhxxdCTEDrVAf797itMZLrjJgkCBL+ns/bmCAYvgQjSPFw2
LlM/t2xSgiG+g/Gz7RA/9KGdEaSG/s/pW2ot2a5ZoALNq3m0InUSNX8yjaT4U9CddW3+tPgjOb0r
rjTgsXKfTVmiTXcyb3bPmeLgpDmE9WuxVDMr9vw4AAAAAACT817apNlA5wAB5QeiDQAAIcBG2LHE
Z/sCAAAAAARZWg==
YEET
}

assert_root() { [ "$(id -u)" -eq '0' ] || { echo "This action requires root." && exit 1; }; }
_usage() { echo "Usage: $(basename "$0") (--emit|--offline|--uninstall)"; }

_main "$@"
