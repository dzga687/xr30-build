# 「 自编译XR30」固件 — 编译包（padavanonly 6.6 底座）

目标：在 **padavanonly/immortalwrt-mt798x-6.6**（ImmortalWrt 24.10，内核 **6.6** + MTK mtwifi 原厂闭源驱动 mt7915_mtwifi）上，为 **CMCC XR30 NAND** 编译一份固件，并复刻冰奇固件特性：

- MTK **mtwifi 闭源驱动**（**不是** mt76 开源），专治 `NOT_ROBUST_UNICAST_FRAME` 中继断流（已通过 rc.local + hotplug 固化 PMF 关闭补丁）
- 预置 **iStore**、**无线中继面板**（luci-app-mtk / WISP）、**USB RNDIS/NCM/QMI 4G 上网**
- 预置 **QModem**（5G/4G 模组管理面板）与 **OpenClash**（nftables 模式）
- 适配 **ubootmod / H 大 fixed-parts** 分区布局（bl-mt798x-xr30 恢复台）

---

## ⚠️ 最重要的前提
- **设备必须是 XR30 NAND**（`cmcc_xr30_nand`，128M SPI-NAND）。eMMC 版（RAX3000Z 增强版）分区不通用，**不能互刷**。
- **U-Boot 必须是 ubootmod / H 大 fixed-parts 布局**（bl-mt798x-xr30）。原厂 stock 布局请改用对应的 stock 镜像，本包按 ubootmod 产出。
- padavanonly 6.6 **已原生合入 `cmcc_xr30-nand`**，无需任何第三方 fork 或设备树补丁。

## 关于「 PMF 补丁」
mtwifi 没有能"永久关 PMF"的 menuconfig 开关。`diy-part2.sh` 用 `files/` 覆盖层在 `rc.local`（开机）和 `hotplug.d/iface`（apcli0/apcli1 up 时）自动执行：
```
iwpriv apcli0 set PMFMFPC=0
iwpriv apcli0 set PMFMFPR=0
iwpriv apcli0 set PMFSHA256=0
```
效果等同于冰奇那版"PMF 相关补丁"，重启/重连都生效，根治中继因 802.11w 协商失败而掉线。

---

## 用法 A：GitHub Actions 一键编译（推荐）
1. 把本目录（`xr30-build/`）内容推到你的一个 GitHub 仓库（含 `.github/workflows/build.yml`、`.config`、`diy-part2.sh`）。
2. GitHub → Actions → **Build XR30 NAND (mtwifi 6.6)** → `Run workflow`。
3. 跑完在 Artifacts 下载 `xr30-nand-mtwifi-6.6`，里面是 `mediatek/mt7981/` 目录下所有镜像。

## 用法 B：本地 / WSL2 编译
```bash
git clone --depth=1 -b openwrt-24.10-6.6 https://github.com/padavanonly/immortalwrt-mt798x-6.6 openwrt
cd openwrt
echo "src-git istore https://github.com/linkease/istore;master" >> feeds.conf.default
echo "src-git qmodem https://github.com/FUjr/modem_feeds.git;main" >> feeds.conf.default
echo "src-git openclash https://github.com/vernesong/OpenClash.git;master" >> feeds.conf.default
./scripts/feeds update -a && ./scripts/feeds install -a
cp /path/to/xr30-nand-mtwifi.config .config
bash /path/to/diy-part2.sh
make defconfig
make -j$(nproc) V=s
# 产物: bin/targets/mediatek/mt7981/immortalwrt-mediatek-mt7981-cmcc_xr30_nand-squashfs-sysupgrade.bin
```

---

## 刷入 & 验证
- **ubootmod 布局**：路由器断电→按住复位键通电进 bl-mt798x-xr30 Web 恢复台（默认 `192.168.1.1`）→ 上传 `*-sysupgrade.bin`。
  （也可在现有系统 LuCI → 系统 → 备份/升级 里 `sysupgrade`，记得勾选"不保留配置"做干净升级。）
- 默认后台：`http://192.168.1.1`（用户 root，默认无密码，首次登录请设密码）。
- 验证中继不再断流：`logread | grep PMF` 不应再刷 `NOT_ROBUST_UNICAST_FRAME`。
- 若仍需手动临时修复：`iwpriv apcli0 set PMFMFPC=0; iwpriv apcli0 set PMFMFPR=0; iwpriv apcli0 set PMFSHA256=0`（本包已固化，重启也生效）。

## 排错
- `make` 报找不到 `cmcc_xr30_nand` 目标：到 `target/linux/mediatek/mt7981.mk` 确认设备名（可能带细微差异），改 `.config` 第 6 行符号即可。
- 镜像过大放不进 NAND：可去掉 `luci-app-qmodem-mwan` 或某个不用的包再编。
- OpenClash 启动后需联网下载 Clash 内核（服务 → OpenClash → 版本更新）。
