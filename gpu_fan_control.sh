#!/usr/bin/env bash
# GPU温度でケースファンPWMを制御

set -u  # 未定義変数をエラーに
# set -e は敢えて使わず、途中の失敗でもループ継続させる
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 設定値
TEMP_THRESHOLD=${TEMP_THRESHOLD:-60}   # ℃
PWM_MIN=${PWM_MIN:-100}                # 0–255
PWM_MAX=${PWM_MAX:-255}
SLEEP_SEC=${SLEEP_SEC:-5}

# PWMパスを自動探索（環境変数 PWM_PATH があればそれを優先）
# PWM_PATH=/sys/class/hwmon/hwmon5/pwm1
PWM_PATH="${PWM_PATH:-}"
if [ -z "$PWM_PATH" ]; then
  for d in /sys/class/hwmon/hwmon*; do
    [ -e "$d/pwm1" ] && PWM_PATH="$d/pwm1" && break
  done
fi

if [ -z "${PWM_PATH:-}" ] || [ ! -e "$PWM_PATH" ]; then
  echo "ERROR: pwm1 が見つかりません。PWM_PATH を環境変数で指定してください。" >&2
  exit 1
fi

HWDIR="$(dirname "$PWM_PATH")"
# 手動制御に切り替え（ドライバにより 1=マニュアル の場合が多い）
if [ -w "$HWDIR/pwm1_enable" ]; then
  echo 1 > "$HWDIR/pwm1_enable" 2>/dev/null || true
fi

cleanup() {
  # 自動制御へ戻す（環境によっては 2=自動 の場合あり。1/2 を試行）
  echo 2 > "$HWDIR/pwm1_enable" 2>/dev/null || echo 0 > "$HWDIR/pwm1_enable" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

while :; do
  GPU_TEMP="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk 'BEGIN{max=0} {if ($1>max) max=$1} END{print max}')"
  if [[ "$GPU_TEMP" =~ ^[0-9]+$ ]]; then
    if [ "$GPU_TEMP" -gt "$TEMP_THRESHOLD" ]; then
      VAL="$PWM_MAX"
    else
      VAL="$PWM_MIN"
    fi
    echo "$VAL" > "$PWM_PATH" 2>/dev/null || true
  fi
  sleep "$SLEEP_SEC"
done
