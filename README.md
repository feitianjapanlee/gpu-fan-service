# gpu-fan-service
Control fan speed based on GPU temperature

Linux環境のPCに２枚のNVIDIA Tesla T4が接続しています。
T4は本体にファンが付いていないので、T4の冷却は特別に設置したPWM FANで強化します。
PWM FANはマザーボードのCHA_FANに接続しています。
いずれのT4の温度が60度を超えると自動的にPWM FANを最大回転数で回転するようにします。

---

## 設定方法
### 1.BIOSの設定
BIOSのスマートファン機能が有効でカーネルドライバが書き込みを拒否していることがあります。
→ BIOS/UEFI で該当ヘッダの自動制御を「Disabled/Full Speed/Manual」に変更、または Smart Fan/Q-Fan を無効化。

### 2.必要なパッケージをインストール
```bash
sudo apt update -y
sudo apt install -y lm_sensors fancontrol nvidia-smi
```

### 3.ハードウェアを検出
```bash
sudo sensors-detect # すべて”yes”で続ける
```
`sensors-detect`がPWM FANのPWMチャンネルを認識し、`/sys/class/hwmon/hwmon*/pwm*` が作成されます。

### 4.スクリプトを設置
`gpu_fan_control.sh`を`/usr/local/bin/gpu_fan_control.sh`に保存し、実行権限を付与します。

`gpu-fan.service`を`/etc/systemd/system/gpu-fan.service`に保存します。

### 5.起動・有効化
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now gpu-fan.service
```
これで **起動時に自動で** スクリプトが走り、GPU が 60 °C を超えるとファンを 100 % に、下回ると 35 % などに下げます。

---

## 動作確認
```bash
sudo systemctl status gpu-fan.service
```
ログを確認したい場合は `journalctl -u gpu-fan.service -f` で追跡。

---
## トラブルシューティング

| 兆候 | 原因 | 対策 |
|------|------|------|
| PWM ファイルが見つからない | `sensors-detect` が PWM を検出していない | BIOS で CHA_FAN の PWM を有効にする、あるいは別のデバイスにファンを接続する |
| `nvidia-smi` で温度が取得できない | NVIDIA ドライバが正しくインストールされていない | `sudo apt install akmod-nvidia` などでドライバを再インストール、`nvidia-smi` が動作するか確認 |
| ファンが上がらない | `/sys/.../pwmX` に書き込み権限がない | スクリプトを root で実行しているか、`sudo` で実行しているか確認 |
| ファンが過度に回転する | `PWM_MIN` が高すぎる | `PWM_MIN` を 0 に近い値（例 50）に下げる |

---
