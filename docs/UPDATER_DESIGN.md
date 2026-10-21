# 更新与侧载：维护者说明

普通用户请看[首次安装](INSTALL.md)、[日常升级](UPDATE.md)、[续期](RENEWAL.md)。本页不是用户安装步骤。

## 路线

不维护签名器、证书服务器或 Windows 安装助手。首次通过现成电脑工具引导安装；HiPDA·OH 仅提供官方发布检查、下载、完整性校验和系统文件分享。手机安装工具独立负责登录、签名、设备连接与用户确认安装。

本分支不直接调用猜测的安装器协议。Kazumi 的原生桥接有可参考的 `viewData + file URI + com.xiaobai.hap_installer` 实现，但它和系统分享不是同一接口；在本项目真机完成读权限、包接收及失败回退验证前，不开启定向交接。

已只读检查小白 3.1 官方 HAP 的 `module.json`：`com.xiaobai.hap_installer/EntryAbility` 为 exported，声明 `sendData` / `viewData`、file scheme 和 `openharmony.package` 类型。它提供了文件交接依据，仍不能代替系统分享匹配和文件读取的真机验证。其清单版本显示 `1.0.0 / 1`，教程须以官方发布文件与实际界面识别 3.1，不用该字段冒认工具版本。

## 发布契约

- 使用 GitHub Releases 列表，而不是排除预发布的 `latest`。匿名访问，不配置 Token。
- 跳过 Draft 和没有 HAP 的源码-only 发布。beta.1 属于后一种。
- 每个可安装 Release 的 tag 形如 `v1.0.0-beta.6`、`v1.0.0` 或 `v1.0.0.4`。
- 同一 tag 的 `AppScope/app.json5` 须保持可用 `JSON.parse` 读取的 JSON 子集，并包含正确的 `bundleName`、`versionName`、正整数 `versionCode`。不执行 JSON5/JS。版本名须与 tag 一致。
- 附件严格使用 `hipda-oh-<versionName>-unsigned.hap` 和 `SHA256SUMS.txt`；后者为标准 SHA-256 两空格文件名格式。文件名和 URL 均须属于同一官方 Release。
- 版本比较仅依据标签源码中的 `versionCode`，不依据 beta 字符串顺序、发布日期、草稿或附件上传时间。发行前务必核对 HAP 内版本与标签源码一致。
- 不改动 beta.5 或历史 tag、附件。新版本建议使用 beta.6 / 1000007，需验收与发布授权后确定。
- 当前安全上限：单 HAP 64 MiB、校验文件 16 KiB、API 2 MiB、最多 24 个可安装 Release。触及上限明确失败，不把不完整检查说成“最新”；发布数量接近上限前需改为经过验证的分页/索引方案。

## 边界与失败处理

HTTP 使用独立匿名请求，不复用 4D4Y WebView/会话。逐跳拦截器仅允许 HTTPS 官方 GitHub API、该仓库标签源码/附件路径及 GitHub 附件 CDN；拦截器不可用时失败关闭。禁用缓存，设连接/读取超时，最多五次重定向。

流式落盘，限制字节数；`.part` 不供分享。同时等待成功响应码与 `dataEnd`，不假定两个回调的先后顺序；120 秒总截止时间及显式取消能解除缺失结束回调的等待。大小及 SHA-256 均正确才改名为 HAP；取消、失败清理半成品。分享前再次校验。系统分享仅授予所选文件的访问，不增加存储权限。页面销毁取消请求，不更新已销毁页面。

校验保护传输完整性，不是独立签名认证，也不保证系统或安装工具一定接受 HAP。分享成功不等于安装成功。没有兼容分享目标则提示浏览器/电脑路径，不自动下载安装器或卸载原应用。

隐私政策补充主动 GitHub 请求及安装文件缓存，使用统一新政策版本重新征得同意；不改变现有 Cookie 安全存储。

## 已核查的上游依据（2026-10-20）

