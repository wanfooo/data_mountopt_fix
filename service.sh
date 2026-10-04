#!/system/bin/sh
# =====================================================================
#  /data 挂载参数修正
#
#  背景：
#    /vendor/etc/fstab.qcom 里 /data 声明为
#      noatime,nosuid,nodev,barrier=1,noauto_da_alloc,inlinecrypt
#    其中并没有 errors= 选项。本机实测：只要启用 Zygisk Next，
#    开机早期（post-fs-data 之后约 13 秒）就会有 root 组件执行
#      mount -o remount,errors=remount-ro /data
#    Momo 会按「挂载参数与 ROM 声明不一致」把它判成
#      详情：分区挂载异常。
#
#  作用：
#    开机后看护 /data，一旦发现 errors=remount-ro 就还原成 fstab
#    声明的状态，并把当前状态写进 module.prop 的 description
#    （Magisk 模块页可读），日志写 /data/local/tmp/datafix.log。
#
#  用法：
#    service.sh          开机时由 Magisk 自动调用（后台看护）
#    service.sh check    只做一次检查（模块动作按钮/排障用）
# =====================================================================

MODDIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
[ -n "$MODDIR" ] || MODDIR=/data/adb/modules/data_mountopt_fix
PROP="$MODDIR/module.prop"
STATE="$MODDIR/state.txt"
LOG=/data/local/tmp/datafix.log

BURST_ROUNDS=90      # 开机前 90 轮
BURST_SLEEP=2        # 每 2 秒查一次（约 3 分钟，抓开机那次 remount）
STEADY_SLEEP=10      # 之后全程每 10 秒查一次
DESC_EVERY=60        # 状态文本最快每 60 秒刷一次

COUNT=0
LAST_FIX="-"
LAST_COUNT=-1

# ---------- 状态文件（同一次开机内累计） ----------
read_state() {
  if [ -f "$STATE" ]; then
    . "$STATE" 2>/dev/null
    COUNT=${COUNT:-0}
    LAST_FIX=${LAST_FIX:--}
  fi
}

write_state() {
  printf 'COUNT=%s\nLAST_FIX=%s\n' "$COUNT" "$LAST_FIX" > "$STATE" 2>/dev/null
}

# ---------- 写 module.prop 的 description ----------
set_desc() {
  [ -f "$PROP" ] || return 0
  [ "$(grep -m1 '^description=' "$PROP" 2>/dev/null)" = "description=$1" ] && return 0
  if sed -i "s|^description=.*|description=$1|" "$PROP" 2>/dev/null; then
    return 0
  fi
  grep -v '^description=' "$PROP" > "$PROP.tmp" 2>/dev/null || return 0
  echo "description=$1" >> "$PROP.tmp"
  mv -f "$PROP.tmp" "$PROP" 2>/dev/null
}

# ---------- 日志（保留最近 300 行） ----------
logline() {
  echo "$(date '+%F %T') $1" >> "$LOG"
  if [ "$(wc -l < "$LOG" 2>/dev/null)" -gt 300 ]; then
    tail -n 200 "$LOG" > "$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG"
  fi
}

# ---------- 单次检查：0=刚修正 1=修正失败 2=正常 ----------
fix_once() {
  if grep -q ' /data .*errors=remount-ro' /proc/self/mountinfo 2>/dev/null; then
    if mount -o remount,errors=continue /data 2>/dev/null; then
      COUNT=$((COUNT + 1))
      LAST_FIX=$(date '+%m-%d %H:%M:%S')
      write_state
      logline "已还原 /data 挂载选项（本次开机第 $COUNT 次）"
      return 0
    fi
    logline "发现 errors=remount-ro，但 remount 失败"
    return 1
  fi
  return 2
}

# ---------- 单次检查模式 ----------
if [ "$1" = "check" ]; then
  read_state
  fix_once
  rc=$?
  NOW=$(date '+%m-%d %H:%M:%S')
  case $rc in
    2)
      echo "OK      : /data 未发现 errors=remount-ro"
      set_desc "✅ 正常（本次开机修正 $COUNT 次）｜最后检查 $NOW"
      ;;
    0)
      echo "FIXED   : 已还原 /data 挂载选项"
      set_desc "🔧 已修正 $COUNT 次（最近 $NOW）｜最后检查 $NOW"
      ;;
    1)
      echo "FAILED  : 发现异常但修正失败"
      set_desc "⚠️ 需要修正但失败，请查看 /data/local/tmp/datafix.log"
      ;;
  esac
  grep ' /data ' /proc/self/mountinfo | head -1 | awk '{print "  现在: " $NF}'
  exit $rc
fi

# ---------- 开机看护 ----------
(
  # 新的一次开机：计数归零
  COUNT=0
  LAST_FIX="-"
  write_state
  set_desc "[看护中] 正在监视 /data 挂载参数…"
  logline "看护开始"
  last_write=0
  i=0
  while :; do
    read_state
    fix_once
    rc=$?
    now=$(date +%s)
    if [ "$COUNT" != "$LAST_COUNT" ] || [ $((now - last_write)) -ge $DESC_EVERY ]; then
      if [ "$rc" = "1" ]; then
        set_desc "⚠️ 需要修正但失败，请查看 /data/local/tmp/datafix.log"
      elif [ "$COUNT" = "0" ]; then
        set_desc "✅ 正常（本次开机修正 0 次）｜最后检查 $(date '+%H:%M:%S')"
      else
        set_desc "🔧 已修正 $COUNT 次（最近 $LAST_FIX）｜最后检查 $(date '+%H:%M:%S')"
      fi
      last_write=$now
      LAST_COUNT=$COUNT
    fi
    if [ $i -lt $BURST_ROUNDS ]; then
      sleep $BURST_SLEEP
    else
      sleep $STEADY_SLEEP
    fi
    i=$((i + 1))
  done
) &
