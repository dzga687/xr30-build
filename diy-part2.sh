#!/bin/bash
# diy-part2.sh — 在 openwrt 源码根目录执行（feeds install 之后、make defconfig 之前）
# 固化「冰奇同款」apcli PMF 补丁，根治 NOT_ROBUST_UNICAST_FRAME 中继断流。
# padavanonly 6.6 (mtwifi 闭源) 上，关闭 apcli 客户端口的 PMF/802.11w 协商，
# 使其以普通 WPA2-PSK 客户端连接上游 AP，中继不再因 802.11w 失败而掉线。
# 同时写入 rc.local(开机) 与 hotplug(接口 up) 两处，重启/重连均生效。

set -e

mkdir -p files/etc/hotplug.d/iface

cat > files/etc/rc.local <<'EOF'
#!/bin/sh
# apcli PMF 关闭补丁（冰奇同款）—— 根治中继断流
sleep 15
for iface in apcli0 apcli1; do
    ip link show "$iface" >/dev/null 2>&1 || continue
    iwpriv "$iface" set PMFMFPC=0 2>/dev/null
    iwpriv "$iface" set PMFMFPR=0 2>/dev/null
    iwpriv "$iface" set PMFSHA256=0 2>/dev/null
done
exit 0
EOF
chmod +x files/etc/rc.local

cat > files/etc/hotplug.d/iface/99-apcli-pmf <<'EOF'
#!/bin/sh
[ "$ACTION" = "ifup" ] || exit 0
case "$INTERFACE" in
    apcli0|apcli1) ;;
    *) exit 0 ;;
esac
iwpriv "$INTERFACE" set PMFMFPC=0 2>/dev/null
iwpriv "$INTERFACE" set PMFMFPR=0 2>/dev/null
iwpriv "$INTERFACE" set PMFSHA256=0 2>/dev/null
EOF
chmod +x files/etc/hotplug.d/iface/99-apcli-pmf

echo "[*] apcli PMF 补丁已写入 files/ 覆盖层，编译后固化进固件。"