| 来源 | 能支持的判断 | 不足以证明的内容 |
|---|---|---|
| [小白 3.1 发布说明](https://github.com/likuai2010/auto-installer/releases/tag/3.1.0) | 登录保留、续期、日历提醒，升级助手需 2.5+；下载目录有账号/备份 | 所有设备均成功、账号永不过期、无损跨签名 |
| [Kazumi 安装说明](https://kazumi.app/docs/misc/how-to-install-in-ohos/) | 电脑首次装手机助手、后续手机更新的社区路线 | 本项目分享面板一定能列出小白；文档部分旧版 Java 描述不应照搬到 3.1 |
| [Kazumi 原生桥接](https://github.com/ErBWs/Kazumi/blob/f7a482e9142d84500daca7fbaea7efe6ac64c111/ohos/entry/src/main/ets/entryability/MethodCall.ets) | `openWithInstaller` 的真实跨应用调用 | 不代表 HiPDA·OH 已实测；不可照搬写权限授权 |
| [小白 #124](https://github.com/likuai2010/auto-installer/issues/124) | 最新反馈可能缺少自身续期入口 | 发布日志的按钮并非所有人可见 |
| [小白 #118](https://github.com/likuai2010/auto-installer/issues/118)、[#116](https://github.com/likuai2010/auto-installer/issues/116) | 签名/选包仍会失败；有用户使用 HoKit 选包成功 | 不能推导重置证书或换安装器必然无损 |
| [HoKit Releases](https://github.com/yabi-zzh/HoKit/releases)、[Issues](https://github.com/yabi-zzh/HoKit/issues) | 桌面工具仍维护；近期修复网络、重签/设备相关错误 | 不等同手机版能力，不能把投屏服务 HAP 当手机签装器 |
| [HoKit 作者应用的推荐](https://github.com/yabi-zzh/livify-ohos)、[手机入口](https://gitcode.com/yabi-zzh/HoKit-App) | 可追溯的手机版入口 | 手机仓库页面未提供可审阅接口代码，未验证数据迁移 |
| [GitHub Releases API](https://docs.github.com/en/rest/releases/releases#list-releases) | 公开发布及附件查询契约 | `latest` 不满足 Beta 检查需求 |
| [华为调试证书说明](https://developer.huawei.com/consumer/en/doc/app/agc-help-add-debugcert-0000001914263178) | 证书有期限 | 证书期限不等于每份应用 Profile 的运行期限 |

也核对本机 HarmonyOS SDK 的 `HttpInterceptorChain`、`requestInStream`、`file.hash` 和现有图片分享的 `ShareController` 用法。NG/MY4D4Y 的论坛逻辑不是鸿蒙签名依据，本任务不因此改动论坛业务。

## 开发验证与发布前验收

离线测试入口：现有 `run-regressions.cjs` 自动包含 `github-update.test.cjs`。该测试运行真实生产策略/服务方法，以受控网络及文件适配器覆盖版本、边界、进度、损坏、取消、磁盘失败、限流、分享前重校验，不连接手机。

`scripts/verify-github-update.cjs <SDK typescript.js> [installedVersionCode]` 是开发者只读联网检查，匿名验证现有 Releases 和 HAP SHA-256，不写 GitHub、不安装软件。它验证数据源与策略，不冒充 HarmonyOS 原生传输测试。

发布前须人工核对：

2026-10-21 的阶段性实机结果：已核对本地测试包与 Mate 60 原安装包的签名证书指纹、应用标识及包名一致；经用户允许，覆盖安装成功，系统报告 `1.0.0-beta.5 / 1000006`。新版隐私政策重新确认页正常出现。此为开发者原签名测试包，**不是小白 3.1 签装验收**；论坛账号、偏好、阅读记录保留及安装工具交接仍需继续核对。该测试包没有替换 GitHub 已发布 beta.5。

- [ ] Windows 3.1 首次安装小白手机版和 HiPDA·OH，补真实、脱敏后的教程截图。
- [ ] 手机更新页：没有新版/有新版、断网重试、取消下载、退出页面、再次分享。
- [ ] 小白 3.1 能否接收系统分享 HAP；如不能，浏览器下载后文件选择与电脑路径是否清楚。
- [ ] 原签名覆盖升级后版本正确，论坛账号、主题/字号、浏览记录保留。
- [ ] 小白一键续期后再核对以上数据；实际按钮、日期提醒、登录恢复截图。
- [ ] HoKit 只作备选；跨工具数据保留未验证时不推荐普通用户迁移。
- [ ] 新版 HAP 内 versionCode、版本名、包名与 tag 源码一致，SHA256SUMS 匹配。
- [ ] 不发布开发记录、账号文件、调试签名、密码或设备绑定包；经用户确认再创建新 Release。
