# 更新与侧载：维护者说明

普通用户请看[首次安装](INSTALL.md)、[日常升级](UPDATE.md)、[续期](RENEWAL.md)。本页说明更新接口及发布约定。

## 路线

首次安装、签名、设备连接和续期复用现成工具。HiPDA·OH 提供官方发布检查、下载、完整性校验、交给手机小白助手以及系统文件分享，不维护签名器、证书服务或 Windows 安装助手。

定向交接参考 [Kazumi 的原生桥接](https://github.com/ErBWs/Kazumi/blob/f7a482e9142d84500daca7fbaea7efe6ac64c111/ohos/entry/src/main/ets/entryability/MethodCall.ets)，使用系统 `viewData`、文件 URI 和目标包名 `com.xiaobai.hap_installer`，仅授予读取所选 HAP 的权限。小白官方 HAP 的清单声明了该接收入口；本项目已经实机确认接收文件。系统分享面板未列出小白时，可用定向交接或“另存为 → 小白选包”。

## 发布约定

- 使用官方仓库的 Releases 列表，包含 Pre-release，跳过 Draft 和没有 HAP 的发布。匿名访问，不要求 GitHub Token。
- Tag 格式为 `v1.0.0-beta.6`、`v1.0.0` 或 `v1.0.0.4`。
- 同一 Tag 的 `AppScope/app.json5` 保持可用 `JSON.parse` 读取的 JSON 子集，包含正确包名、版本名和正整数 `versionCode`。不执行 JSON5/JS。
- 附件为 `hipda-oh-<versionName>-unsigned.hap` 和 `SHA256SUMS.txt`，URL 属于同一官方 Release；校验文件采用 SHA-256、两个空格及文件名的标准格式。
- 仅用 `versionCode` 比较版本，不根据 Beta 字符串、日期或发布排序推断新旧。发行前核对 HAP、Tag 源码及校验文件一致。
- 不修改已发布版本的 Tag 或附件；候选包经确认后再发布。
- 当前上限：HAP 64 MiB、校验文件 16 KiB、API 2 MiB、最多 24 个可安装 Release。触及上限明确报错，不将不完整检查显示为“最新”。接近上限前需实现经过验证的分页或索引。

## 网络和文件边界

HTTP 请求独立于论坛会话，不携带论坛 Cookie、账号或 GitHub Token。逐跳拦截器仅允许 HTTPS 官方 API、该仓库标签源码及发布附件路径和 GitHub 附件 CDN。拦截器不可用时停止请求，最多五次重定向，设置连接/读取超时及总截止时间，不跳过证书校验。

文件流式写入私有缓存，限制字节数，同时等待成功响应和 `dataEnd`，不假定回调顺序。大小和 SHA-256 均正确后才改名为 HAP；半成品不供交接。取消、失败或页面退出会中止请求，清理半成品，并防止迟到回调更新已销毁的页面。只清理本更新器拥有的文件名，不触碰论坛数据或用户文档。

打开小白或系统分享前再次校验文件。校验失败时停止；工具缺失时提示分享/另存为及电脑安装路径。交接成功不代表安装成功，安装工具仍须由用户确认。隐私说明覆盖主动 GitHub 请求、缓存和文件交接；不改变 Cookie 安全存储。

## 验证范围

版本检测、下载、校验、系统分享、另存为、小白选包和定向交接已实机验证。原签名 beta.5 到 beta.6 候选版的递增版本覆盖，以及当前账号、设置、可见浏览记录保留已验证；不代表检查了全部本地数据。

小白 3.1 在“直接安装”完成后可能保存历史失败；[上游同类反馈](https://github.com/likuai2010/auto-installer/issues/120) 尚无作者确认的通用修复。小白自身选择“使用当前证书”续期，本轮也遇到待重签文件打不开，系统记录确认未重新安装。因此 HiPDA·OH 的自动重签、续期及续期后数据保留仍待验收，不能宣传为一键安装/一键续期已经完整打通。

离线回归覆盖版本判断、限流、下载进度、损坏阻断、取消、存储错误、分享前重校验、安装器缺失和页面销毁回调。`scripts/verify-github-update.cjs <SDK typescript.js> [installedVersionCode]` 可匿名核对现有发布和文件校验值，不写 GitHub、不安装软件。`ohosTest` 提供可选实机入口，测试样本、签名材料和调试记录仅保留本地。

## 参考来源

- [小白 3.1 发布说明](https://github.com/likuai2010/auto-installer/releases/tag/3.1.0)：登录保留、无线端口、续期、日历提醒及直接安装已签名 HAP。
- [Kazumi 安装说明](https://kazumi.app/docs/misc/how-to-install-in-ohos/)：电脑引导安装手机助手；旧版界面及 Java 说明不能照搬到 3.1。
- [小白历史/续期反馈 #108](https://github.com/likuai2010/auto-installer/issues/108)、[续期入口反馈 #124](https://github.com/likuai2010/auto-installer/issues/124)：发布说明不代表所有设备均可用。
- [小白选包反馈 #116](https://github.com/likuai2010/auto-installer/issues/116)：有用户尝试 HoKit，但不证明跨工具签名及数据保留。
- [HoKit 桌面版](https://github.com/yabi-zzh/HoKit)、[手机版入口](https://gitcode.com/yabi-zzh/HoKit-App)、[作者应用的推荐](https://github.com/yabi-zzh/livify-ohos)：仅作备选，未验证本项目的手机交接或无损迁移。
- [GitHub Releases API](https://docs.github.com/en/rest/releases/releases#list-releases)：公开发布与附件查询。
- [华为调试证书说明](https://developer.huawei.com/consumer/en/doc/app/agc-help-add-debugcert-0000001914263178)：证书期限与应用设备授权期限分别核对。

实现同时核对本机 HarmonyOS SDK 的 HTTP 拦截器、流式请求、文件哈希、URI 读权限及系统分享 API。NG/MY4D4Y 的论坛逻辑不作为鸿蒙签名依据。
