#!/bin/sh
# Keep our entries in zapret's per-host exclude list, and survive a LuCI save.
#
# Zapret's LuCI app rewrites /opt/zapret/ipset/* from its own copy whenever
# somebody presses Save, which silently drops hand edits to
# zapret-hosts-user-exclude.txt. The symptom is a client stating "the internet
# broke" again, with nothing in the log naming a cause. This script re-asserts
# our entries and restarts zapret only when something actually changed, so it
# is safe to run from cron.
#
# Two kinds of entry:
#   ADD     names that desync breaks, so they must be present and active
#   DISABLE names the ISP SNI-filters, so an active line must be commented out
#
# Mutating: appends to the exclude list and restarts zapret on change.
# Exits 0 either way; exits 1 only when the file is missing.

LIST=/opt/zapret/ipset/zapret-hosts-user-exclude.txt

# Alibaba-hosted endpoints that answer a split ClientHello with a TLS alert or
# plaintext instead of a handshake. The Android app fetches its audio from
# tts-static.duolingo.cn and images from simg-ssl.duolingo.cn.
ADD="duolingo.com
duolingo.cn"

# cloudfront.net is excluded by the shipped list, which leaves the Duolingo web
# app's audio CDNs (d1vq87e9lcf771, d2pur3iezf4d1j, d1btvuu4dwu627) without a
# bypass while the ISP filters exactly those SNIs. To keep the bypass for them,
# an active cloudfront.net line is commented out.
DISABLE="cloudfront.net"

[ -f "$LIST" ] || { echo "exclude-ensure: missing $LIST" >&2; exit 1; }

changed=0

for name in $ADD; do
	if grep -Fxq "$name" "$LIST"; then
		continue
	fi
	printf '%s\n' "$name" >> "$LIST"
	echo "exclude-ensure: added $name"
	changed=1
done

for name in $DISABLE; do
	grep -Fxq "$name" "$LIST" || continue
	sed -i "s/^$(printf '%s' "$name" | sed 's/\./\\./g')\$/#&/" "$LIST"
	echo "exclude-ensure: disabled $name"
	changed=1
done

if [ "$changed" = 1 ]; then
	/etc/init.d/zapret restart >/dev/null 2>&1
	echo "exclude-ensure: zapret restarted"
fi

exit 0
