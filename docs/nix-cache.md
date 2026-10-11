# 私有 R2 缓存配置与维护

下载由 Nix 直接访问 R2；手动上传采用“导出本地签名缓存，再用 rclone 上传”的流程。
配置位于 [modules/nix-cache/default.nix](../modules/nix-cache/default.nix)，通过共享模块
应用到 laptop、home、class、base；nixos 别名继承 laptop，installer 保持独立。

## 配置在哪里

| 内容 | 配置或位置 |
| --- | --- |
| R2 桶 | `nix-cache`，私有访问 |
| S3 endpoint | `https://6ed1b3dcdc0ddb8c496ad7de884c55cc.r2.cloudflarestorage.com` |
| 区域、凭据 profile | `auto`、`r2-cache` |
| 加密凭据 | `secrets/r2-cache-credentials.age`，收件人规则在 `secrets/secrets.nix` |
| 系统解密文件 | `/run/agenix/r2-cache-credentials`，root 所有、权限 `0400` |
| daemon 认证 | `systemd.services.nix-daemon.environment.AWS_SHARED_CREDENTIALS_FILE` |
| 下载源、公钥 | `nix.settings.extra-substituters`、`extra-trusted-public-keys` |
| 上传签名私钥 | 上传设备的 `~/.local/share/nix-cache/signing-key` |
| 对应公钥文件 | 上传设备的 `~/.local/share/nix-cache/public-key`，公钥名为 `r2-fonts-1` |

所有设备使用同一份桶级读写凭据。R2 凭据用于认证；签名私钥用于签名，下载设备通过
共享模块中的公钥验签。签名私钥只保存在上传设备或加密备份中，不进入仓库或 Nix store。
更新凭据密文并部署配置后，模块的 `restartTriggers` 会触发 nix-daemon 重启。

