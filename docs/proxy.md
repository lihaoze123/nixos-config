# dae、honk 与 doona

dae 和 honk 共用 `modules/dae/config.dae` 的公开规则与 `secrets/dae-nodes.age` 的加密节点。公开配置保留 DMIT/HK 分组、国内直连、AI/GitHub 经 DMIT、Google 经 HK、UDP 443 阻断，以及 HK 默认出站。`dae-config.age` 已不再被配置或加密规则引用；旧加密文件保留供迁移核对。

## 节点凭据

加密文件只包含完整的节点块，节点名称须为 `DMIT` 和 `HK`：

```dae
node {
    DMIT: 'vless://替换为真实分享链接'
    HK: 'vless://替换为真实分享链接'
}
```

使用现有 ragenix 规则编辑，不在普通仓库文件中保存真实分享链接：

```bash
cd /home/chumeng/nixos-config/secrets
ragenix -e dae-nodes.age -i ~/.ssh/id_ed25519
```

系统通过 agenix 将节点解密为 `/etc/dae/nodes.dae`，权限为 root `0400`，并使用真实文件而非符号链接。dae 的公开配置位于 `/etc/dae/config.dae`，直接 include 同目录节点。honk 启动前把公开配置与解密节点复制到 root 私有的 `/run/honk/`，满足 honk 对 include 真实路径的限制；停止后由 systemd 清理该运行目录。凭据不会进入 Nix store，store 中仅包含公开配置与加密文件。

## 功能与接口

`my.features.dae.enable` 和 `my.features.honk.enable` 互斥；求值断言和 systemd `Conflicts` 都有约束。honk 启动与 dae 停止之间还有顺序约束，避免同时接管接口。

```nix
my.features = {
  dae.enable = false;
  honk.enable = true;
};
```

两个引擎共用 `modules/dae/render-config.nix` 生成配置，保留 `wan_interface: auto`。LAN 接口按最终系统配置选择：启用 `virtualisation.docker.enable` 时加入 `docker0`，启用 `virtualisation.libvirtd.enable` 时加入 `virbr0`；两者均关闭时不生成 `lan_interface`，仅代理本机流量。仓库的 `my.features.docker.enable` 和 `my.features.virtualMachines.enable` 分别控制这两个服务。

## honk 与 doona

固定使用 doona beta.19 发布附件中的 `honk debug.2026.10.9.native-api.2`，下载由 SHA-256 校验。它包含 eBPF、原生 API 和内嵌 doona；版本更新需同时核对引擎与前端契约。

本机访问 `http://127.0.0.1:9527/ui/`，首次创建管理员账号；9527 不开放到局域网。账号与运行状态位于 `/var/lib/honk/state/honk.db`。配置由 Nix 管理，因此 `config_write: false`，在仓库修改规则后重建；界面用于查看流量、DNS 和节点状态。

两套引擎使用相同的 DNS 上游和分流规则：阿里 `tcp+udp://223.5.5.5:53`，Google DoH `https://dns.google/dns-query`。上游连接沿用公开的流量路由规则，阿里直连、Google 经 HK，不另加 honk 专用的出站覆盖。[dae DNS 文档](https://github.com/daeuniverse/dae/blob/v2.1.1/docs/en/configuration/dns.md)、[honk DNS 文档](https://github.com/daeuniverse/honk/blob/main/doc/en/reference/dns.md)。

## 在 class 使用 honk

`class` 已启用 honk，dae 保持关闭；其他主机的代理选择由各自的功能开关决定。在仓库根目录先构建，再激活：

```bash
previous_system=$(readlink -f /run/current-system)
nixos-rebuild build --flake .#class
sudo nixos-rebuild switch --flake .#class
systemctl is-active honk
```

预期 honk 为 active，dae 不再运行。打开 `http://127.0.0.1:9527/ui/` 创建管理员账号，检查网站访问和 DNS。原始 journald 日志可能包含节点连接元数据，排查时不要直接公开整份日志。

需要恢复激活前的运行状态时：

```bash
sudo "$previous_system/bin/switch-to-configuration" test
```

要持久恢复 dae，在 `hosts/class/features.nix` 中关闭 honk、启用 dae，再构建并 switch。图形登录配置发生变化时仍按桌面文档采用 boot 后重启；不清理旧系统代际。
