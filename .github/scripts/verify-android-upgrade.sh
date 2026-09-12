#!/usr/bin/env bash
set -euo pipefail

if (($# != 5)); then
  echo "Usage: $0 <lower-apk> <published-apk> <application-id> <final-version-name> <final-version-code>" >&2
  exit 2
fi

lower_apk=$1
published_apk=$2
application_id=$3
final_version_name=$4
final_base_version_code=$5
[[ "$final_base_version_code" =~ ^[0-9]+$ ]] || { echo 'Final base versionCode is invalid.' >&2; exit 1; }
final_version_code=$((10#$final_base_version_code + 4000))

lower_version_code=$(apkanalyzer manifest version-code "$lower_apk" | tr -d '\r')
published_version_code=$(apkanalyzer manifest version-code "$published_apk" | tr -d '\r')
[[ "$lower_version_code" =~ ^[0-9]+$ ]] || { echo 'Lower APK has an invalid versionCode.' >&2; exit 1; }
[[ "$published_version_code" == "$final_version_code" ]] || { echo 'Published APK versionCode does not match the tagged source.' >&2; exit 1; }
((published_version_code > lower_version_code)) || { echo 'Published APK versionCode is not higher than the installed APK.' >&2; exit 1; }

adb install "$lower_apk"
adb shell pm list packages | grep -Fx "package:$application_id" >/dev/null
adb install -r "$published_apk"

installed_package=$(adb shell dumpsys package "$application_id")
installed_version_code=$(sed -n 's/.*versionCode=\([0-9][0-9]*\).*/\1/p' <<< "$installed_package" | head -n 1)
installed_version_name=$(sed -n 's/.*versionName=\([^[:space:]]*\).*/\1/p' <<< "$installed_package" | head -n 1)
[[ "$installed_version_code" == "$final_version_code" ]] || {
  echo "Installed versionCode is $installed_version_code, expected $final_version_code." >&2
  exit 1
}
[[ "$installed_version_name" == "$final_version_name" ]] || {
  echo "Installed versionName is $installed_version_name, expected $final_version_name." >&2
  exit 1
}

echo "Updated $application_id in place from $lower_version_code to $installed_version_code."
