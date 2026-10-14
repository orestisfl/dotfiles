#!/usr/bin/env bash
set -euo pipefail

START_URL=${START_URL:-http://neverssl.com/}

PROFILE_DIR=$(mktemp -d /tmp/captive-portal-firefox.XXXXXX)
trap 'rm -rf "$PROFILE_DIR"' EXIT

cat >"$PROFILE_DIR/user.js" <<'EOF'
user_pref("dom.security.https_only_mode", false);
user_pref("dom.security.https_only_mode_ever_enabled", false);
user_pref("dom.security.https_only_mode_pbm", false);
user_pref("dom.security.https_first", false);
user_pref("dom.security.https_first_pbm", false);
user_pref("browser.fixup.fallback-to-https", false);

user_pref("network.trr.mode", 5);
user_pref("network.trr.uri", "");
user_pref("network.dns.native_https_query", false);
user_pref("network.dns.upgrade_with_https_rr", false);
user_pref("network.dns.use_https_rr_as_altsvc", false);
user_pref("network.dns.echconfig.enabled", false);
user_pref("network.dns.http3_echconfig.enabled", false);
user_pref("network.dns.disableIPv6", true);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("network.proxy.type", 0);

user_pref("network.stricttransportsecurity.preloadlist", false);
user_pref("security.cert_pinning.enforcement_level", 0);

# A post-quantum key share pushes the ClientHello past ~1.5 KB, so it spans two
# TCP segments and cheap captive-portal middleboxes answer with an RST.
user_pref("security.tls.enable_kyber", false);
user_pref("network.http.http3.enable", false);
user_pref("network.http.http2.enabled", false);

user_pref("network.captive-portal-service.enabled", true);
user_pref("network.connectivity-service.enabled", true);

user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "");
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.tabs.warnOnClose", false);
EOF

sed -i 's/^#/\/\//' "$PROFILE_DIR/user.js"
echo "user_pref(\"browser.startup.homepage\", \"$START_URL\");" >>"$PROFILE_DIR/user.js"

if [[ ${CAPTIVE_TLS12:-0} == 1 ]]; then
    echo 'user_pref("security.tls.version.max", 3);' >>"$PROFILE_DIR/user.js"
    echo "TLS capped at 1.2"
fi

echo "Launching captive portal browser (profile: $PROFILE_DIR)"
echo "Profile will be deleted on exit."
exec firefox --no-remote --profile "$PROFILE_DIR" "$START_URL"
