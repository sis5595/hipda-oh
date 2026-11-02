# HiPDA·OH

一个原生鸿蒙版的 **4D4Y 非官方客户端**，希望把 HiPDA·NG 熟悉、顺手的论坛体验带到鸿蒙手机和平板上。

本项目以 NG 为主要参考，尽量对齐它的界面布局、操作习惯和日常功能，并结合鸿蒙系统做适当调整。它由社区爱好者维护，与 4D4Y 官方没有隶属关系。

## 下载

当前版本：**1.0.0-beta.6.1**。

本次更新：

- 平板和折叠屏内屏增加左侧列表、右侧正文的双栏布局。
- 拖动分隔线可调整左右栏宽，并记住比例。
- 窄窗口自动使用单栏；回复、编辑和查看大图时使用全宽。
- 调整双栏下的返回、抽屉关闭和页码弹窗。

从 [GitHub Releases](https://github.com/sis5595/hipda-oh/releases/tag/v1.0.0-beta.6.1) 下载未签名 HAP 安装包 `hipda-oh-1.0.0-beta.6.1-unsigned.hap`；源码 ZIP 不是安装包。历次更新见[更新记录](CHANGELOG.md)。

当前构建面向 HarmonyOS 6.1.1 及以上的原生鸿蒙设备，不适用于 Android。

## 可以做什么

- 浏览版面和帖子，下拉刷新、滚动加载，调整排序和置顶帖显示。
- 阅读引用并跳转楼层，查看原图、缩放和切换多图，保存或分享图片，下载附件。
- 发主题、快速回复、引用回复、上传多图，以及编辑或删除自己的帖子。
- 搜索标题、全文和作者，查看自己的主题与回复，管理收藏、关注和黑名单。
- 收发私信、查看帖子提醒，切换多个账号，调整主题、字号和行距。
- 设置发帖小尾巴，在“关于”中查看版本和项目链接。

各项操作仍受论坛规则和账号权限限制。消息提醒显示在应用内，目前不提供后台系统推送。

## 隐私与反馈

应用没有广告和统计 SDK，不读取或保存论坛密码。已保存账号的会话由鸿蒙系统安全存储保护；具体说明见[隐私政策](docs/PRIVACY_POLICY.md)。

遇到问题可在 [Issues](https://github.com/sis5595/hipda-oh/issues) 中反馈，说明操作步骤、手机型号和系统版本。截图前请遮住私信、账号等个人信息。联系邮箱：sis5595@gmail.com。

## 致谢

特别感谢 **[HiPDA·NG](https://github.com/GreenSkinMonster/hipda)** 的作者与贡献者。NG 多年积累的界面设计、功能和论坛适配经验，是本项目最重要的参考，也奠定了本项目希望对齐的使用体验。

感谢 MY 4D4Y、[Re:Source](https://github.com/kenischu/ReSource) 等论坛客户端带来的参考，以及鸿蒙和 OpenHarmony 开发者社区分享的经验。内部界面图标采用 [Google Material Icons](https://github.com/google/material-design-icons)。

## 开源协议

本项目采用 [GPL-3.0-or-later](LICENSE)。第三方素材的来源与许可见[第三方声明](THIRD_PARTY_NOTICES.md)。
