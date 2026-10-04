data_mountopt_fix

> ⚠️ 测试环境（重要）

本模块仅在下面这一台设备上实测通过，没有在其它机型/ROM 上验证过：

项目	值

机型	Redmi K20 Pro（raphael，代号 raphael）
系统	MIUI 12.5.6（V12.5.6.0.RFKCNXM）/ Android 11（SDK 30）
Root	Magisk Kitsune R6687BB53-kitsune (27001)
Zygisk	Zygisk Next 1.3.2（内置 Zygisk 关闭），LSPosed 2.1.1


其它设备请先自己确认这两件事再决定用不用：

1. /data 是否真的被加上了 errors=remount-ro：
cat /proc/mounts | grep ' /data '


2. 你的 /vendor/etc/fstab.qcom（或对应 fstab）里 /data 的声明是否不含 errors=



不满足的话本模块没有任何意义（会空转，不会修改你系统里的东西）。



一个针对 Momo「分区挂载异常」 的 Magisk 模块：看护 /data 的挂载参数，
把被额外加上的 errors=remount-ro 移除，让它与 ROM 的 fstab 声明一致。

> A Magisk module that keeps /data's mount options matching the ROM's
fstab.qcom by removing an unexpected errors=remount-ro.
Fixes Momo's "分区挂载异常" (abnormal partition mount) detection.




---

背景

在部分机器上（本次实测：Redmi K20 Pro / MIUI 12 / Android 11，
Magisk Kitsune + Zygisk Next + LSPosed），开机早期会有某个 root 组件执行：

mount -o remount,errors=remount-ro /data

而 /vendor/etc/fstab.qcom 中 /data 的声明是：

/dev/block/bootdevice/by-name/userdata  /data  ext4  
  noatime,nosuid,nodev,barrier=1,noauto_da_alloc,inlinecrypt  
  latemount,wait,check,fileencryption=ice,wrappedkey,quota,reservedsize=128M

并没有 errors= 选项。Momo 会拿实际挂载参数和 ROM 声明对比，
不一致就报：

详情：分区挂载异常。

实测（A/B 各重启一次 + 最小复现）：

/data 的超级块选项	Momo

rw,seclabel,noauto_da_alloc,inlinecrypt,resgid=1065,data=ordered	正常，无详情项
…,resgid=1065,errors=remount-ro,data=ordered	详情：分区挂载异常。


这个 remount 不是开机一次性的，日志显示它可能在一段时间内反复出现，
所以模块采用常驻看护而不是只修一次。

工作原理

service.sh 由 Magisk 在开机时调用，在后台循环：

开机前 3 分钟：每 2 秒检查一次

之后：全程每 10 秒检查一次

一旦 /proc/self/mountinfo 里 /data 带 errors=remount-ro，
就 mount -o remount,errors=continue /data 还原成 fstab 声明的状态


修正计数与动作写 /data/local/tmp/datafix.log（自动只留最近 300 行）。

状态查看

模块的 module.prop 里 description 就是实时状态，Magisk 模块页（下拉刷新）可见：

文本	含义

[看护中] 正在监视 /data 挂载参数…	刚开机，看护已启动
✅ 正常（本次开机修正 0 次）｜最后检查 09:09:31	未发现异常
🔧 已修正 N 次（最近 10-04 09:05:43）｜最后检查 …	出手修过
⚠️ 需要修正但失败，请查看 /data/local/tmp/datafix.log	报警


也可以点模块的「动作」按钮（action.sh）手动跑一次检查并打印完整状态。

命令行：

cat /data/adb/modules/data_mountopt_fix/module.prop          # 状态文本  
tail -20 /data/local/tmp/datafix.log                          # 修正记录  
sh /data/adb/modules/data_mountopt_fix/service.sh check       # 立即检查一次

安装

Magisk / KernelSU / APatch：刷 data_mountopt_fix-v1.0.zip

或手动：把本仓库的 module.prop、service.sh、action.sh
放进 /data/adb/modules/data_mountopt_fix/，chmod 755 *.sh，重启


卸载

Magisk 应用里移除模块后重启，或

rm -rf /data/adb/modules/data_mountopt_fix 后重启


想临时暂停（不卸载）：touch /data/adb/modules/data_mountopt_fix/disable 后重启。

可调参数

service.sh 顶部：

BURST_ROUNDS=90      # 开机前 90 轮  
BURST_SLEEP=2        # 每 2 秒查一次（约 3 分钟）  
STEADY_SLEEP=10      # 之后全程每 10 秒查一次  
DESC_EVERY=60        # 状态文本最快每 60 秒刷一次

已知限制

没有定位到「谁」在做这次 remount，所以修正发生在它出现之后（≤ STEADY_SLEEP 秒）。
若某个应用恰好在这段窗口里读取挂载表，理论上仍可能看到一次异常；
把 STEADY_SLEEP 调小可以缩小窗口。

mount -o remount,errors=continue 会让 ext4 在出错时保持挂载而不是转为只读，
这与本 ROM fstab 声明的默认行为一致；介意的话可以删掉本模块。

只在 Redmi K20 Pro / MIUI 12.5.6 / Android 11 上实测过，其它机型/ROM 未验证。


适用性

只有当你的设备同时满足以下条件时才有意义：

1. 有 root（Magisk/KSU/APatch）；


2. /data 被某个组件加了 errors=remount-ro（cat /proc/mounts | grep ' /data ' 自查）；


3. 你在意 Momo 之类的检测报「分区挂载异常」。



如果 /data 本来就没有这个选项，装本模块不会有任何变化（空转，不写状态外的东西）。

License

MIT