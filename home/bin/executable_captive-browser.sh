#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR=$(mktemp -d /tmp/captive-portal-firefox.XXXXXX)
trap 'rm -rf "$PROFILE_DIR"' EXIT

cat >"$PROFILE_DIR/user.js" <<'EOF'
user_pref("dom.security.https_only_mode", false);
user_pref("dom.security.https_only_mode_ever_enabled", false);
user_pref("dom.security.https_only_mode_pbm", false);
user_pref("dom.security.https_first", false);
user_pref("dom.security.https_first_pbm", false);

user_pref("network.trr.mode", 5);
user_pref("network.trr.uri", "");

user_pref("network.stricttransportsecurity.preloadlist", false);
user_pref("security.cert_pinning.enforcement_level", 0);

user_pref("network.captive-portal-service.enabled", true);
user_pref("network.connectivity-service.enabled", true);

user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "");
user_pref("browser.startup.homepage", "http://neverssl.com");
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.tabs.warnOnClose", false);
EOF

echo "Launching captive portal browser (profile: $PROFILE_DIR)"
echo "Profile will be deleted on exit."
exec firefox --no-remote --profile "$PROFILE_DIR" http://neverssl.com
