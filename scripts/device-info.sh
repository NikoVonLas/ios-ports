#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need_command ideviceinfo

printf 'Device: %s\n' "$(ideviceinfo -k DeviceName)"
printf 'Product: %s\n' "$(ideviceinfo -k ProductType)"
printf 'iPadOS: %s\n' "$(ideviceinfo -k ProductVersion)"
printf 'CPU: %s\n' "$(ideviceinfo -k CPUArchitecture)"
printf 'Locked: %s\n' "$(ideviceinfo -k PasswordProtected)"

