#!/system/bin/sh
# Magisk 模块「动作」按钮：执行一次检查，并显示 /data 挂载参数修正的状态
MODDIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
[ -n "$MODDIR" ] || MODDIR=/data/adb/modules/data_mountopt_fix
PROP="$MODDIR/module.prop"
LOG=/data/local/tmp/datafix.log

echo "===== /data 挂载参数修正 ====="
echo
echo "[执行一次检查]"
sh "$MODDIR/service.sh" check | sed 's/^/  /'
echo
echo "[模块状态]（Magisk 模块页显示的文本）"
grep -m1 '^description=' "$PROP" 2>/dev/null | sed 's/^description=/  /'
echo
echo "[fstab.qcom 对 /data 的声明]"
echo "  noatime,nosuid,nodev,barrier=1,noauto_da_alloc,inlinecrypt"
echo
echo "[最近日志]"
if [ -s "$LOG" ]; then
  tail -6 "$LOG" | sed 's/^/  /'
else
  echo "  （无：本次开机未需要修正）"
fi
