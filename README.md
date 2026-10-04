data_mountopt_fix

«Magisk / KernelSU / APatch module for fixing Android "/data" mount option anomalies caused by "errors=remount-ro".

Fixes Momo's 「分区挂载异常」 / abnormal partition mount detection when the actual "/data" mount options no longer match the ROM's "fstab".»

关键词 / Keywords: Android root · Magisk · KernelSU · APatch · Zygisk · "/data" · "errors=remount-ro" · "errors=continue" · mount options · mountinfo · fstab · Momo · partition mount anomaly

---

⚠️ 测试环境（重要）

本模块目前仅在下面这一台设备上实测通过，没有在其它机型 / ROM 上验证。

项目| 值
机型| Redmi K20 Pro（"raphael"）
系统| MIUI 12.5.6（"V12.5.6.0.RFKCNXM"）/ Android 11（SDK 30）
Root| Magisk Kitsune "R6687BB53-kitsune"（27001）
Zygisk| Zygisk Next 1.3.2（内置 Zygisk 关闭）
LSPosed| 2.1.1

其它设备请先确认下面两项，再决定是否使用：

1. 确认 "/data" 确实出现了 "errors=remount-ro"

cat /proc/mounts | grep ' /data '

或者：

cat /proc/self/mountinfo | grep ' /data '

2. 确认 ROM 的 fstab 没有声明 "errors="

例如：

cat /vendor/etc/fstab.qcom

如果你的 "/data" 本来就没有 "errors=remount-ro"，或者 fstab 本身明确声明了 "errors="，本模块没有适用意义。

«请先确认问题确实存在，再安装模块。
在不满足条件的设备上，本模块不会主动修改其它挂载参数。»

---

它解决什么问题？

在部分 Android Root 环境中，开机早期可能有某个 Root / Zygisk 相关组件执行：

mount -o remount,errors=remount-ro /data

这会导致实际的 "/data" mount options 与 ROM 的 "fstab" 声明不一致。

例如，ROM 的 "/vendor/etc/fstab.qcom" 中 "/data" 声明为：

/dev/block/bootdevice/by-name/userdata  /data  ext4
noatime,nosuid,nodev,barrier=1,noauto_da_alloc,inlinecrypt
latemount,wait,check,fileencryption=ice,wrappedkey,quota,reservedsize=128M

其中没有 "errors=" 选项。

但实际挂载状态可能出现：

rw,seclabel,noauto_da_alloc,inlinecrypt,resgid=1065,errors=remount-ro,data=ordered

Momo 会将实际 mount information 与 ROM 的 fstab 声明进行对比，并可能因此显示：

详情：分区挂载异常。

实测结果

"/data" 超级块 / 挂载选项| Momo
"rw,seclabel,noauto_da_alloc,inlinecrypt,resgid=1065,data=ordered"| ✅ 正常
"...,resgid=1065,errors=remount-ro,data=ordered"| ❌ 详情：分区挂载异常

本模块的目的就是处理这个特定的 mount option anomaly：

Unexpected:
errors=remount-ro

↓ fix

errors=continue

从而恢复与 ROM 默认 "/data" 挂载行为一致的状态。

---

背景

本项目最初针对以下环境进行排查：

Redmi K20 Pro / MIUI 12.5.6 / Android 11 / Magisk Kitsune / Zygisk Next / LSPosed

观察到 "/data" 的 "errors=remount-ro" 并不是只在开机时出现一次，而可能在一段时间内再次被加入。

因此，仅在开机时执行一次 remount 并不可靠。

本模块采用持续监视 "/data" mount options 的方式：

检测 /data
    ↓
发现 errors=remount-ro
    ↓
remount /data
    ↓
errors=continue
    ↓
继续监视

---

工作原理

Magisk 在开机阶段调用 "service.sh"，模块随后在后台检查 "/data" 的 mount information。

默认参数：

BURST_ROUNDS=90
BURST_SLEEP=2
STEADY_SLEEP=10
DESC_EVERY=60

含义：

- 开机前约 3 分钟：每 2 秒检查一次
- 之后：每 10 秒检查一次
- 检测到 "errors=remount-ro" 后执行：

mount -o remount,errors=continue /data

修正次数和动作记录在：

/data/local/tmp/datafix.log

日志自动只保留最近 300 行。

---

为什么不是只修一次？

因为实际观察到的 "errors=remount-ro" 可能在之后再次出现。

因此模块不是：

开机 → 修一次 → 退出

而是：

