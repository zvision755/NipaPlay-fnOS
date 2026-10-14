# NipaPlay v1.11.9 → fnOS Web 移植审计报告

更新日期：2026-10-15。源码基线：`v1.11.9` / `c26e1f9947e3091b400b07ec2d5558a617bb38ad`。下列源码位置均相对于本项目；行号以该 tag 为依据。报告区分实际执行结果、静态证据和后续建议。

## 2026-10-15 当前交付状态

- 用户确认 Mac 本地文件夹媒体库测试通过。OrbStack linux/arm64 Docker 版已真实播放 AVI、加载弹幕与 ASS 特效；Windows Docker Desktop / linux/amd64 与 Windows 上的 Jellyfin 尚未实际测试。
- Windows Docker 准备脚本和 PowerShell 流程已加入仓库；本地目录通过 `NIPAPLAY_MEDIA_DIR` 映射为容器 `/media/anime`。Windows 详细步骤见 `docs/DOCKER.md` 中的“Windows Docker 与 Jellyfin 联调”。
- Jellyfin Web 配置校验在容器执行，Web 播放器也会直接请求 Jellyfin；Windows Jellyfin 应填写双方都可访问的局域网 IP 和端口。CORS、防火墙及真实服务器登录需在 Windows 实机验收。
- 已按用户授权创建公开 fork [zvision755/NipaPlay-fnOS](https://github.com/zvision755/NipaPlay-fnOS)，描述和 README 标明上游 AimesSoft/NipaPlay-Reload v1.11.9。适配提交 `4992a8c2fa3c498b7082a505b64d689910eb415c` 保留原 tag 为父提交，Author/Committer 均为已确认身份 `Ziwei Zhao <199458887+zvision755@users.noreply.github.com>`。
- 适配分支已上传：[fnos/web-port-v1.11.9](https://github.com/zvision755/NipaPlay-fnOS/tree/fnos/web-port-v1.11.9)。2026-10-15 用户 HTTPS/PAT 推送输出 `curl 18 transfer closed with outstanding read data remaining`，但随后独立 `git ls-remote` 确认远端提交为 `d4cae817c5c4b051ff5a2f7733b188afcd0fa8e1`，与本地 HEAD 一致；实际成功，断开的是回执。早期 OAuth 的 `workflow` scope 拒绝与 SSH 连接关闭保留为历史诊断，SSH 网络根因未确认。Windows 可执行：`git clone --branch fnos/web-port-v1.11.9 https://github.com/zvision755/NipaPlay-fnOS.git`。

## 结论与本轮边界

### 上次实测更新（2026-10-14）

登录准备更新：1181 曾因 30 分钟测试时限自动结束（原日志保留），恢复服务后浏览器同源探测可直接进入首页，不需要填写另一台设备的地址。测试 host 已取消自动超时。SharedPreferences 已由 `ServerPreferencesStore` 桥接为项目内持久化文件，服务器启动读取，写入排队且原子替换，0700 私有目录/0600 文件；单写入进程、未加密静态存储，后续生产部署需评估秘密存储。浏览器 Web 分支不再保存账号 Token。Bangumi 保存/退出通过新增 Shelf 接口复用 `BangumiApiService`，不重新设计账号系统；状态接口只返回状态/用户资料。用户密码只用于登录请求，未添加密码持久化。开发 host 输出不落日志，上游 WebToken 响应/URL 原文诊断已移除。测试证据：`server-preferences-regression.log` 1 项通过、`web-account-api-regression.log` 2 项通过、`web-account-regression.log` 11 项通过、`web-server-account-final-build.log` 构建/复制校验通过；`web-account-analyze.log` 没有编译错误。真实账号仍未由用户授权验证，因此不宣布登录及同步功能通过。第三方 API 对衍生应用的授权问题仍未解决，不能把本机原版验证当作公开发布凭据授权。

首次加载目录后立刻添加时发现上游 ScanService 异步加载覆盖新目录列表的竞态；已让添加和 API 目录查询等待加载 Future，沿用原扫描服务。账号授权前已恢复用户指定根目录，没有修改视频或字幕。

以下更新覆盖报告后文的早期 gate-only 状态：已通过隔离的 Flutter test engine 加载**原版完整 WebApiService**，Shelf 在 `127.0.0.1:1181` 提供业务 API 和 build/web。它是有限时长的开发验证入口，使用测试内存 SharedPreferences 和项目内真实 SQLite/缓存；不是已完成的生产无 GUI 后端。

- 原版首页、共享管理、文件夹浏览已实际进入；`registered-media-roots.json` 证实仅登记用户指定的一个根目录。展开目录没有新增媒体根。原界面把子目录扁平放成卡片，已改 Web 使用已有 `LibraryManagementFolderRow` / `_buildRemoteDirectoryChildren`，实际浏览器展开/收起复核通过，截图 browser-library-tree.png。修复后 registered-media-roots-after-tree.json 仍为一个根目录。
- MKV 样本 HEVC 10-bit/AAC 在本机 Chrome 直接播放及跳转成功。仅说明该机器/浏览器支持，不能推广到所有 NAS 用户浏览器。样本的内封 SRT 简体、繁体已从原文件提取并通过原 `SubtitleParser` 与 `ExternalSubtitleOverlay` 显示；实际执行开启、关闭、重新开启。截图 `browser-mkv-subtitle-on.png`、`browser-mkv-subtitle-off.png`、`browser-mkv-subtitle-reopened.png`。
- AVI MPEG-4 Part 2/AC3 原流报 `MEDIA_ERR_SRC_NOT_SUPPORTED`。最小服务端兼容适配将其生成 H.264/AAC MP4 缓存，再用原播放器播放，原文件只读。实际时长 1465.507 秒、704×528、readyState=4。首次转换需等待，缓存容量管理及生产任务调度尚未实现。
- AVI 外挂 UTF-16 LE ASS 经原解码/解析流程获得 376 条；内封 SRT 326 条。AVI 已在同一 00:48 暂停画面执行开启、关闭和重开，字幕语义出现/消失/恢复，截图 `browser-avi-subtitle-on.png`、`browser-avi-subtitle-off.png`。**ASS 当前只显示文字/时间，不保留 karaoke、变色、动画和完整排版，不能认定完整 ASS 支持。**
- 新增 Web 字幕轨道入口及真实 API，自动选择 `.default.`/简体/首轨的适配已构建，AVI 从库内重新打开自动出现片头字幕，截图 browser-avi-subtitle-auto.png；MKV 自动选择尚未单独复核。原生字幕选择保持原流程。需继续补充其他媒体源的字幕地址映射。
- Range/HEAD 修复通过 5 项回归，原字幕缓存开关测试 1 项通过。日志 `web-subtitle-regression.log`；实际 API、媒体字节验证、ffprobe 与编译日志保存在 `.porting/logs/`。`web-subtitle-build.log` 为已成功的阶段构建；最终树形界面包装构建及复制校验通过，见 web-subtitle-tree-final-build.log。
- Rust 扫描组件未构建，真实自动扫描因此仍失败；未伪造番剧匹配数据。原扫描还限制 mp4/mkv，AVI 需后续兼容。首页继续观看仍把物理本地路径传入 Web 播放器，已有失败证据，待修复。
- 弹幕搜索/整季保存、实际弹幕渲染及两个账号登录仍未端到端验证；无需为字幕测试登录。Jellyfin/飞牛影视按用户说明暂不测试。未请求用户密码/Token。

ASS 下一步候选是 [JASSUB](https://github.com/ThaUnknown/jassub)，项目说明其以 WebAssembly libass 在 HTML5 video 上渲染 ASS。原生内核同样使用 libass（`media_kit_player_adapter.dart`、`subtitle_manager.dart`）。这属于替换 Web 缺失的字幕渲染桥，不是重写播放器。尚未引入或验证，必须先检查其 worker/WASM、字体、视频与 Flutter 层级、许可及远程网关头要求，再验证片头特效，不能仅凭项目说明宣布兼容。

**原版完整 Flutter 应用能够编译为 JavaScript Web 产物，无需改动业务源码。Chrome 已实际加载原版远程访问连接界面。它目前不是可独立使用的 NAS Web 应用：需要可运行的 NipaPlay API 后端，浏览器才会进入主界面。**

没有重新实现播放器、媒体库、弹幕或账号系统，没有屏蔽核心功能来通过编译。本轮增加构建结果校验脚本和审计文档。没有部署 NAS、制作 FPK、创建 Git 提交或推送。

首选后续架构是原版 Flutter Web + 从现有 Shelf/业务模块解耦出的 Dart 服务端 + 原有统一媒体库数据 + 按需媒体转封装/转码。这个架构是源码审计后的建议，尚不是已经验证可部署的实现。直接用普通 Dart VM 启动现有服务的探针失败，需要先解决依赖边界。

## 1. 基线、环境与可复现构建

保留 upstream 和非浅 Git 历史，开发分支 `fnos/web-port-v1.11.9`。网络多次中断，最终以部分克隆保留所有历史，官方 tag 归档补齐当前版本；逐个验证 4,852 个 blob，包括符号链接，与 tag 对象哈希一致。历史其他版本的 blob 仍会按需从 upstream 下载。证据：`.porting/logs/archive-verification.log`。

本机 arm64，Git/Command Line Tools/OrbStack 可用。没有找到既有 Flutter/Dart 或 Rust/Cargo。按上游 `.github/actions/setup-flutter/action.yml:9` 的版本要求，在 `.porting/tools/flutter` 隔离 Flutter 3.44.6 / Dart 3.12.2；`pubspec.lock:2039` 的实际 SDK 约束比 `pubspec.yaml` 的最低声明更严格，不能只按 Dart 3.5.3 安装。Pub 缓存在 `.porting/pub-cache`，没有升级业务依赖或改变锁文件。

Web 所需 media-kit 子模块固定为 `7a2135661ff37a717f11d6012fefa56cae27ef36`，其余原生编译子模块未初始化。没有为了 Web 安装 Rust 或桌面 IDE。

| 实际执行 | 结果 | 证据 |
| --- | --- | --- |
| 原版 `build_and_copy_web.sh` 第一次 | Flutter patched SDK 下载中途断开；脚本退出 0，但三个必需产物全部缺失 | `.porting/logs/web-build-baseline.log`、`web-build-baseline-status.txt` |
| 官方 Web SDK 下载重试 | 仍发生连接中断 | `.porting/logs/flutter-web-precache.log` |
| 项目内使用 Flutter 中国存储镜像预缓存 | 成功补齐 Web/host SDK；仅命令环境指定镜像，没有全局网络配置修改 | `.porting/logs/flutter-web-precache-mirror.log` |
| `flutter pub get --enforce-lockfile` | 成功；原锁文件保留 | `.porting/logs/pub-get-baseline.log` |
| 校验包装脚本再次运行原版流程 | 成功，构建与复制完成，必需产物存在且为本次生成 | `.porting/logs/web-build-verified-retry.log`、`web-build-verified-retry-status.txt` |
| `flutter build web --no-pub` | 成功，日志显示 `✓ Built build/web` | `.porting/logs/web-compile-no-pub.log`、`web-compile-no-pub-status.txt` |
| 最终单次原版流程与修正版包装检查 | 退出 0，build/web 与 assets/web 各约 79 MiB，三个入口文件逐个 SHA-256 一致 | `.porting/logs/web-build-final-verified.log`、`web-build-final-verified-status.txt`、`final-web-sha256.txt` |

上游脚本 `build_and_copy_web.sh:25` 把失败改成 WARNING 并继续，是桌面构建容错策略，不能用于判定 Web 成功。新增 `scripts/build_fnos_web.sh` 保留其流程，先将旧 build/web 隔离到 `.porting/previous-web-*`，检查警告、必需文件及与复制目录的一致性。`bash -n` 已通过。最初采用 mtime 检查，单次复核发现 Flutter 缓存恢复保留旧时间戳而误拒绝，已改为隔离旧目录；该失败与修正分别记录在 `web-build-final.log` 和 `web-build-final-verified.log`，未掩盖失败。

编译日志的 Wasm dry-run 警告涉及 `universal_html` 的 `dart:html`、video_player_web、permission_handler_html、flutter_rust_bridge 的 JS interop 类型检查。**本轮成功的是普通 JavaScript Web，未验证 Wasm 构建。** 无需为了 Wasm 预检警告改写应用。

## 2. Web 原有能力与边界

- `web/index.html`、`web/manifest.json` 是 Flutter 客户端入口；`lib/main.dart:1163` 仍进入原版主题/UI，并使用 `WebRemoteAccessGate`。
- `lib/themes/nipaplay/widgets/web_remote_access_gate.dart:90` 在启动时解析后端、探测并挂载共享媒体库；只有探测成功才展示 child。关闭按钮的 `onClose` 是空操作，不是离线入口（约第 200 行）。
- `lib/services/web_remote_access_service.dart:44` 支持 `api` / `apiBase` / `baseUrl` 查询参数、已保存地址、同源自动发现。`probe:117` 要求 `/api/info` JSON 中 `app == NipaPlay`，不是任意 200。
- `proxyUri:163` 将跨源 HTTP 请求送到 `/api/web_proxy`；`imageProxyUrl` 支持本地路径/网络图像代理。
- `lib/services/web_server_service.dart:48` 查找 `assets/web` 及桌面打包资源目录；提供 SPA fallback、远程 service worker 处理、同源 API 参数注入。约第 373 行挂载 `/api`，约第 400 行加入 CORS，监听默认 1180。
- `docs/WEB_SERVER_IMPLEMENTATION.md` 是设计/实施文档，不是每项接口已实现的证据。当前实际路由以 `lib/services/web_api_service.dart:35` 为准。
- `dandanplay_service.dart`、MDK adapter、SMB2 native service、字幕 native parser、JS runtime、Rust 初始化等已有条件导入/回退。编译实际通过，说明不能仅依据出现 `dart:io`/FFI 文本就宣布 Web 不可编译；运行时仍要逐路径检查。

本轮浏览器测试没有伪造 `/api/info`、绕过 gate 或替换空壳首页。静态资源服务器只提供真实 `build/web`。

## 3. 统一媒体库：必须继续复用

| 原有模块 | 真实实现与复用方向 |
| --- | --- |
| 统一 UI 分区 | `lib/app/unified_media_library_sections.dart:5` 统一 local/WebDAV/SMB/shared/Dandanplay/Jellyfin/Emby 分区；`lib/media_library/adaptive_media_library_page.dart:218` 计算 Web 与原生可用性 |
| 统一展示/管理组件 | `adaptive_media_library_controls.dart:404` 将分区路由到原有 collection、LibraryManagementTab、SharedRemoteLibraryView、NetworkMediaLibraryView，继续保留此统一入口 |
| 数据与观看历史 | `lib/models/watch_history_model.dart`、`watch_history_database.dart:51`；SQLite `watch_history.db` v2，保存 anime_id、episode_id、media_key、进度、缩略图与扫描状态。并非需要另造一个“番剧库” |
| 稳定媒体身份 | `lib/models/media_identity.dart:7`、`lib/utils/media_identity_resolver.dart` 为不同来源提供稳定键；应保留以免复制媒体源后丢进度 |
| 浏览器历史 | WatchHistoryDatabase 使用 SharedPreferences Web store；`watch_history_provider.dart:102` 从后端 `/api/history` 读取。浏览器缓存不是 NAS 权威 SQLite 的替代品 |
| NAS 本地目录浏览/管理 | `local_media_management_api.dart:44` 有 folders、browse、stream、subtitles、scan/status、scan/rescan；`SharedRemoteLibraryProvider` 和 `SharedRemoteLibraryView` 已有对应 UI/请求 |
| 本地番剧共享 | `local_media_share_api.dart:10` 有番剧详情、剧集流、字幕、外挂音轨、字体、观看进度；`local_media_share_service.dart` 根据原历史数据组装番剧，不是第二套数据库 |
| SMB/WebDAV | 原服务负责连接、目录与扫描，Web 管理 API 复用它们。SMB 不能由浏览器直接建立 TCP 会话；在 NAS 后端执行即可 |
| Jellyfin/Emby | 原 Provider/Service/NetworkMediaLibraryView 及播放身份/历史同步继续复用；`media_server_transport.dart:8` 已隔离 Web 与 IO client，并处理浏览器禁止自定义 User-Agent 的情况 |

Web 不暴露客户端机器的本地媒体分区：`shouldExposeLocalMediaLibrary:77` 返回 `!isWeb && !isTelevision`。NAS 文件夹应通过现有共享管理/浏览 API 接入，继续使用原统一库，不要直接把条件改成 true 后在浏览器调用 File/Directory。

## 4. 手动/批量弹幕匹配

`lib/services/danmaku_matching_service.dart:8` 是共享业务入口，统一访问权限、精确匹配、番剧搜索、剧集列表、弹幕下载与发送。应保留此入口及既有鉴权策略。

`lib/themes/nipaplay/widgets/batch_danmaku_dialog.dart:240` 搜索，约第 283 行选番剧并加载剧集，约第 363 行排序，`_confirmAndClose:410` 将左右两栏选择映射为 `{animeId, animeTitle, mappings:[filePath, fileName, episodeId, episodeTitle, episodeNumber]}`。其交互和匹配算法无需重写。

`library_management_tab.dart:4309` 消费结果，读取原观看历史、保留已看进度、迁移已解除匹配的旧记录，写入 `WatchHistoryManager.addOrUpdateHistory`，并刷新统一 Provider。这段保存逻辑也应抽成可共享的业务方法。

**现存 Web 缺口：** Web 的共享管理分区路由到 `SharedRemoteLibraryView`，不是原本地 LibraryManagementTab；该共享 view 未引入双栏对话框。`local_media_management_api.dart:44` 的实际路由也没有手动 mappings 保存接口。自动 scan 不等于手动批量匹配。因此不能声称此功能现已在浏览器正常运行。

最小方案：在原共享管理页复用 BatchDanmakuMatchDialog；由后端返回当前文件夹的候选文件（原 browse），将 mappings POST 到新增小型接口，服务端调用抽出的原保存逻辑，校验文件属于授权媒体根目录，最后刷新原共享库。保留进度处理、原字段和匹配策略，不创建新库。

Web 条件导入实际选择 `dandanplay_service_stub.dart`，该文件是具有完整 HTTP 代理实现的 Web 服务，不是空 stub。`matchVideo:552`、`getVideoInfo`、`getDanmaku:1256` 已有后端路径；搜索/剧集可经通用代理。IO 端复用磁盘/内存弹幕缓存（`danmaku_cache_manager.dart`），Web 侧不应尝试读 NAS 磁盘缓存。

## 5. 账号、网关与授权

**弹弹play：** `web_api_service.dart:62` 提供 login_status/login/logout/refresh_login、Bangumi OAuth 登录、webtoken、观看历史、收藏、发送弹幕等代理。Web stub 初始化会同步后端状态。`dandanplay_http_client.dart:59` 对官方网关要求登录，并控制 Token 的接收目标；后端可注入自身账号 Token，浏览器不必取得后端的弹弹play Token。不能通过移植取消登录要求。

**服务权限：** IO 与 Web 的 `getAppSecret` 均返回 `server-managed` 占位符，不是可独立使用的官方 AppSecret。`server/dandanplay-gateway/README.md:3` 明确网关保管实际 Secret，并要求有效 Bearer Token；除了 login/register，其上游 search/comments/metadata 等也需要登录。MIT 源码许可不能据此推导独立 fnOS 衍生应用获准使用 NipaPlay 官方网关、appId 或弹弹play应用授权。需要获得相应授权或注册独立应用，并配置受控服务端网关；没有复制、探测或索取原官方服务端 Secret。

**Bangumi：** `bangumi_api_service.dart:74` Web 启动后轮询后端 `/api/bangumi/login_status`（约第 120 行）；`saveAccessToken:229` 则验证 `/v0/me` 并保存到当前客户端 SharedPreferences。账号页面 `account_controller.dart:358` 调用该 Token 路径。现有 Shelf 只提供 Bangumi 登录状态查询，没有对应的直接 Token 保存/注销接口；浏览器新保存的 Token 不会自动写入 NAS 状态，并可能被后端轮询状态覆盖。这是静态发现，尚未经真实授权复现。

弹弹play的 Bangumi OAuth 绑定/网页登录能力与直接 Bangumi API Token 登录是两条不同路径，不能混称为同一个完整 OAuth 实现。NAS 端建议复用现有业务验证和同步模块，增加正确的后端账号存储入口，完成浏览器、NAS、刷新/注销的一致性。真实账号仅由用户在应用页面授权，不要求聊天中提供密码或 Token。

## 6. 播放、字幕与弹幕

`player_factory.dart:88` 在 Web 强制 VideoPlayer；Chrome 实际运行日志也确认了此选择。不能把 MDK、Erika、libmpv 的原生解码/ASS 支持能力当成 Web VideoPlayer 的能力。

| 能力 | 源码/资料结论 | 尚需实际验证 |
| --- | --- | --- |
| H.264/AAC MP4 | 常用兼容基线；沿用 VideoPlayer | 本机及目标客户端真实播放、音轨与拖动 |
| HEVC | 取决于浏览器/OS/设备/编码 profile，不能保证全平台 | capability 检测与真实 Main/Main10 样本 |
| AV1 | 浏览器及硬件支持需要分别判断，不能仅凭扩展名推断 | MP4/WebM 样本、软解性能与硬解 |
| MKV | 原分享服务返回 video/x-matroska 并原样流式传输；没有本地分享转码层。不能承诺所有浏览器直放 | 容器、音轨、编码联合测试，必要时转封装 |
| HTTP Range | `local_media_share_service.dart:411` 和 management stream 有 bytes range、206/416、HEAD | suffix range/multiple range/end<start 等边界以及代理穿透 |
| ASS/SSA/SRT | 原 Dart 文本解析和 ExternalSubtitleOverlay 可复用；NativeSubtitleParser Web 回退返回 null | 远程字节加载、时间同步、多字幕与字体 |
| 完整 ASS 特效 | `subtitle_manager.dart:937` Web 不使用原生字幕轨；libass 原生能力不直接迁移。普通文本解析不等于完整排版/卡拉 OK | 后续可评估 libass WASM 或选择性烧录；先验证原文本 fallback |
| 自动查找同名字幕 | `subtitle_manager.dart:1361` 在 Web 明确跳过本地文件自动检测 | 复用已有共享 subtitles 接口实现 NAS 侧检测/加载 |
| 内嵌字幕 | VideoPlayer 的 mediaInfo.subtitle 是空列表；不能据此承诺 MKV 内嵌字幕可直接选择 | 后端抽取轨道并复用字幕 UI |
| 弹幕叠加 | `danmaku_kernel_factory.dart:36` 已说明 Web 回退 NipaPlay Next，保留原 Flutter 渲染层 | 实际播放下弹幕覆盖、seek、全屏和性能 |

Range 的源码已有基础实现，但 `bytes=-N` 当前按 start=0/end=N 解析，不能作为 suffix-range 正确性证据。后续应在真实文件样本下修复和测试这些边界，避免只因响应 206 就认定可正确拖动。

编码资料依据：[MDN video codecs](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Video_codecs)、[MDN container formats](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Containers)。这些是兼容性研究，不能替代本机播放器测试。

建议顺序：原样直放 → 仅容器不兼容时 FFmpeg 转封装 → 仅音轨不兼容时音频转码 → 视频不能解码时才视频转码。继续使用原 AbstractPlayer/UI，将后端输出 URL 交给 Web VideoPlayer；优先不引入新的前端或解码框架。

## 7. 无 GUI 服务端验证与最小解耦

现有 `WebServerService` 不是独立服务包，它经 WebApiService → ServiceProvider 引入 WatchHistoryProvider、ScanService、Jellyfin/Emby Provider 和播放器/控制模块；其中 WatchHistoryProvider 直接导入 `flutter/material.dart`。StorageService 依赖 path_provider 与 SharedPreferences；SQLite 初始化走 Flutter sqflite/FFI；扫描调用 Rust bridge；部分路由是实际桌面遥控，不适合无 GUI 服务。

在 `.porting/headless_probe.dart` 仅导入原 `WebServerService` 并调用 startServer，实际执行：

- `dart compile kernel`：退出 254，Dart FFI transformation 在 `_verifyAndReplaceNativeCallable` 处抛 `InvalidType`/`FunctionType` 编译器异常；`.porting/logs/headless-dart-probe.log`。
- 直接 `dart` 运行：退出 252，同类 compiler crash；`.porting/logs/headless-dart-run.log`。

进一步将探针缩小到仅 `import package:flutter/material.dart` 并打印 Colors.blue，仍得到同类 compiler crash（退出 252，`.porting/logs/headless-flutter-dependency.log`）。这证明**直接普通 Dart 导入 Flutter 依赖没有成功**，不证明所有 Shelf 逻辑不能解耦；异常并非只有原服务图才能触发。没有把它归因到某个 Rust/播放器文件。静态 Flutter UI/插件耦合另有明确源码证据。

最小解耦路线：

1. 分离 Shelf 启动/静态资源服务与桌面发现、遥控、GUI Provider；保留实际媒体、弹幕、账号路由和响应字段。
2. 把媒体记录/身份、批量结果保存、账号状态与持久化逻辑从 UI Provider 抽到共享业务模块；Provider 作为 UI 适配层继续调用它们。
3. 对数据根目录、配置/账号存储、SQLite factory、HTTP client 注入服务端实现；保留原数据库/schema、配置键和迁移语义，不能用仅内存 mock 当持久化结果。
4. 保留 NAS 文件 IO、媒体哈希及 Rust 扫描能力；评估单独复用已有 Rust 扫描模块，避免服务端必须加载 GUI/GPU 渲染初始化。Rust 尚未安装/构建，不能宣布其 linux/arm64 或 x86_64 已可用。
5. 新建薄 Dart server 入口，实际验证扫描→批量 mappings 保存→共享番剧列表→Range 播放→进度写回→重启持久化的闭环。

本轮没有引入 Flask/FastAPI/Node 业务后端，也没有用 Xvfb/VNC 启动 GUI。Ruby 仅用于本机静态产物测试，不属于拟议生产后端。

## 8. fnOS 部署建议（尚未部署）

建议最终维持一个同源 Web/API 服务：原 Flutter 静态资源 + Dart Shelf；权威数据库和账号在 `/data` 持久化，媒体目录以 `/media/<source>` 挂载，缓存单独目录。默认媒体只读，移除库记录与删除媒体文件分开。Jellyfin/Emby 是可选来源，飞牛影视也只能是可选来源，不作为必要数据基础。

不直接沿用 `Dockerfile.arm64`：它是 Ubuntu/GTK/libmpv/MDK 的原生 GUI 构建环境，使用浮动 Flutter stable 和 MDK nightly，并非独立 Web runtime。先让纯 Dart 后端可启动，再采用固定 SDK/依赖的多阶段构建。浏览器静态产物可跨架构复用，Dart AOT executable、Rust 动态库与 FFmpeg 必须分别构建/验证 linux/amd64、linux/arm64。当前本机 Docker 为 linux/arm64，NAS 架构待确认；没有构建生产镜像。

官方资料已获取并保存本地 HTML 证据：

- [应用入口](https://developer.fnnas.com/docs/core-concepts/app-entry/)：`manifest desktop_uidir=ui` 对应 `app/ui/config` 的 `.url` 入口，可使用 url/iframe、protocol/port/path；桌面图标打开原 Flutter 页面即可。
- [manifest](https://developer.fnnas.com/docs/core-concepts/manifest/)：声明实际架构和已测试的系统版本、端口与目录授权，不能凭 macOS 构建结果宣称支持所有 NAS。
- [统一网关](https://developer.fnnas.com/docs/core-concepts/gateway-registration/)：公开路径如 `/app/{appname}`，系统校验会话后转发到应用 Unix Socket，可用于长期服务/API/WebSocket。

统一网关/FN Connect 后续验证要覆盖：Flutter base href、子路径下 API URL、静态资源、Range/长连接、大文件超时、HTTPS 与浏览器 CORS。原后端以 origin 拼 `/api`，Web `apiUri` 也使用根路径，不能假设放在 `/app/nipaplay-fnos` 后直接正常。FN Connect 远程可访问尚未验证。

现有 WebServer 监听 anyIPv4 并加入宽松 CORS、通用 URL 代理和文件路径接口。fnOS 对外部署前，应与真实网关认证衔接并限制授权媒体路径/代理目标，不能把桌面 LAN 服务直接公开到公网。这是由当前代码和目标部署路径产生的具体适配需求。

## 9. 许可证与第三方资产

主项目 `LICENSE`：MIT，Copyright (c) 2025 MCDFsteve，已保留。已为解析出的 260 个 Dart packages 生成逐项许可证文件位置清单：`docs/WEB_PORTING_LICENSE_INVENTORY.tsv`，含 direct dependency 标记、首个非空标题、文件位置和待审查状态。该清单是文件证据索引，不是全部二进制许可审核已完成的声明。

| 组件 | 已检查证据/限制 |
| --- | --- |
| media_kit / media_kit_video / danmaku_canvas | 项目内 LICENSE 为 MIT |
| fvp 包装插件 | `third_party/fvp/LICENSE` 为 BSD-3-Clause；不等同于 MDK SDK 的许可 |
| erika_flutter 0.2.1 | 本地下载 package LICENSE 为 MPL-2.0；原生 Erika/预构建载荷的第三方资产需另审 |
| smb_connect fork | 项目内 LICENSE 为 Apache License；native smb2 绑定/分发仍需分别确认 |
| flutter_rust_bridge | 下载 package LICENSE 为 MIT；不代表 Rust 全依赖都是 MIT |
| video_player / sqflite 等 | 已逐包定位许可证文件，见清单 |
| MDK | [官方 SDK 仓库](https://github.com/wang-bin/mdk-sdk) 有单独使用/商业许可条件；不能从 fvp 的 BSD 推导 MDK 可任意分发。本次 Web 不使用 MDK 播放内核 |
| FFmpeg | [官方许可说明](https://ffmpeg.org/legal.html) 指出配置可引入 GPL 部分；后续选择具体二进制和编码器后检查构建配置/来源/通知，不能只写统一 LGPL |
| Rust | `rust/Cargo.toml` 包含 wgpu、librqbit、reqwest、图像/字体/编码等依赖；尚未取得所有 crate 源码逐项审核，属于明确未完成项 |
| 其他资源 | 字体、图像、第三方预编译播放器、mpv/libplacebo 子模块许可证尚需在最终分发范围确定后补齐 |

没有从零重写核心功能的提案；新增工作应限制在平台适配、后端依赖注入、已有保存逻辑抽取、必要媒体转换与打包边界。

## 10. 实际浏览器状态与待办

本轮通过本机 Chrome 在 `http://127.0.0.1:1181/` 使用原版 Flutter Web UI，并由 `.porting/web_dev_host_test.dart` 启动原 `WebApiService` 与本地静态资源。该 Shelf 测试宿主只监听 loopback，用于开发验证，不是已解耦的生产服务端。

测试媒体来自用户提供的本地番剧目录。实际播放 AVI 第 1 集，验证了本地媒体卡片、播放、外置 ASS 字幕轨道和弹幕叠加。该集两种 ASS 字幕接口返回完整 ASS 文本；服务响应中包含 376 条 Dialogue 和 429 个 karaoke 标签。浏览器手动选择 ASS 轨道后，DOM 中出现 JASSUB `canvas.JASSUB`，OP 卡拉 OK 特效正常渲染。第一次截图中日文是方框；根因是 JASSUB 仅使用 Latin fallback。改为把原字幕声明字体映射到项目已有的 `Droid Sans Fallback`（`assets/subfont.ttf`）之后，日文/中文均正常显示，用户也确认当前页面显示正确。

| 用户要求的功能 | 真实状态 |
| --- | --- |
| 页面渲染 | 本机 Chrome 已加载 Flutter Web 首页与播放器 |
| 本地媒体库 | 用户已确认本地文件夹测试通过；Docker 内填写容器映射路径 `/media/anime` |
| AVI 播放与外挂字幕 | Chrome 中实际播放；手动选择 ASS 轨道后显示日文及中文、卡拉 OK 特效 |
| ASS/SSA 字体回退 | 已接入现有 Droid Sans Fallback；本机 Chrome 与用户当前页面确认不再显示方框 |
| 弹幕 | 该集成功加载并叠加在视频上，用户已确认 |
| 内封 MKV 字幕 | 数据接口保留 ASS 时序与样式；本轮字体回归使用 AVI 外挂 ASS，仍需对 MKV 内封 ASS 做相同的浏览器画面对照 |
| SRT 字幕 | 继续使用原 NipaPlay 文字字幕管理器；本轮未额外回归 |
| 手动批量匹配 | 复用原版双栏匹配 UI；此前已经保存两集到媒体库，SQLite 有映射记录 |
| Bangumi/弹弹play 登录 | 用户已在同源 Web API 登录；无真实凭据被读取或写入源码 |
| Jellyfin/Emby/飞牛影视 | 用户当前没有可测服务器，未连接 |

JASSUB 2.5.20 为第三方 WASM/libass 渲染器，许可证是复合表达式，完整 notice 在 `web/vendor/jassub/NOTICE.md`。NipaPlay 自带字体已有上游 FVP 文档的来源指向，但字体自身的独立许可证文本仍需在 fnOS 发布前补齐；详见 `docs/WEB_PORTING_LICENSE_INVENTORY.tsv`。Flutter 构建成功；Wasm 预检仍报告上游 `universal_html`/插件兼容警告，当前产物是正常 JS Web 构建。


## 11. 上游测试执行

实际运行 `flutter test --no-pub test/danmaku_matching_access_test.dart test/dandanplay_http_client_test.dart test/web_ui_proxy_api_test.dart`，24 项通过，退出 0。覆盖探测路径/超时、原共享匹配入口、匿名访问限制、网关迁移、Token 目标隔离与代理请求头处理。日志：`.porting/logs/upstream-core-tests.log`、`upstream-core-tests-status.txt`。

测试使用原测试中的 mock HTTP/SharedPreferences，没有登录真实账号，也不能作为播放器/媒体库/账号端到端通过的证据。

## 12. OrbStack Docker 验证与后端边界（2026-10-14）

本轮完成 Linux arm64 的原业务后端运行和生产 Web 构建：`server/fnos/main.dart` 使用 Flutter 无界面引擎承载 Shelf，直接挂载 `WebApiService`，原账号/弹幕/SQLite/本地媒体业务保持同一实现。存储注入是 `StorageService.configureServerStorageDirectory` 和已有 `ServerPreferencesStore`；纯 Dart 解耦仍待抽离 Flutter/Provider 依赖。没有 Xvfb、VNC 或桌面会话。Rust 库按原 Cargo 锁构建，补齐 include_bytes 字体，扫描扩展 AVI 并通过原差异/哈希测试。

已复现并修复提示框 Platform API 与默认 ASS 普通字幕路径；整个首页刷新失败未在原 1181 完整复现，不泛称 Docker 修好了所有刷新错误。源码 file:// 入口无构建 bootstrap；远端图片 500、开发空图片导致 ImageCodecException 仍有待修复。浏览器/Web API/缓存诊断和真实结果详见 PROGRESS.md 最新章节及 `.porting/logs/refresh-diagnosis.md`。

生产模式使用 Compose 的同源 Web+API 1182；开发模式 Flutter 1183+同一容器后端、数据卷，源码只读挂载，后端重启重编译，前端无需重建镜像。两模式互斥。正常首次打开/三次刷新/另开标签、本地 2 部5集、真实账号状态、搜索结果、Range 字节对照、AVI 实际播放+2494弹幕+自动ASS特效均有实测证据。容器重建后数据仍在，随后明确的删除文件夹 API 请求使库为空，未擅自恢复旧匹配。没有重启 OrbStack daemon。

卡片新增重新匹配/移除菜单，复用 `BatchDanmakuMatchDialog`、`BatchDanmakuMatchPersistence` 与原 `WatchHistoryManager.removeHistoryByAnimeId`，不是新媒体库。移除不删除文件但会删除观看记录，UI需用户确认；跨媒体源记录拒绝由本地移除入口处理。新测试与原匹配进度测试共3项通过。

完整操作说明在 `docs/DOCKER.md`。Flutter hot.reload 编译完成但 No client connected，保状态热重载未验证；当前仍为未提交适配工作区，构建记录包含 Git HEAD与摘要，发布前需固定适配提交。amd64 只是准备路径，实际编译/运行尚未完成。MKV内封字幕、各编码、Jellyfin/Emby以及fnOS FPK仍需专项验收。许可证/字体授权与上游自有服务使用权限的既有待办继续有效，不能从 Docker 编译成功推断已可公开发布。
