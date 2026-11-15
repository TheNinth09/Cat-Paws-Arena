#!/usr/bin/env bash
# Fails if the built APK requests the advertising ID or the app depends on an
# ad, attribution or analytics SDK (Google Play Families policy).
# Usage: check_families_policy.sh <apk>  (run after flutter build apk)
set -euo pipefail
apk="$1"
fail=0

banned_pub='^  (firebase_analytics|firebase_crashlytics|firebase_remote_config|firebase_in_app_messaging|firebase_dynamic_links|google_mobile_ads|advertising_id|facebook_app_events|flutter_facebook_auth|appsflyer_sdk|adjust_sdk|applovin_max|unity_ads_plugin|ironsource_mediation|easy_ads_flutter|amplitude_flutter|mixpanel_flutter|segment_analytics|flutter_branch_sdk):'
if grep -En "$banned_pub" pubspec.lock; then
  echo "Banned Dart package in pubspec.lock (see backend/PROPOSAL.md)." >&2
  fail=1
fi

aapt="${AAPT2:-$(ls -d "$ANDROID_HOME"/build-tools/*/ | sort -V | tail -n 1)aapt2}"
perms="$("$aapt" dump permissions "$apk")"
echo "$perms" | grep "uses-permission" || true
if echo "$perms" | grep -q "com.google.android.gms.permission.AD_ID"; then
  echo "The APK requests com.google.android.gms.permission.AD_ID." >&2
  fail=1
fi

deps="$(cd android && ./gradlew -q :app:dependencies --configuration releaseRuntimeClasspath)"
banned_maven='com\.google\.android\.gms:play-services-(ads|ads-identifier|ads-lite|measurement[a-z-]*)|com\.google\.firebase:firebase-(analytics|crashlytics|config|inappmessaging|dynamic-links)|com\.facebook\.|com\.applovin|com\.unity3d\.ads|com\.appsflyer|com\.adjust\.|com\.ironsource|io\.branch'
if echo "$deps" | grep -Eo "$banned_maven[^ ]*" | sort -u | grep .; then
  echo "Banned Android dependency in releaseRuntimeClasspath." >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "Families policy check passed."
