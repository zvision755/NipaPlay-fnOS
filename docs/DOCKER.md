# OrbStack Docker 运行

源码：NipaPlay v1.11.9，现有 `fnos/web-port-v1.11.9` 分支。生产和开发使用同一个 `server/fnos/main.dart`，直接挂载原 `WebApiService`，没有独立账号、弹幕或媒体库系统。

## 首次构建

在项目根目录执行：

```sh
scripts/prepare_fnos_sdk.sh
PUB_CACHE="$PWD/.porting/pub-cache" .porting/tools/flutter/bin/flutter pub get --enforce-lockfile
scripts/prepare_fnos_dependencies.sh
scripts/fnos_compose.sh build
```

Flutter 固定 3.44.6 的 revision，Dart 3.12.2；Rust 固定 1.93.0；基础镜像固定多架构 manifest digest。Flutter Linux 引擎从 `storage.flutter-io.cn` 镜像下载，TLS 校验保留。使用官方 SDK 的公开源码快照与本项目的公开 Pub 缓存，解决容器 Git HTTPS 下载失败；Docker 不复制整个 `.porting`。Pub 离线解析严格检查 `pubspec.lock`；Rust `cargo build --locked` 和扫描测试在构建阶段执行。

`healthz` 返回构建时 Git HEAD 和工作区摘要，未提交适配修改不能被表述为上游 tag 本身。当前镜像由未提交工作区构建；发布前需要确认 Git 作者身份、提交适配改动，再从该确定提交构建。摘要不会让变化中的工作区自动变成可重现版本。基础 apt 仓库未固定快照，因此目前不保证字节级镜像一致。

## 数据与启动

现有数据卷 `nipaplay-fnos-data` 已初始化；不要再次覆盖。服务器凭据位于 `/data/private/preferences.json`（0600），SQLite、弹幕缓存、字幕提取和视频转换缓存均在 `/data`。必须通过 `NIPAPLAY_MEDIA_DIR` 设置宿主机视频目录；容器内统一映射到 `/media/anime` 并只读挂载。

```sh
scripts/fnos_compose.sh up -d
scripts/fnos_compose.sh ps
scripts/fnos_compose.sh logs --tail 100 app
scripts/fnos_compose.sh restart app
```

页面：`http://127.0.0.1:1182/`。健康检查：`http://127.0.0.1:1182/healthz`。不要以 `file://.../web/index.html` 打开源码入口。

新安装可先创建空数据卷，使用 UID/GID 10001 初始化卷目录所有权，然后启动。旧 macOS 数据迁移工具是 `tool/fnos/snapshot_data.dart`，三个参数分别是原数据目录、新快照目录、原媒体目录。它拒绝覆盖已有目标，SQLite 使用 `.backup`，复制数据后将路径映射为容器路径。快照含凭据，必须留在忽略目录，不可提交或当作镜像输入。已有迁移快照在 `.porting/docker-seed`；原数据目录完整保留。

更换媒体目录可设置 `NIPAPLAY_MEDIA_DIR`；端口可设置 `NIPAPLAY_HTTP_PORT`。两者在 Compose 启动时生效。默认只绑定 macOS 回环；尚未实现面向多用户 NAS 暴露的访问控制。

## Windows Docker 与 Jellyfin 联调

Windows 使用 Docker Desktop 的 Linux 容器模式。克隆仓库后，在 PowerShell 项目根目录运行一次准备脚本。它初始化 pubspec 需要的 media-kit 子模块，并在 Git 忽略的 `.porting` 下下载固定 Flutter 3.44.6 源码与 Pub 缓存，不把媒体或服务器凭据复制进构建上下文，也不需要在 Windows 安装完整 Android Studio。

```powershell
.\scripts\prepare_fnos_windows.ps1
$env:NIPAPLAY_MEDIA_DIR = 'D:\Media\Anime'
docker volume create nipaplay-fnos-data
docker compose build
docker compose up -d
```

