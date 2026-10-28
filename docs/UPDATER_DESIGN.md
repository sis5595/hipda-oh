# 更新与侧载：维护者说明

普通用户请看[首次安装](INSTALL.md)、[日常升级](UPDATE.md)、[续期与迁移](RENEWAL.md)。

## 边界与文件导出

HiPDA·OH 负责官方 GitHub 发布检查、下载、完整性校验、系统分享和系统文件保存，不绑定签名安装工具，不管理证书、私钥或安装账号，不执行重新签名、卸载、清空数据或安装。

安装器正在重新验证。源码、测试及运行时不保留旧工具的目标包名、定向 Want、缓存或历史兼容层。历史 CHANGELOG 的实测事实保留，用户文档只在迁移说明中提及旧工具。

接口保持简单：

- `GitHubUpdateService.check(installedCode)`：取得官方可安装更新。
- `download(candidate, cacheDir, progress)`：返回大小及 SHA-256 均通过的私有缓存 HAP。
- `verifyForExport(candidate, path)`：每次分享、保存或未来工具交接前的统一校验入口。
- `UpdatePanel.share()`：系统 `SharedData` / `ShareController`，只导出所选文件，不预设任何目标工具。
- `UpdatePanel.save()`：系统 `DocumentViewPicker.save` 取得用户选择的 URI；选择前及返回后校验，异步按文件描述符复制并检查目标大小，关闭文件句柄。用户可取消，不申请广泛存储权限。

未来若新增经验证的工具交接，仅增加调用 `verifyForExport` 的小型导出动作及对应测试，按需调整 UI 和教程；下载、版本比较和校验服务无需重写。不预置工具探测，不建立插件框架。

系统分享没有合适目标或分享失败时，独立保存入口仍可使用。保存位置由用户选择，副本由用户管理。分享/保存成功不代表安装成功。保存失败可能留下空或不完整的目标文件，提示用户不要导入，不擅自删除其选择的文件。

## 发布约定

- 匿名读取官方仓库 Releases 列表，包含 Pre-release，跳过 Draft 和没有 HAP 的发布。不要求 GitHub Token。
- Tag 格式为 `v1.0.0-beta.6`、`v1.0.0` 或 `v1.0.0.4`。
- 对应 Tag 的 `AppScope/app.json5` 保持可用 `JSON.parse` 读取的 JSON 子集，含正确包名、版本名和正整数 versionCode。不执行 JS。
- 附件为 `hipda-oh-<versionName>-unsigned.hap` 和 `SHA256SUMS.txt`，均来自同一官方 Release；校验文件采用标准 SHA-256、两个空格及文件名格式。
- 仅用 versionCode 比较新旧，发行前核对 HAP、标签源码和校验文件一致。
- 不修改已发布 beta.5 或历史附件。beta.6 仍为候选，未经确认不推送或发布。
- 上限：HAP 64 MiB、校验文件 16 KiB、API 2 MiB、最多 24 个可安装 Release。列表达到 100 条时停止，避免把截断历史误报为最新。后续接近上限时实现经过验证的分页或索引。

## 网络、完整性与隐私

独立 HTTP 请求不携带论坛 Cookie、账号或 GitHub Token。逐跳只允许 HTTPS 官方 API、仓库标签源码/附件及 GitHub 附件 CDN；拦截器不可用则停止，最多五次重定向，不跳过 TLS 校验。

流式写入私有缓存，限制字节数，同时等待成功响应和 `dataEnd`。文件大小和 SHA-256 均正确才改名为 HAP，半成品不导出。取消、失败及页面退出中止请求并清理更新器拥有的半成品，防止迟到回调写 UI。

导出前重新从官方源获取校验信息；网络失败时保留重试入口，损坏时清除可导出状态。SHA-256 是官方发布文件的一致性检查，不是独立发行签名。隐私政策同步说明用户主动网络请求、缓存、系统分享和用户选定位置的副本。

## 验证范围与待办

此前已真机验证版本检测、真实下载、SHA-256、系统分享及通过分享另存为；也有原签名覆盖升级后当前账号、设置和可见阅读记录保留记录，不等于跨工具迁移验证。

本次去除定向工具交接、增加独立保存，测试覆盖导出前校验、选择期间文件变化、取消、权限/空间/短复制失败、重试、句柄清理及页面退出。新界面、独立保存到用户目录、分享回退和取消的真机验收待完成。本轮不安装或卸载手机应用。

`ohosTest` 仅保留复用生产 UpdatePanel 的通用设备测试入口，可显式模拟旧 versionCode 检查已发布包；没有本地签名样本交接、安装或续期操作。`scripts/verify-github-update.cjs` 是匿名只读联网检查，不写 GitHub。

新安装器的文件导入、签名、覆盖、续期及数据保留均需独立验收，不把 HoKit、QSStore 或其他候选描述为默认可靠方案。

## 接口依据

- [GitHub Releases API](https://docs.github.com/en/rest/releases/releases#list-releases)
- [OpenHarmony 保存用户文件](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/file-management/save-user-file.md)
- [HarmonyOS 系统文件选择器](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-file-picker)

同时核对本机 HarmonyOS 6.1.1 SDK 中 HTTP、文件哈希、文件选择器、异步文件复制、文件 URI 和系统分享声明，复用项目已有文件保存方式。
