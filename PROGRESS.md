# NipaPlay-fnOS 开发进度

更新日期：2026-10-15（Asia/Shanghai）。源码已提交并上传公开 GitHub fork 的适配分支；未修改真实 NAS。

**GitHub 状态：** 公开 fork [zvision755/NipaPlay-fnOS](https://github.com/zvision755/NipaPlay-fnOS/tree/fnos/web-port-v1.11.9) 已上传适配分支 `fnos/web-port-v1.11.9`。源项目与 v1.11.9 基线已在描述和 README 标明。2026-10-15 用户通过 HTTPS/PAT 推送时收到 `curl 18` 回执断开错误，但随后独立 `git ls-remote` 查询确认远端为 `d4cae817c5c4b051ff5a2f7733b188afcd0fa8e1`，与本地 HEAD 完全一致，证明分支实际已上传。最初适配提交 `4992a8c2fa3c498b7082a505b64d689910eb415c` 以原 tag 为父提交，Author/Committer 均为已确认身份 `Ziwei Zhao <199458887+zvision755@users.noreply.github.com>`。媒体、数据卷和真实账号凭据未上传。

**当前运行环境：OrbStack Docker，正式页面 http://127.0.0.1:1182/。最新结论见末尾“OrbStack 运行调整”；下方早期 1181/待登录/缺 Rust 状态仅作为过程记录。**

## 2026-10-15 Windows Jellyfin 测试准备

- 用户确认 Mac 本地文件夹媒体库测试通过。Mac 目录映射为容器路径 `/media/anime`；本地路径本身不应填进 Docker 内运行的 NipaPlay。
- 为 Windows Docker Desktop 新增 `scripts/prepare_fnos_windows.ps1`：下载/校验 Flutter 3.44.6、按 `pubspec.lock` 解析依赖，在 Git 忽略的 `.porting` 下准备 Docker 的 Flutter 源码与 Pub 缓存上下文。脚本会保存并还原现有桌面插件注册文件，避免准备构建环境改变代码工作区。
- Compose 现在要求显式设置 `NIPAPLAY_MEDIA_DIR`，避免在 Windows 上悄悄使用 Mac 路径。PowerShell 流程和 Windows Jellyfin 联调说明见 `docs/DOCKER.md`。
- Jellyfin Web 连接校验由 NipaPlay Linux 容器发起，随后 Web 客户端也会直接读取 Jellyfin。Windows Jellyfin 应填容器与浏览器都能访问的 Windows 局域网 IPv4 地址/端口，不能填 localhost。实际 Docker Desktop、Windows 防火墙、CORS 与 Jellyfin 登录尚待 Windows 实机验证。
- Windows 新建的数据卷没有 Mac Docker 数据；不会复制或上传弹弹play/Bangumi/Jellyfin 凭据，Windows 测试时须在 NipaPlay 页面本机登录。
- 本轮未在 Windows 执行 PowerShell 脚本或 amd64 镜像构建；本机验证只有 OrbStack linux/arm64。不能把 Windows 部署或 Jellyfin 联调写成已通过。
- 个人 `origin` 指向公开 fork，保留 AimesSoft 原版 `upstream`；适配分支已上传。早期 HTTPS OAuth 缺少 `workflow` scope，SSH 验证成功但部分连接关闭；具体网络根因未确认。用户改用 HTTPS/PAT 后分支实际更新，回执仍断开；以远端提交比对判定成功。没有推送到上游。

## 最新进度（以下覆盖早期 gate-only 测试状态）

- 登录测试准备更新：此前 1181 服务的 30 分钟测试时限已触发退出，原版 gate 因 `/api/info` 不可达显示连接提示。恢复同源服务后浏览器直接进入首页，未要求手动填写地址。开发测试 host 已取消自动超时，仍不是系统开机服务。
- 新增服务端 `ServerPreferencesStore`，复用原 SharedPreferences 业务代码，持久化在 `.porting/local-media-test-data/private/preferences.json`，目录 0700/文件 0600，静态页面只服务 build/web，不公开凭据文件。当前是本机开发用单进程 JSON 存储，未实现加密静态存储。
- Bangumi 新增服务端保存/退出接口，Web 仅提交一次令牌并读取服务端状态，解决浏览器本地保存被 5 秒服务端状态覆盖的问题；弹弹play Web 不再读写浏览器 Token，服务器复用原登录/续期及持久化方法。密码不保存；凭据响应不记入测试 host 日志，并移除上游 WebToken 原文日志。
- 持久化重新打开/删除/0600 权限 1 项测试通过；Bangumi 空/错误输入及退出/状态 2 项通过；HTTP 鉴权及 Web 代理 11 项通过。账号模块静态检查无错误（上游警告仍在），Web 最终构建和复制校验通过。实际用户登录尚待手动完成。
- 修复 ScanService 首次异步载入文件夹与添加根目录的竞态：添加/列出目录等待载入完成，避免已登记根目录被旧的空列表覆盖。真实测试目录已恢复，重启后继续验证。

- 原版完整 WebApiService 已在隔离 Flutter 测试引擎中启动，真实 SQLite/缓存存放 `.porting/local-media-test-data`；仅监听回环 1181。该入口有 30 分钟测试时限，尚不是生产无界面服务。
- 用户媒体目录只登记一个根目录；API 证据 `.porting/logs/registered-media-roots.json`。浏览时子目录扁平卡片导致误解，Web 已改复用原版树形列表，实际展开/收起验证通过，截图 browser-library-tree.png；修复后 API 仍只登记一个根目录。
- MKV HEVC10bit/AAC 原流在本机 Chrome 播放、跳转成功；内封简体/繁体 SRT 已显示，关闭后消失，重新开启恢复。
- AVI 原 MPEG4/AC3 不被该浏览器支持，新增只读服务端 FFmpeg 转换缓存，真实整集 24:25 在原播放器播放。外挂 UTF16 ASS 通过原解析器/叠层，00:48 同一暂停画面实际验证开启、关闭、重开。
- **ASS 特效尚未支持**，当前只有文本、时间。已研究 JASSUB/libass WebAssembly 候选，未引入或验证，后续需保留字体/样式/动画及验证开关。
- 字幕菜单已恢复 Web 可见；补充自动加载默认字幕，避免每集手动选轨。最终构建及复制校验通过，AVI 从媒体库重新播放后自动出现片头字幕，截图 browser-avi-subtitle-auto.png；MKV 自动选择尚未单独复核。
- HTTP Range/HEAD 与字幕缓存开关 6 项回归通过，见 `web-subtitle-regression-final.log`。原 24 项测试先前通过。阶段 Web 字幕构建成功，最终包装构建见 `web-subtitle-tree-final-build.log`。
- Rust 扫描仍缺动态组件；共享番剧编目、批量匹配保存、弹幕、真实账号尚未完成端到端验证。首页继续观看的本地物理路径恢复也仍有 Web 兼容缺口。
- 测试截图/日志在 `.porting/logs/`，原媒体及外挂字幕从未修改。详细当前结论见 WEB_PORTING_REPORT.md 最新实测更新。

## 源码基线

- 上游：https://github.com/AimesSoft/NipaPlay-Reload
- 固定 tag：`v1.11.9`
- 固定提交：`c26e1f9947e3091b400b07ec2d5558a617bb38ad`
- 分支：`fnos/web-port-v1.11.9`；remote：`upstream`。
- 保留非浅 Git 历史；使用 blob:none 部分克隆，历史版本文件内容可从 upstream 按需获取。
- 多次 Git 文件传输中断后，以官方同 tag 归档补齐；4,852 个 tracked blob（包含符号链接）逐一校验 Git 哈希，见 `.porting/logs/archive-verification.log`。
- 仅初始化 Web 依赖所需 `third_party/media-kit-upstream`，固定 `7a2135661ff37a717f11d6012fefa56cae27ef36`。其余原生编译子模块尚未初始化。

## 环境

- macOS arm64；Git 和 Xcode Command Line Tools 可用。
- OrbStack 2.2.3 / Docker Engine 29.4.0 可用，服务端为 linux/arm64。NAS 的实际 CPU 架构未知。
- 系统 PATH 未找到 Flutter/Dart、Rust/Cargo；没有安装 Xcode、Android Studio、VS Code 或 Rust。
- 按上游 `.github/actions/setup-flutter/action.yml` 固定 Flutter 3.44.6，隔离在 `.porting/tools/flutter`，配套 Dart 3.12.2，Pub 缓存在 `.porting/pub-cache`。
- SDK 官方源码及引擎下载均已实际尝试；启动版本日志：`.porting/logs/flutter-bootstrap-retry.log`。
- Git 配置显示 Ziwei Zhao / GitHub noreply 邮箱；未据此认定已获提交身份确认，本轮不创建提交。

## 已完成审计

- Web gate、后端探测、条件导入、静态资源服务、账号/弹幕/媒体 API。
- 统一媒体库分区、SQLite 观看历史、共享管理、SMB/WebDAV/Jellyfin/Emby。
- 双栏手动批量匹配的数据流与保存逻辑。
- 弹弹play网关鉴权、Bangumi Token/同步与 OAuth 绑定的区别。
- Web VideoPlayer 选择、HTTP Range、外挂字幕、弹幕渲染与 Rust 扫描边界。
- Shelf 与 Flutter/Provider/插件的耦合；当前没有独立无 GUI API 入口的验证。

## 构建与测试

1. 已运行原版 `build_and_copy_web.sh`，完整日志：`.porting/logs/web-build-baseline.log`。
2. 第一次失败原因是 Flutter `flutter_patched_sdk.zip` 下载途中连接关闭，发生在源码编译之前。
3. 脚本退出码 **0**；`build/web/index.html`、`main.dart.js`、`flutter_bootstrap.js` 全部不存在。证据：`.porting/logs/web-build-baseline-status.txt`。这是失败，不能作为 Web 可运行证据。
4. 使用命令级 Flutter 中国存储镜像补齐 Web SDK，`flutter pub get --enforce-lockfile` 成功；原版 Web 编译成功，未修改业务源码或锁文件。普通 JavaScript 构建通过，Wasm 预检有警告。
5. 新增 `scripts/build_fnos_web.sh`，保留原版构建流程。隔离旧 build/web，检查失败警告、必需产物和复制一致性，防止旧产物或上游警告路径伪装成功。第一次用 mtime 判断新鲜度误拒绝 Flutter 缓存恢复产物，已改为隔离旧目录；日志仍保留。
6. Chrome 实际加载原版远程访问 gate，输入本机地址后显示“连接失败，请确认远程访问服务已开启”。仅有静态资源，没有伪造业务后端。证据：`.porting/logs/browser-static-gate.png`、`browser-static-gate.txt`。
7. 原版弹幕匹配访问策略、弹弹play HTTP 鉴权和 Web 代理的三组测试共 **24 项通过**；这不是账号或播放器端到端测试。日志：`.porting/logs/upstream-core-tests.log`。
8. 普通 Dart 的原 Shelf 导入探针失败；进一步缩到仅导入 Flutter material 仍发生同类 FFI transformation compiler crash，说明不能将异常归因于某个 Rust/播放器模块。日志见报告。
9. 最终单次构建及包装检查退出 0，build/web 与 assets/web 的入口/JS/bootstrap SHA-256 一致；两个目录各约 79 MiB。证据：`.porting/logs/web-build-final-verified.log`、`final-web-sha256.txt`。依赖工具生成的跨平台注册文件和原 `.gitkeep` 已恢复至 tag 内容，业务源码没有改动。
10. 本机静态服务仅监听 `127.0.0.1:1180`，页面 200，业务 `/api/info` 为 404；服务与 Chrome 页面保留供查看。这不是生产后端。
11. 最终构建后 Chrome 干净刷新，使用标准 textbox 输入复核连接提示，未捕获新的 error/warn；初次可访问性 setValue 路径的 null-check 未复现。最终截图：`.porting/logs/browser-final-gate.png`。

| 功能 | 当前真实验证状态 |
| --- | --- |
| 首页/界面 | Web 产物成功，Chrome 原 gate 已显示；主界面待可用后端 |
| 统一媒体库浏览 | 完成源码审计，当前 gate 阻挡，未进入验证 |
| NAS 文件夹管理 | 原有共享管理 API/UI 已定位，待后端 |
| 视频播放/拖动 | 原有 VideoPlayer/Range 已定位，尚无样本和后端，未验证 |
| 弹幕搜索/下载 | 原有代理与鉴权已定位，未请求账号授权 |
| 手动整季批量匹配 | 原版逻辑可复用；共享 Web 保存接口缺口已定位 |
| 弹幕叠加 | 原版 Web 回退内核已定位，未播放验证 |
| Bangumi 登录/同步 | Token 与后端状态同步缺口已定位，未授权验证 |
| 弹弹play 登录 | 原有代理入口已定位，未授权验证 |
| Jellyfin/Emby | 原有统一界面/传输层已定位，未连接真实服务器 |
| 后端独立运行 | 当前代码有 Flutter/插件耦合，未通过无 GUI 启动验证 |

## 下一步

原版 Web 已编译成功，下一步优先最小解耦并真实启动 Shelf 业务后端，再验证统一媒体库、批量 mappings 保存、播放与账号流程。用户已说明 Mac 没有媒体库，已创建 Git 排除的 `test-media/`，可接收 Windows 的小型番剧测试文件夹。真实账号仅由用户在应用/授权页面输入。完成核心链路验证后再确定 Docker 跨架构构建、FPK 和 FN Connect，暂不打包或修改 NAS。

12. 按照用户确认，修复 ASS/SSA 卡拉 OK 字幕在浏览器中的字体方框问题。Web 现在用 JASSUB/libass 渲染保留原样式与 karaoke 标签的 ASS 字幕，并将字幕样式引用的字体映射到 NipaPlay 已有的 `Droid Sans Fallback`（`assets/subfont.ttf`）；没有添加新的特效开关或入口。
13. 本机浏览器实际播放用户提供的 AVI 第 1 集，选择简体 ASS 后检查到 JASSUB 画布已挂载，日文与中文歌词及 OP 卡拉 OK 效果正常。开始时同一页面显示 CJK 方框；加载原版项目内字体并映射缺失字体后，用户确认字幕已正确显示。ASS API 实际返回完整 track（376 Dialogue 行、429 karaoke 标签）。
14. `./scripts/build_fnos_web.sh` 在添加 ASS 原文端点、JASSUB worker/WASM 资源和字体回退后再次成功，build/web 与 assets/web 文件校验通过。Wasm 预检保留 Flutter/universal_html 和插件兼容警告；当前使用 JS Web 构建。
15. `docs/WEB_PORTING_LICENSE_INVENTORY.tsv` 和 `web/vendor/jassub/NOTICE.md` 已记录 JASSUB 复合许可证及复用字体来源；原 Droid Sans Fallback 字体许可文本尚待发布前确认。

## 2026-10-14 OrbStack 运行调整（覆盖前文过时状态）

### 已确认诊断

- 原 macOS 1181 测试 host 首次打开/刷新仍能渲染，不能把所有刷新异常归因于缓存或 Docker。实际复现的是播放器设置提示框执行 Web 不支持的 `Platform.isWindows`；main.dart.js 调用栈对应 `tooltip_bubble.dart::_getBubbleWidth`，已加 `!kIsWeb`。诊断记录 `.porting/logs/refresh-diagnosis.md`。
- 自动打开/刷新重新播放 ASS 的路径只加载普通 cue，手动轨道选择才调用 JASSUB；现统一走 `SubtitleManager.activateWebSubtitleTrack`，有 ASS 样式默认渲染，无新增特效开关。Docker 实际 AVI 播放显示日文/中文 OP 特效，DOM 1 个 JASSUB canvas、video readyState 4，播放时间增加，弹幕可见；设置按钮悬停无原平台异常。
- `file://.../web/index.html` 是源码入口，没有生成的 bootstrap，不能用它验收。固定使用 HTTP 1182 的容器构建产物。
- 某些远端图片请求 500、开发首页空图片 URL 返回 HTML 导致 ImageCodecException，尚未完全处理；不等同于媒体库/播放不可达。外部服务的超时与 TLS 问题仍可能存在。

### 架构与实际构建

- `server/fnos/main.dart` 独立 main 复用原 WebApiService、LocalMediaManagementApi、DandanplayService、BangumiSyncService、ScanService 和 WatchHistoryManager；没有 flutter_test/runApp/桌面会话。仍用 Flutter 无界面引擎，尚不是纯 Dart 服务端；桌面远程控制接口 501。
- `docker/Dockerfile` 多阶段构建，固定 Debian/Rust 镜像 digest、Flutter revision/Dart 与 Cargo/Pub 锁文件。生产运行镜像约 1.14 GB（含原 Flutter 内核、FFmpeg/共享库）；无 Xvfb/VNC/完整桌面环境。
- 首次 Git Flutter 下载 TLS 失败；第二次 Git Pub 依赖 TLS 失败。改为导出现有官方 SDK 的公开源码与项目公开 Pub 缓存，严格离线锁文件解析，不导出整个 `.porting`，未关闭 TLS 验证。
- ARM64 前端编译器快照改用 SDK 的 host snapshot；Rust 构建补齐原 `include_bytes!` 字体资源。原 Rust 扫描只认 mp4/mkv，已最小增加 AVI；Linux 扫描识别 5 集。原 Rust 库完整构建，扫描差异/sha256 两项原测试通过。
- 开发模式首启因导出的 Pub 文件权限而失败，定位 Permission denied 后只在镜像内为公开包设置读取权限；非 root 开发容器现已健康，启动从只读源码挂载编译到 `/tmp` 成功。
- 生产 Compose 使用 `nipaplay-fnos-data` 独立卷、UID/GID 10001，媒体只读 `/media/anime`，HTTP 回环 1182；开发 Flutter 1183 通过 api 参数连接同一后端/数据卷。两种模式互斥一个 app 服务，避免并行写库。未修改 ChainFlow 容器/端口或重启 OrbStack daemon。
- Linux arm64 实际成功；amd64 引擎/基础镜像可用，尚未构建或运行 amd64。并行多架构 Cargo 缓存还需按架构隔离。当前适配仍为未提交工作区，healthz 标识 HEAD+构建摘要；不声称仅凭上游 tag 能复现所有适配改动。

### 数据与真实验收

- 原 `.porting/local-media-test-data` 保留；一致性副本 `.porting/docker-seed` 迁移进 Docker 卷，媒体路径重定位，SQLite integrity ok，private/preferences.json 0600。两个真实账号状态 true，未读取/输出其凭据。
- 首次打开、三次逐次刷新及另开测试标签通过首页渲染；媒体库显示 2 部/5 集；库 API、账号状态 API 200。Chrome 初测后按用户要求关闭本轮创建的 4 个 Chrome 标签，此后仅用 Codex 内置浏览器。
- 实际搜索“惊爆草莓”返回 1 结果；弹幕加载 2494 条；Range 206、Content-Range 正确，0–1023 的 1024 字节与源文件一致。证据 `docker-http-verification.json`、`docker-http-after-recreate.json`、`docker-http-final.json`。
- 仅重建/重启本项目容器，曾验证两个账号、2 部/5 集持久化；没有重启 Docker daemon（避免影响其他项目）。原 7 项 Range/偏好存储/字幕测试通过。
- 后续日志明确出现 `DELETE /api/media/local/manage/folders 200`，连带移除了原 5 条库记录。目前库为空由这次删除请求导致，不能表述为容器持久化失败。没有擅自把已删除的旧匹配恢复进正式库；视频未被删除。
- 用户提出缺少删除/重新匹配入口：新增卡片菜单，复用原 BatchDanmakuMatchDialog 与持久化方法；移除复用原 WatchHistoryManager 删除及 tombstone，确认对话框说明观看记录删除、视频保留。隔离测试 3 项通过（移除保留源文件/文件夹，拒绝跨源记录，重匹配保留进度），未删除正式用户番剧。
- Flutter machine hot.reload 请求返回 0，但输出 No client connected；已验证重新编译后刷新加载，保状态热重载未验收。开发 Web 与非 root Linux 后端实际已连接，不需要前端改动就重建完整镜像。

构建日志：`.porting/logs/orbstack-build*.log`（保留失败/修复后的日志）；运行说明 `docs/DOCKER.md`。FPK、真实 fnOS、Jellyfin/Emby/飞牛影视、GPU 转码、发布许可证/独立服务授权仍未验收。

- 补充内置浏览器隔离 UI 验证：1184 使用只包含原 SQLite 编目的独立测试卷，无账号凭据，不写正式卷。卡片菜单两个选项可见；“重新匹配”打开原双栏窗口并列出两集 AVI；移除确认文案明确记录删除/视频保留，未提交正式库移除。正式 1182 已恢复生产模式并单独 restart，SQLite integrity ok；当前 0 条与此前删除文件夹一致。