开机 → 高频监视 → 修正
             ↓
        持续低频监视
             ↓
        再次出现就再次修正

这也是本模块存在常驻检查逻辑的主要原因。

---

状态查看

模块会通过 "module.prop" 的 "description" 显示当前状态。

在 Magisk / KernelSU 的模块页面下拉刷新即可查看。

状态| 含义
"[看护中] 正在监视 /data 挂载参数…"| 模块已经启动，正在监视
"✅ 正常（本次开机修正 0 次）"| 暂未发现异常
"🔧 已修正 N 次"| 已经发现并修正过 "errors=remount-ro"
"⚠️ 需要修正但失败"| remount 失败，请检查日志

也可以使用模块的 Action / 动作 按钮：

action.sh

手动执行一次检查并打印状态。

命令行

查看实时状态：

cat /data/adb/modules/data_mountopt_fix/module.prop

查看最近日志：

tail -20 /data/local/tmp/datafix.log

立即检查一次：

sh /data/adb/modules/data_mountopt_fix/service.sh check

---

安装

Magisk / KernelSU / APatch

直接刷：

data_mountopt_fix-v1.0.zip

手动安装

将以下文件复制到：

/data/adb/modules/data_mountopt_fix/

需要：

module.prop
service.sh
action.sh

并确保脚本具有执行权限：

chmod 755 /data/adb/modules/data_mountopt_fix/*.sh

然后重启。

---

卸载

推荐直接在 Magisk / KernelSU / APatch 中移除模块，然后重启。

也可以：

rm -rf /data/adb/modules/data_mountopt_fix

然后重启。

临时禁用

不卸载模块，只想暂时停止：

touch /data/adb/modules/data_mountopt_fix/disable

然后重启。

---

可调参数

编辑 "service.sh" 顶部：

BURST_ROUNDS=90      # 开机高频检查次数
BURST_SLEEP=2        # 高频检查间隔（秒）
STEADY_SLEEP=10      # 后续低频检查间隔（秒）
DESC_EVERY=60        # 状态文本最短刷新间隔（秒）

例如希望进一步缩小异常窗口，可以降低：

STEADY_SLEEP

但这会增加检查频率。

---

已知限制

1. 尚未定位究竟是谁执行了 remount

目前已确认问题表现为 "/data" 出现：

errors=remount-ro

但还没有确定具体是哪个 Root / Zygisk / namespace 操作产生的。

因此本模块采用的是：

发现异常 → 修正

而不是：

阻止源头产生异常

这意味着理论上存在一个时间窗口：

某组件添加 errors=remount-ro
        ↓
模块下一次检查
        ↓
修正

默认情况下这个窗口最大约为 "STEADY_SLEEP" 秒。

---

2. "errors=continue" 的行为

模块使用：

mount -o remount,errors=continue /data

使 ext4 在错误情况下保持挂载，而不是因为该选项转为只读。

在本项目的测试 ROM 中，这与 "/data" 原始 fstab 声明的默认行为一致。

如果你不接受这一行为，请不要使用本模块。

---

3. 仅在单一环境验证

目前只有以下环境经过实际验证：

Redmi K20 Pro
raphael
MIUI 12.5.6
Android 11
Magisk Kitsune
Zygisk Next
LSPosed

其它机型、Android 版本、ROM、Root 方案均未验证。

请不要默认本模块适用于所有 Android 设备。

---

适用性判断

只有同时满足以下条件时，本模块才有实际意义：

1. 设备具有 Root（Magisk / KernelSU / APatch 等）。

2. "/data" 实际出现：
   
   errors=remount-ro

3. ROM 的对应 fstab 对 "/data" 没有声明 "errors="。

4. Momo 等工具因为这个差异报告：
   
   分区挂载异常

可以使用：

cat /proc/mounts | grep ' /data '

自行确认。

如果 "/data" 本来就没有 "errors=remount-ro"，安装本模块不会产生有意义的修改。

---

常见搜索关键词

本项目可能适用于以下问题：

- Momo 分区挂载异常
- Momo "/data" 挂载异常
- Android "/data" mount anomaly
- Android abnormal partition mount
- "errors=remount-ro"
- "errors=continue"
- "/data" mount options
- "/data" mountinfo
- Android fstab mismatch
- Magisk "/data" remount
- KernelSU "/data" mount
- Zygisk "/data" remount
- Zygisk mount namespace
- Magisk module for "/data" mount options
- KernelSU module for mount option fix

---

License

MIT
