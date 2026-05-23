#!/bin/sh
#
# pve-nag-buster.sh https://github.com/diamondpete/pve-nag-buster
# Copyright (C) 2019 /u/seaQueue (reddit.com/u/seaQueue)
#
# Removes Proxmox VE 9.x+ license nags automatically after updates
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

NAGFILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
SCRIPT="$(basename "$0")"

# disable license nag: https://johnscs.com/remove-proxmox51-subscription-notice/

echo "$SCRIPT: Removing Nag ..."
awk '
/res.data.status.toLowerCase\(\) !== '\''active'\''/ {
    inblock = 1
}
inblock && /return;/ {
    hasreturn = 1
}
inblock && /Ext\.Msg\.show/ {
    if (!hasreturn) {
        print "                        return;";
        hasreturn = 1
    }
    inblock = 0
}
{
    print
}
' "$NAGFILE" > "$NAGFILE.tmp" && mv "$NAGFILE.tmp" "$NAGFILE"
systemctl restart pveproxy.service

# disable paid repo list

ENTERPRISE_BASE="/etc/apt/sources.list.d/pve-enterprise"
CEPH_BASE="/etc/apt/sources.list.d/ceph"

CEPH_URI="http:\/\/download.proxmox.com\/debian\/ceph-squid"

ENTERPRISE_LAST_LINE=$(tail -n 1 "$ENTERPRISE_BASE.sources")

if [ "$ENTERPRISE_LAST_LINE" != "Enabled: false" ]; then
  echo "$SCRIPT: Disabling PVE enterprise repo sources..."
  echo "Enabled: false" >> $ENTERPRISE_BASE.sources
fi

CEPH_SUBSCRIPTION_LINE=$(grep "Components:" $CEPH_BASE.sources)

if [ "$CEPH_SUBSCRIPTION_LINE" != "Components: no-subscription" ]; then
  echo "$SCRIPT: Disabling Ceph enterprise repo sources..."
  sed -i "s/URIs:.*$/URIs: "$CEPH_URI"/" $CEPH_BASE.sources
  sed -i "s/Components:.*$/Components: no-subscription/" $CEPH_BASE.sources
fi