R2 桶根目录中的 `nix-cache-info` 描述缓存；`<store-hash>.narinfo` 包含数据文件地址、
哈希、引用关系和签名；`nar/` 保存压缩后的 NAR。应让 `nix copy` 生成这些文件。
[Nix 本地二进制缓存说明](https://nix.dev/manual/nix/2.34/store/types/local-binary-cache-store.html)

## 应用到设备

在目标设备同步仓库后，先构建，再写入下次启动。以下以当前 class 为例，其他设备
替换为自身的主机入口：

```bash
nixos-rebuild build --flake .#class
sudo nixos-rebuild boot --flake .#class
```

保存工作后重启。配置生效后正常 rebuild 即可：本地已有的输出直接复用，缺失的输出
从缓存下载并验签，未命中缓存时才构建。无需给每个软件单独添加缓存配置。

首次构建仍使用当前运行系统的缓存配置。如果新设备尚无 Windows 字体，先关闭
`windowsFonts` 并部署缓存配置，再开启字体并构建，避免在缓存生效前下载、解包 ISO。

新主机还需要把解密公钥加入 `secrets/keys.nix` 和 R2 凭据的 `publicKeys` 规则，
重新加密，并将主机的 `age.identityPaths` 设置为对应私钥路径。base 当前继承的
`/home/chumeng/.ssh/id_rsa` 路径需要按新机器调整。class 的系统解密密钥是
`/etc/ssh/ssh_host_ed25519_key`；手动维护时使用用户的 `~/.ssh/id_ed25519`。

## 进入临时维护会话

以下命令均在仓库根目录执行。先进入包含工具的 **Bash**，然后再粘贴后面的代码；
后面的变量、trap 和命令替换使用 Bash 语法。

```bash
nix shell --inputs-from . nixpkgs#rage nixpkgs#rclone --command bash
```

在这个 Bash 中执行一次以下配置。退出该会话时删除明文临时凭据；凭据值不会出现在
命令行参数或 rclone 配置文件中。当前 class 使用 id_ed25519，其他设备需换成实际
能解密该密文的私钥，例如 laptop 的 id_rsa。

```bash
set -euo pipefail
umask 077
task_r2_credentials=$(mktemp "${XDG_RUNTIME_DIR:?}/r2-maintenance.XXXXXX")
trap 'rm -f -- "$task_r2_credentials"' EXIT

rage -d -i ~/.ssh/id_ed25519 \
  secrets/r2-cache-credentials.age > "$task_r2_credentials"

export AWS_SHARED_CREDENTIALS_FILE="$task_r2_credentials"
export RCLONE_S3_PROVIDER=Cloudflare
export RCLONE_S3_ENV_AUTH=true
export RCLONE_S3_PROFILE=r2-cache
export RCLONE_S3_REGION=auto
export RCLONE_S3_NO_CHECK_BUCKET=true
export RCLONE_S3_ENDPOINT="https://6ed1b3dcdc0ddb8c496ad7de884c55cc.r2.cloudflarestorage.com"

task_r2_store="s3://nix-cache?endpoint=6ed1b3dcdc0ddb8c496ad7de884c55cc.r2.cloudflarestorage.com&region=auto&profile=r2-cache"
```

下面的上传、校验、用量和清理命令使用这个维护会话的环境。
`Config file ... not found - using defaults` 是正常提示：rclone 从环境变量读取配置。
[rclone 认证说明](https://rclone.org/s3/#authentication)

## 上传字体或其他已构建结果

先构建目标输出。例如 Windows 字体：

```bash
nix build --out-link result-cache \
  .#nixosConfigurations.class.pkgs.windows-fonts
```

在维护会话中执行下面的流程。上传已有结果时，将 `task_r2_source` 换成
`./result-windows-fonts`、其他结果链接或实际 `/nix/store/...` 路径。
`nix copy` 导出运行时引用闭包；大型应用可能同时导出很多依赖，构建输入和 ISO
并不会仅因为参与过构建就自动进入这份闭包。

每次使用独立暂存目录，避免将以前准备过、后来已从远端删除的旧索引再次上传。

```bash
task_r2_source=./result-cache
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
task_r2_stage=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/nix-r2-upload.XXXXXX")
printf '本次暂存目录：%s\n' "$task_r2_stage"

nix copy \
  --to "file://$task_r2_stage?compression=zstd&compression-level=3&secret-key=$HOME/.local/share/nix-cache/signing-key" \
  "$task_r2_source"

# 先上传数据，使用 4 个并发分片。
rclone copy "$task_r2_stage/nar" :s3:nix-cache/nar \
  --checksum \
  --s3-upload-cutoff 16M \
  --s3-chunk-size 16M \
  --s3-upload-concurrency 4 \
  --progress

# 数据上传成功后，再发布索引和缓存信息。
rclone copy "$task_r2_stage" :s3:nix-cache \
  --exclude '/nar/**' --checksum --progress

# 只核对本批文件；远端允许同时保存其他批次的缓存。
rclone check "$task_r2_stage" :s3:nix-cache --one-way

# 检查上传闭包的签名，刷新之前“未命中”的记录。
nix store verify --store "$task_r2_store" --recursive --no-contents \
  --option extra-trusted-public-keys "$(cat ~/.local/share/nix-cache/public-key)" \
  --option narinfo-cache-negative-ttl 0 --refresh \
  "$task_r2_source"
```

`--checksum` 按内容判断是否需要传输，避免重新导出同一输出后因时间戳变化重复上传。
数据先于索引发布，下载设备才能在看到索引时找到完整数据；脚本的 `set -e` 会在失败
时退出维护会话，不继续发布索引。上传数据阶段不向桶同步删除操作。
[rclone S3 上传与校验说明](https://rclone.org/s3/#multipart-uploads)

确认两次 copy 成功、check 无差异、Nix 签名验证通过后，本批上传完成。
`--no-contents` 只检查 Nix 信任关系；需要通过 Nix 下载并验证 NAR 内容哈希时，
去掉它，可能产生整批数据的下载流量。
[Nix 验证说明](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-store-verify.html)

上传中断时，暂存目录仍保留。重新进入维护会话，将 `task_r2_stage` 设置为之前打印的
目录，重新运行两次 copy 和校验即可；已完整上传且内容相同的对象会跳过，未完成的
对象会重新上传，不要求重新构建。验证完成后可手动删除本批暂存目录；R2 中的副本
和 `/nix/store` 中的原输出不受影响。此前字体上传使用的目录是
`~/.cache/nix-r2-upload`，也可以在上传成功后删除。

退出维护会话并清理临时凭据：

```bash
exit
```

## 凭据、收件人与签名密钥维护

R2 凭据格式为下面的 INI；将占位符替换成实际值，字段值不要加引号。

```ini
[r2-cache]
aws_access_key_id = ACCESS_KEY_ID
aws_secret_access_key = SECRET_ACCESS_KEY
```

当前 R2 的 Access Key ID 是 32 位十六进制，Secret Access Key 是 64 位十六进制。
使用 R2 为 S3 API 生成的这对凭据；编辑加密文件时从仓库根目录运行：

```bash
ragenix --rules secrets/secrets.nix \
  --edit secrets/r2-cache-credentials.age \
  --identity ~/.ssh/id_ed25519
```

轮换 R2 凭据时，在 Cloudflare 新建限制到 `nix-cache` 桶的 Object Read & Write 凭据，
更新上述密文并同步各设备。各设备构建、部署并重启后确认可读，再撤销旧凭据。
若旧凭据已泄露，应立即撤销，然后处理设备更新。
[Cloudflare R2 凭据说明](https://developers.cloudflare.com/r2/api/tokens/)

增加设备或更换 SSH 解密密钥时，更新 `secrets/keys.nix` 和收件人规则，然后执行：

```bash
ragenix --rules secrets/secrets.nix --rekey --identity ~/.ssh/id_ed25519
```

这个命令会按规则重新加密所有 secrets；执行设备需要能解密这些文件。检查 `jj diff`
并同步密文，再在目标设备部署对应私钥路径。

签名私钥需要单独加密备份；上传设备更换时安全迁移它，目录权限保持 `0700`、私钥
保持 `0600`。下载设备只需要共享模块中的公钥和能解密 R2 凭据的身份。
已有缓存时不要重新生成并覆盖签名密钥，否则新公钥无法验证原签名。

确需轮换签名密钥时，先让所有设备同时信任旧、新公钥，再用新私钥在新的暂存目录中
重新导出需要保留的输出并上传索引；全部迁移、验证完成后再移除旧公钥。
尚未重新签名的旧索引仍需要旧公钥。修改共享模块后检查求值并构建受影响主机。

## 用量、未完成上传与旧包清理

在维护会话中查看对象和存储量：

```bash
rclone lsf :s3:nix-cache --max-depth 1
rclone size :s3:nix-cache
rclone backend list-multipart-uploads :s3:nix-cache
```

中断的分片上传可能在桶中留下临时数据。确认没有需要保留的、超过 24 小时的上传任务
后，可以先预览，再清理这些未完成上传：

```bash
rclone backend cleanup :s3:nix-cache -o max-age=24h --dry-run
rclone backend cleanup :s3:nix-cache -o max-age=24h
```

这项 cleanup 处理未完成的分片，不删除已完整上传的缓存对象。
[rclone 清理说明](https://rclone.org/s3/#cleanup)
R2 默认提供发起 7 天后终止未完成分片上传的生命周期规则，可在桶设置中检查是否保留。
[Cloudflare 生命周期说明](https://developers.cloudflare.com/r2/buckets/object-lifecycles/)

R2 作为普通对象存储，没有 Nix 引用关系的垃圾回收。设备本地执行 Nix GC 不会删除
R2 对象，也无法据此判断其他设备是否还需要某个缓存。少量字体缓存可直接保留旧版本。
确需删除旧包时：

1. 确认该输出及其依赖已不再需要用于其他设备、当前配置或旧配置回滚。
2. 从旧 `.narinfo` 记录 `URL` 和 `References`，先删除已确认不用的索引。
3. 数据文件可能被其他索引共享，确认其 `URL` 没有被保留索引引用后再删除对应 NAR。
4. 依赖索引可能被保留输出的 `References` 引用，按引用关系决定是否继续清理依赖。

保留桶根目录的 `nix-cache-info`。上传单批缓存使用 `rclone copy`；不要用单批暂存目录
执行 `rclone sync`，否则会删除桶中不属于这一批的其他对象。避免为 `nar/` 单独设置
按年龄自动删除的规则，以免留下指向缺失数据的索引。

## 常见排查

先确认当前设备已应用配置，以及 daemon 能找到解密文件：

```bash
nix config show | rg '^(substituters|trusted-public-keys) ='
systemctl show nix-daemon.service --property=Environment --value \
  | tr ' ' '\n' | rg '^AWS_SHARED_CREDENTIALS_FILE='
sudo stat /run/agenix/r2-cache-credentials
journalctl -u nix-daemon.service -n 50 --no-pager
```

| 情况 | 检查方式 |
| --- | --- |
| TLS handshake failure | 核对 endpoint 的账号 ID，正确值是上面的完整 32 位字符串；曾因漏掉一个 `d` 导致握手失败 |
| HTTP 400，Access Key 长度不符 | 用 ragenix 编辑 INI，检查是否误加引号、复制了空格或用错凭据 |
| 403 或无法解密 | 检查桶权限、profile、凭据是否失效、SSH 私钥是否对应密文收件人；Object 级凭据需要 `no_check_bucket=true` |
| 数据传了，Nix 仍不命中 | 两次 copy 都需成功，检查 `.narinfo` 是否已发布；按上面 verify 命令临时设置负缓存 TTL 为 0 并刷新 |
| signature 不可信 | 检查上传签名私钥是否对应共享模块中受信任的公钥，以及当前设备是否部署了公钥配置 |
| 改了字体包却没有命中旧缓存 | 对比实际 store 路径；锁文件、平台或构建输入变化可能产生新输出，需要另行构建并上传 |
| 本机 build 没显示下载 | 已有输出会直接复用本地 store；不要为测试下载而删除仍被当前系统引用的字体 |
| 上传进度有字节但文件数仍是 `0/1` | 文件尚未完整上传、提交；等命令成功结束，并用 check 确认，未完成分片不等于可用对象 |
| 原生 Nix 上传慢 | 本次实测 rclone 并发分片更快，优先用本文流程；速度差异不能单凭截图归因于代理或 IPv6 |

维护文档只记录手动操作；没有部署 post-build-hook、自动上传服务或 R2 对象删除规则。
