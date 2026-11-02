# HiPDA·OH 便捷安装与更新：调研、决策和开发计划

> 状态：持续维护的工程决策记录（不是已经验收的用户教程）
>
> 建档与最后核对：2026-11-02；代码/发布基线：`main a102603c74001fd9bf658b6fa86057be719f1547`，`v1.0.0-beta.6.1`（`versionCode=1000008`）。
>
> 本文聚焦首次安装、日常更新、签名续期、安装渠道和迁移，不处理普通论坛功能。每轮实施后追加“验证记录/决策变化”，不得用计划中的效果替代真机证据。

## 1. 结论与设计红线

**已决定**

1. 采用 **同一套功能源码、两个并行发行渠道**：**A：华为 AppTest 邀请测试**；**B：GitHub Releases + QSStore / HoKit 社区侧载**。两者功能保持一致，安装和更新路径不同；不得退化成两个独立的功能分支。
2. GitHub 社区版继续长期维护，不以 AppTest 审核或测试期限作为其生存前提。
3. **社区版现有 bundleName `com.sis5595.hipdaoh` 原则上保持不变**，以免破坏当前已安装用户的连续升级。AppTest 原则上使用独立包名（暂定 `com.sis5595.hipdaoh.apptest`，**仅为候选值**，须先核验 AGC 支持、签名、设备共存和审批要求）。不允许两个渠道用互不兼容的签名互相覆盖。
4. 保留现有应用内 GitHub 版本查询、下载、校验、分享/保存能力；签名与安装继续由外部工具完成。AppTest 构建必须避免引导用户下载社区未签名包来覆盖 AppTest 安装。
5. **用户数据优先**：不得静默卸载、清除数据、重置证书、覆盖私钥、导出论坛 Cookie/账号凭据；签名不兼容即停止，并明确说明本地数据后果。任何迁移机制都必须先经明确授权与真机验证。
6. **小白调试助手（Auto-installer）已停止作为默认推荐。** HoKit、QSStore 均为待验收候选，未通过验收前不能宣传“免电脑、无损覆盖、自动续签、永久有效”。
7. 不要把“通过校验并打开分享面板”写成“安装成功”；不把第三方服务器上的云端私钥托管默认当成可接受方案。

**目标用户**：不会命令行、不会手工安装 DevEco Studio 的普通鸿蒙用户；允许分别提供邀请测试（低门槛）和社区侧载（可持续）的清晰教程。两渠道应尽可能避免重复下载安装。

## 2. 当前仓库进度（已核对，不代表全部真机验收）

