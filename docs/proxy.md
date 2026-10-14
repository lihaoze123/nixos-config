# dae、honk 与 doona

dae 和 honk 共用 `modules/nixos/network/dae/config.dae` 的公开规则与 `secrets/dae-nodes.age` 的加密节点。公开配置保留 DMIT/HK 分组、国内直连、AI/GitHub 经 DMIT、Google 经 HK、UDP 443 阻断，以及 HK 默认出站。`dae-config.age` 已不再被配置或加密规则引用；旧加密文件保留供迁移核对。

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

代理由 `my.network.proxy.backend` 选择 `"dae"`、`"honk"` 或 `null`，两者天然互斥；另有求值断言防止 honk 与手动启用的 `services.dae` 同时存在，systemd `Conflicts` 也有约束。honk 启动与 dae 停止之间还有顺序约束，避免同时接管接口。

```nix
my.network.proxy.backend = "honk";
```

两个引擎共用 `modules/nixos/network/dae/render-config.nix` 生成配置，保留 `wan_interface: auto`。`my.network.proxy.lanInterfaces` 默认为空列表，不生成 `lan_interface`，仅代理本机流量。启用 Docker 或 libvirt 不会自动加入 `docker0`、`virbr0`，因为服务启用并不保证这些网桥已经存在；例如 libvirt 的默认网络可能尚未启动，否则 honk 会因绑定不存在的接口而启动失败。

需要代理虚拟机或局域网转发流量时，在主机配置中显式指定接口：

```nix
my.network.proxy.lanInterfaces = [ "virbr0" ];
```

显式配置的接口必须在代理启动前存在。对于 libvirt 的默认网络，先用 `sudo virsh -c qemu:///system net-start default` 启动网络，并用 `sudo virsh -c qemu:///system net-autostart default` 设置自动启动；自动启动仍不保证网桥先于代理就绪，若需要开机即代理虚拟机流量，还应配置相应的服务启动依赖。

### class 的虚拟机代理

`hosts/class/virtualisation.nix` 在启用虚拟机功能时将 `virbr0` 加入代理接口。`libvirt-default-network.service` 为 libvirt 的 `default` 网络设置自动启动，按需启动网络并确认 `virbr0` 已存在；dae 或 honk 都必须等待这个服务完成后才能启动。网桥上的 DNS TCP/UDP 53 与 DHCP UDP 67 已放行。

在 virt-manager 中使用 `QEMU/KVM` 系统连接（`qemu:///system`），将虚拟机网卡的网络源选为 `Virtual network 'default': NAT`，网卡型号建议为 `virtio`。虚拟机通过 DHCP 获取 `192.168.122.0/24` 内的地址、网关和 DNS，即可沿用宿主机的代理分流规则，无需在虚拟机内另设 HTTP/SOCKS 代理。其他虚拟网络不包含在这项配置中。

构建并激活 `class` 后可检查：

```bash
systemctl is-active libvirt-default-network dae
virsh -c qemu:///system net-list --all
ip link show virbr0
journalctl -u dae -b --no-pager | rg 'Bind to LAN'
```

## honk 与 doona

固定使用 [doona beta.20 发布附件](https://github.com/Zakkaus/doona/releases/tag/v0.1.0-beta.20)中的 `honk debug.2026.10.12.native-api.1`，下载由 SHA-256 校验。它包含 eBPF、原生 API 和内嵌 doona beta.20；版本更新需同时核对引擎与前端契约。

honk 的附加配置启用 `tls_implementation: utls` 和 `utls_imitate: chrome_auto`，使用 Chrome 风格的 ClientHello 模拟。节点链接中的 `fp` 不控制 honk 的握手指纹；模拟也不保证与真实浏览器完全一致。构建并激活配置后，用 `journalctl -u honk -b --no-pager | rg 'TLS mode:'` 确认日志显示 `Chrome fingerprint=true`。REALITY 节点若改用 443，须先调整服务端监听或转发，再同步客户端端口；仅修改客户端不能完成迁移。

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

要持久恢复 dae，在主机的 `default.nix` 中将 `my.network.proxy.backend` 设为 `"dae"`，再构建并 switch。图形登录配置发生变化时仍按桌面文档采用 boot 后重启；不清理旧系统代际。