将 `D:\Media\Anime` 换成 Windows 上实际媒体目录。浏览器访问 `http://127.0.0.1:1182/`，本机目录在 NipaPlay 的“添加本地文件夹”中填写 `/media/anime`。重新部署时保留 Docker 数据卷；Docker Desktop 若提示共享/授权媒体盘，在 Docker Desktop 设置中开放对应盘符。

Windows Jellyfin 应使用该电脑在局域网内可达的 IPv4 地址和端口，例如 `http://192.168.1.20:8096`。不要填 `localhost`/`127.0.0.1`：NipaPlay 的连接校验在 Linux 容器内执行，这两个地址会指向 NipaPlay 容器本身。确认 Windows 防火墙允许该端口，并让浏览器所在电脑能够访问同一 Jellyfin 地址。若连接校验成功但媒体列表无法加载，检查 Jellyfin 的浏览器跨域设置是否允许 NipaPlay 页面来源 `http://127.0.0.1:1182`；具体设置名称随 Jellyfin 版本而异。

可先从容器侧检查 Jellyfin 网络连通性（把地址改为自己的 Windows 局域网 IP）：

```powershell
docker exec nipaplay-fnos-app-1 curl -fsS http://192.168.1.20:8096/System/Info/Public
```

账号密码仅在 NipaPlay 页面中的 Jellyfin 登录框输入，不要贴到聊天或命令行。Mac OrbStack 的本机挂载配置不会随 Git 仓库传播；Windows 脚本与这段 PowerShell 流程会生成该机自己的 Docker 构建上下文。

## 开发模式

```sh
scripts/fnos_compose.sh --dev build
scripts/fnos_compose.sh --dev up -d
scripts/fnos_dev_web.sh
```

访问 `http://127.0.0.1:1183/?api=http%3A%2F%2F127.0.0.1%3A1182`。1183 是本机 Flutter 开发服务器，1182 是容器 API。`api` 参数显式选定同一个后端。CORS 只允许本机这两个开发 origin。

开发容器只读挂载 `lib/` 和 `server/`，启动时编译内核到 `/tmp`；后端改动后重启本项目 app 服务即可。前端改动由 Flutter 重新编译，无需重新构建 Docker 镜像。新依赖或原生组件改动需要重建镜像。生产与开发互斥占用本项目同一个 app 服务和数据卷，避免两个进程并行写库。

本轮 Flutter machine 的 hot.reload 请求完成，但输出 `No client connected`；web-server 模式下保状态热重载尚未验证。已验证重新编译后刷新加载，不能宣传为完整热重载。需要 Dart Debug 扩展或专门调试客户端时应另行验证，默认验收浏览器使用 Codex 内置浏览器，不占用用户 Chrome。

恢复生产模拟：

```sh
scripts/fnos_compose.sh up -d
```

## 平台与边界

本轮实际验证 `linux/arm64`。基础 Debian/Rust 镜像及 Flutter Linux 引擎同时提供 amd64；尚未构建或运行 amd64，不把 ARM64 成功当成目标 NAS 成功。可使用 Buildx 的 `--platform linux/amd64`、两个命名 context（flutter_source 和 pub_dependencies）和同一个 Dockerfile 做独立构建。多平台并行构建前应给 Cargo target 缓存按架构隔离。

服务仍使用 Flutter 无界面引擎的 `flutter_tester` 可执行文件加载独立 main；没有 flutter_test 导入、runApp、Xvfb、VNC 或桌面会话。它是过渡运行方案，不是纯 Dart 原生服务器。原 WebServerService 的播放器远程控制依赖桌面状态；本入口返回 501，不伪装为可控制 NAS GUI 播放器。Web 播放、文件访问、原数据库和账号 API 则复用原业务服务。

FFmpeg 是服务端转封装/转换工具；图形相关共享库可能作为成熟包的依赖存在，但不启动显示服务器。当前 CPU 转换、没有 GPU 加速验收。许可证/字体独立授权及上游服务授权审计尚未完成，不能据此直接发布 FPK。