| 项目 | 当前事实 | 证据 |
| --- | --- | --- |
| 版本 | 2026-11-02 最新 `v1.0.0-beta.6.1`；`versionCode=1000008`；主分支 `a102603c` | [Release](https://github.com/sis5595/hipda-oh/releases/tag/v1.0.0-beta.6.1)、[AppScope/app.json5](../AppScope/app.json5) |
| 安装包 | `hipda-oh-1.0.0-beta.6.1-unsigned.hap`，1,586,701 字节，SHA-256 `0d763efe710735d3bb67e5bda6a04746b2139e9fd55c0f1e8b2a804959e60edf` | [Release 附件](https://github.com/sis5595/hipda-oh/releases/tag/v1.0.0-beta.6.1) |
| beta.6 | 平板单栏适配、编辑器/键盘修复、灰底正文修复，新增手动检查更新与安全下载/导出 | [CHANGELOG](../CHANGELOG.md) |
| beta.6.1 | 平板及折叠屏双栏、拖动比例和持久化、窄屏/编辑/大图回退 | [CHANGELOG](../CHANGELOG.md) |
| 社区版包名 | `com.sis5595.hipdaoh`；支持 HarmonyOS 6.1.1 (API 24) 及以上 | [应用配置](../AppScope/app.json5)、[构建说明](BUILD.md) |
| 已有更新器 | `GitHubUpdatePolicy.ets` 读取官方 Releases / Tag 版本；`GitHubUpdateService.ets` 下载、大小/SHA-256 校验、重新校验导出；`UpdatePanel.ets` 分享与保存，不负责签名或安装 | [政策](../entry/src/main/ets/domain/update/GitHubUpdatePolicy.ets)、[服务](../entry/src/main/ets/data/update/GitHubUpdateService.ets)、[UI](../entry/src/main/ets/presentation/about/UpdatePanel.ets) |
| 签名和本地数据 | 旧版同签名覆盖后保留账号、设置、部分可见浏览记录**有历史真机记录**；新安装器、跨签名、跨包名、跨渠道迁移**没有验证** | [UPDATER_DESIGN](UPDATER_DESIGN.md)、[RENEWAL](RENEWAL.md) |
| 跨应用备份 | 当前 `backup_config.json` 配置 `allowToBackupRestore=false`；**不能假定可无损从社区版迁移到 AppTest 版** | [backup_config](../entry/src/main/resources/base/profile/backup_config.json) |
| 安装器选型 | INSTALL/UPDATE/RENEWAL 目前明确“不推荐默认安装器”，HoKit 和 QSStore 未完成本项目实机验收 | [INSTALL](INSTALL.md)、[UPDATE](UPDATE.md)、[RENEWAL](RENEWAL.md) |

**发现的文档欠账**（应在不夸大验证范围的前提下修复）：

- `docs/UPDATE.md` 和 `docs/UPDATER_DESIGN.md` 仍有“beta.6 未发布候选”的旧表述；实际 beta.6 和 beta.6.1 已发布。
- `AboutPage.ets` 的安装帮助链接指向 README 的 `#如何安装` 锚点，但当前 README 没有这个标题。需改为真实文档地址并验证手机点击可打开。
- README 目前只指向 Releases，不是完整新手安装教程；在安装器验收前应明确“无默认推荐工具”，不能虚构可用步骤。
- 发布流程中 `versionCode` 必须随版本真正递增；核查最终 HAP 的 `pack.info`/实际安装元数据，不能只依赖文件名或源码里的 `versionName`。

## 3. 调研记录：两类发布渠道

### A. 华为 AppTest 邀请测试

**已有外部依据**：

- [华为 AppTest 介绍](https://consumer.huawei.com/cn/support/content/zh-cn16046463/)：邀请测试的用户可通过 AppTest 获取应用，支持自动更新；**单个测试版本使用周期最长 90 天，到期不能继续使用**。
- [华为 AppTest 自动更新条件](https://consumer.huawei.com/cn/support/content/zh-cn16046465/)：不仅要开启 AppTest 的自动更新，也要开启应用市场的自动更新，且新版本需要相应邀测任务；系统条件满足时才进行更新。
- [华为开放式测试](https://developer.huawei.com/consumer/cn/agconnect/open-test/)：官网开放式测试介绍写内部模式 100 人、开放式测试最多 5000 人；而[AppTest 官方故障排查](https://consumer.huawei.com/cn/support/content/zh-cn16046462/)明确写每个邀请测试任务最多 10000 人。**这两个上限属于不同表述/可能不同测试类别，不应混同；具体以内测/外测任务类型和 AGC 控制台为准**。
- 香港 AppGallery 正式上架曾因“HiPDA/论坛名称、内容相似，需要授权或修改”遭驳回。**内部测试可能免人工审核不等于知识产权风险消失**，需要真实提交验证，不能保证通过。

**路线**：在 AGC 核对可用测试模式、测试地区、包名、签名、邀测和版本续发机制 → 以独立构建提交最小可用样本 → 邀请少量用户在真实设备安装 → 验证第二个测试版本更新、90 天机制及失败处置。

**使用约束**：不得以 AppTest 当成永久分发解决方案；考虑到 90 天失效，必须提供独立的社区版路径，但不承诺同一设备上跨渠道无损迁移。

### B. GitHub Releases + QSStore / HoKit 社区侧载

**已具备**：未签名 HAP 的 GitHub 发布链路；应用内匿名检查 GitHub Releases、下载与 SHA-256 复核、系统分享、保存到用户指定位置。下载、分享到安装器 ≠ 安装完成。

**工具调研**：

- [HoKit（桌面版）](https://github.com/yabi-zzh/HoKit)：公开 README 说明支持 Windows/macOS/Linux，HAP 重签名、设备注册、账号下证书/Profile 管理；以电脑侧签装作为候选兜底。能否无损继承旧版签名、连续升级需本项目验证。
- [QSStore/轻启·安装器](https://github.com/thx853068675-dev/QSStore)：带 GitHub/Gitee Release 索引、安装、版本跟踪、续签能力；`server/hapstore/collector.py` 实现读取包名/实际版本号和 GitHub 摘要。移动端首次安装、后续覆盖和自续签仍需真机验收，不能把作者成功案例当成 HiPDA·OH 已通过。
- [QSStore 首次安装 Issue #1](https://github.com/thx853068675-dev/QSStore/issues/1)：作者介绍先通过 AppTest 邀测安装其安装器，再利用安装器自行签装更新，证书续签需持续维护。这属于社区路径的**启动桥梁**，不是 HiPDA·OH 自身 AppTest 审核成功的证据。
- [QSStore 私钥保险库源码](https://github.com/thx853068675-dev/QSStore/blob/main/server/hapstore/identity_vault.py)：服务端具备按账号加密保管私钥的能力（AES-GCM，服务器持有解密主密钥）。调研时必须查明是否可拒绝云端备份、云端究竟存储什么、终端/服务器权限边界；默认不要求普通用户向第三方上传签名私钥。
- [MYMIX V2 发布仓库](https://github.com/a191442029/My-mix-v2-release)：公开 HAP 和详细自签步骤，说明 GitHub 分发确实有人在用；其 README 对直接安装有限制说明，不应照抄较新 Release 中“点击 HAP 即装”的简化文案。

**建议用户路径**：GitHub 为唯一权威 HAP 发行源，QSStore 负责发现/下载/用户侧签装与更新；HoKit 作为电脑端兜底。**先验收连续两个版本的无损覆盖、再确定默认安装器与教程**。不得在 HiPDA·OH 内新增处理开发者账号/私钥的代码。

**待证实**：QSStore 是否接受当前公开仓库收录、是否识别 `beta.6.1` 版本、下载和 checksum 是否配套、更新时签名身份是否保持、手机端有无免电脑安装、续签何时操作、断网或 GitHub API 限流后的处理。对 HoKit 验证相同签名覆盖、安装日志和失败路径。

## 4. 双渠道构建策略（工程设计候选，未实施）

原则：**保留现有社区版默认行为和既有包名**，新增 AppTest 发布配置，而不是从头重构更新器。两个构建来自同一提交；论坛功能一致，仅渠道配置/包名/签名来源/更新 UI 与帮助链接可不同。

| 项目 | Community（现有） | AppTest（新增） |
| --- | --- | --- |
| 包名 | `com.sis5595.hipdaoh`：不可轻易更改 | 候选 `com.sis5595.hipdaoh.apptest`；AGC 核验后冻结 |
| 产物 | release 模式未签名 HAP + SHA256SUMS，GitHub Releases | AGC/AppTest 所要求的发布签名及上传包 |
| 更新 | 沿用 GitHub 手动检查/校验/分享保存，安装器签装 | 交给 AppTest/应用市场更新；禁止用社区包覆盖 |
| 版本标识 | `versionName` 与主应用功能版本一致；`versionCode` 单调递增 | 建议保持相同功能版本；实际包内 `versionCode` 按独立渠道单调递增 |
| 数据 | 旧社区版可在相同签名身份下覆盖 | 与 Community 独立；切换成本需要单独说明 |
| 密钥 | 不提交任何私钥/证书/Profile | AGC 或本机受保护签名；不提交密钥 |

**验证性约束**：

- 现有 `GitHubUpdatePolicy.ets` 强校验 `bundleName=com.sis5595.hipdaoh`，并按固定文件名/Tag 检查。AppTest 构建不能未经设计就复用它的安装指引；应采用明确的构建渠道配置，但**不要在第一轮擅自大改生产下载器**。
- SDK/DevEco 是否支持产品变体覆盖 bundleName、目标包名如何在打包后生效、签名配置是否按模式隔离，均先实测再选用脚本或 product。禁止通过修改全局 `AppScope/app.json5` 后忘记恢复来完成双构建。
- AGC 创建测试应用/上传构建、变更公开发行渠道、登录华为账号、签名材料的使用，属于独立的操作门槛；Codex 不得自行对外发布或执行不可逆安装。
- 两渠道是否可以同时安装、原数据是否可转移，依赖真实签名、包名和数据沙箱行为；不得仅凭静态代码宣称成功。
- 统一生成并验收：包名、`versionCode`、`versionName`、`pack.info`、文件名、SHA-256、构建模式、签名状态。严禁把含开发者个人调试签名的包上传 GitHub Releases。

## 5. 验收矩阵

每项记录：设备型号/系统、工具与版本、原应用版本、原签名身份（**只记指纹，绝不记录私钥**）、目标版本、操作步骤、结果、错误码、证据位置及是否影响本地数据。

| 场景 | 通过标准 | 当前状态 |
| --- | --- | --- |
| Community 全新用户 | 普通用户按真实教程可从权威地址取得 HAP 并在本人设备完成签装 | 待验收新工具 |
| Community 同工具 V1→V2 | 覆盖升级，无卸载、包名不变、登录/设置/已读记录保留 | 待验收 |
| Community 安装器切换 | 可明确判断签名是否延续，无法延续时停止并提示 | 待验收 |
| Community 证书续签 | 到期前提醒/操作后仍能使用且有真实证据；验证断网与失败恢复 | 待验收 |
| AppTest 首装 | 收到有效邀请的普通账号直接安装，记录地区/审核/资格限制 | 待验收 |
| AppTest V1→V2 | 收到第二个测试任务并开启必要开关后，验证更新和数据保留 | 待验收 |
| AppTest 期限 | 确认 90 天和重新发布版本时的实际行为，不承诺永久有效 | 待验收 |
| 双渠道共存 | 不互相覆盖；版本与渠道明确显示，更新不会跳错渠道 | 待验收 |
| 社区下载完整性 | 只选择合法 GitHub Release，大小/校验不一致时禁止导出 | 已有代码和部分真机记录，最新版本复验 |
| 失败与回退 | 签名不匹配、存储不足、文件保存失败、网络/限流、不支持系统均有安全退出 | 部分已有测试，需综合验收 |

**设备安全**：现有日常手机上的旧应用不用于破坏性迁移试验；可优先用独立测试设备/测试包名/模拟器和脱敏账户。旧数据不动。不要对生产版本执行自动卸载、清数据或覆盖签名。

## 6. 开发计划（按门槛推进）

### M0 — 基线审计与低风险文档同步【下一轮 Codex 第一项】

- 从当前 `main` 读取最新状态，确认与本文件 `v1.0.0-beta.6.1 / a102603c` 基线是否一致；若有更新，以当前实际 Git commit、Release 和 `AppScope/app.json5` 为准，不回退已有功能。
- 清查现有 GitHub 更新器、产品配置、签名和备份配置；找出跨渠道会触发的所有硬编码和测试依赖，整理最小修改面。
- 运行已有离线测试/可用的只读 GitHub 更新检查；如缺 DevEco SDK，只报告“未执行”和具体依赖，不伪称通过。
- 修正 `docs/UPDATE.md`、`docs/UPDATER_DESIGN.md` 过时的 beta.6 候选描述；修复 About 页安装帮助的失效锚点，链接到真实现有文档。**不修改安装器默认推荐、不声称任何替代工具已验收。**
- 将审计结果、测试证据、阻断项追加到本文件的“进度记录”，标记已验证/推断/待验证。
- **交付门槛**：明确两渠道的包名/签名/更新隔离点、当前构建指令与实际测试结果；提交仅必要的文档/极小链接修复，不碰用户安装、外部发布或 AGC。
  
### M1 — Community 安装与升级闭环

- 用隔离测试环境实际验收 QSStore（手机端）与 HoKit（电脑端）：首次签装、连续两版更新、用户数据保留、失败提示、证书续签。
- 对比是否需要用户重复输入开发者账号、是否需要电脑、密钥在哪里保存；评估 QSStore 服务器存钥/备份选择和替代方式。
- 选择已验证的默认路径；如两者都不合格，则继续保留中性下载/导出，**不强行推荐**。
- 更新用户教程，明确“安装成功”与“仅完成下载/校验”的差别。

### M2 — AppTest 可行性验证

- 核验 AGC 测试开通、审核、知识产权风险、地区限制、人数配额、90 天失效机制与第二版本的自动更新条件。
- 仅在授权下创建最小测试应用及邀请任务；用少量可控账号和设备进行实际邀测。
- 记录被驳回原因，不用“改名即可过审”的猜测替代证据。

### M3 — 双渠道构建和升级路由

- 在 M2 明确 AGC 包名与发布要求后，以可复现脚本或 DevEco 支持的产品配置生成两个互不覆盖的构建；同源同功能。
- 保持 Community `com.sis5595.hipdaoh`、既有 Releases 更新协议与已发布 Tag；AppTest 使用自己的包名、签名和更新方式。
- 增加两个渠道各自的包内元数据、更新 UI 和回归测试；构建后检查 `pack.info` 与 SHA。
- **验收**：两个包可以分别安装且没有跨渠道升级路径；社区旧版能按既有签名更新。

### M4 — 数据保留、续期与迁移风险

- 在隔离设备验证 Community 同签名、不同签名；AppTest 连续更新；各自续期和到期。
- 若有跨渠道迁移需求，先研究系统 backup/Asset Store/安全存储限制与用户授权，再设计最小可行迁移；目前 `allowToBackupRestore=false`，**不能默认有迁移能力**。
- 不以私钥拷贝、Cookie 明文导出或自动卸载作为迁移方案。

### M5 — 文档和公开投放

- 验收后同步 README、`docs/INSTALL.md`、`docs/UPDATE.md`、`docs/RENEWAL.md`、本文件。
- 对两渠道分别给出安装和升级页面、真实截图、成功判据、故障处理；受邀版清楚说明 90 天限制。
- 公开 release 前检查许可、隐私、测试证据、SHA-256、签名边界及用户数据保护。

## 7. 待决策 / 待验证

| 问题 | 当前状态 | 验证责任 |
| --- | --- | --- |
| AGC AppTest 是否接受非官方 HiPDA 名称及当前内容 | 未知；既往正式上架有知识产权驳回 | M2 实际提交 |
| AppTest 人数上限究竟多少 | 官网开放式测试写内部 100 / 开放式 5000；AppTest 官方另写单任务 10000，需区分模式 | M2 控制台核对 |
| AppTest 是否支持目标用户地区及账号 | 未验证 | M2 |
| AppTest 包名是否可按候选值创建 | 未验证，禁止提前固化 | M2 |
| QSStore 能否完成 HiPDA·OH 端到端安装、续签 | 未验证 | M1 真机 |
| QSStore 私钥云端备份是否可关闭、默认数据流如何 | 已读到服务端加密保险库，但端到端用户权限流程未核对 | M1 |
| HoKit 能否沿用小白既有签名及覆盖旧版 | 未验证 | M1 |
| AppTest 与社区版能否保留/迁移相同本地数据 | 当前没有证据、备份关闭 | M4 |

## 8. 开始执行前的 Codex 任务定义

第一轮只执行 **M0**：确认代码/发布基线；整理真实证据；修正文档过期信息和失效链接；跑不涉及真机数据的测试；给出 M1/M2 的可验证最小改动建议。不要代替用户登陆 AGC，不要创建邀测、仓库 Release，不要使用个人签名私钥，不要安装/卸载手机应用。M0 完成后先汇报结果，**不自动进入 M1**。

## 9. 维护日志

- **2026-11-02（建立）**：核对新发布 `beta.6.1`；记录 beta.6 已有 GitHub 下载/导出实现、备份禁用、文档过期；决定 AppTest + GitHub/QSStore/HoKit 两渠道并行；Community 保留旧包名；制定 M0–M5 与验收矩阵。
- **下一次更新**：由 Codex 回填 M0 审计结果、测试证据、链接修复提交 SHA，以及各项新风险。只将经验证的事实标为“通过”；不同结论保留日期与来源。

## 10. 原有文档入口

[README](../README.md) · [首次安装](INSTALL.md) · [日常更新](UPDATE.md) · [续期与迁移](RENEWAL.md) · [更新器工程设计](UPDATER_DESIGN.md) · [构建方法](BUILD.md) · [更新记录](../CHANGELOG.md)
