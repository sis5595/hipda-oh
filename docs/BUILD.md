# 构建与测试

普通用户请先阅读 [README](../README.md)。本页供需要自行构建的开发者使用。

## 环境

- DevEco Studio 和 HarmonyOS 6.1.1（API 24）SDK。
- 使用 DevEco Studio 配套的 Node、Hvigor 和 SDK 编译器。
- 真机安装需要为自己的账号和设备生成签名。

## 构建

1. 克隆仓库，用 DevEco Studio 打开项目。
2. 将根目录的 `build-profile.example.json5` 复制为 `build-profile.json5`。
3. 同步项目依赖。模板不含签名；需要真机安装时，在 Studio 的“文件 → 项目结构 → 签名配置”中配置自己的签名，并关联 `default` 产品。
4. 在 Studio 构建 `entry` 模块的 `default` 产品。

也可用配套 Hvigor 构建。以下为 Windows 示例，请按实际安装位置调整：

```powershell
$devEcoRoot = 'D:\Program Files\DevEco Studio'
& "$devEcoRoot\tools\hvigor\bin\hvigorw.bat" --mode module -p product=default assembleHap --no-daemon
```

签名包位于 `entry/build/default/outputs/default/`。签名材料、真实构建配置、依赖和生成文件都不应提交到仓库。

## Beta 分发包与签名边界

- **GitHub Releases：未签名 HAP**，使用不含 `signingConfigs` 的公开构建模板，执行 release 模式构建：

  ```powershell
  & "$devEcoRoot\tools\hvigor\bin\hvigorw.bat" --mode module -p product=default -p buildMode=release assembleHap --no-daemon
  ```

  产物为 `entry/build/default/outputs/default/entry-default-unsigned.hap`。发布时命名为 `hipda-oh-<版本>-unsigned.hap`，同时记录 SHA-256。不要直接覆盖日常开发用签名配置；建议在独立的干净源码目录使用公开模板构建。
- **本机 Debug 签名包**：仅供签名 Profile 所绑定的开发设备调试，不上传到 Release，也不称为通用安装包。
- **AppGallery 正式发布包**：需要单独准备发布证书、发布 Profile 和平台审核材料；未签名 Beta 或设备调试包不能代替它。本项目当前尚未上架。

小白调试助手（[项目说明](https://github.com/likuai2010/auto-installer)、[版本与使用说明](https://github.com/likuai2010/auto-installer/releases)）支持导入 HAP 后签名安装。用户需自行满足工具要求的账号、开发者模式和设备绑定条件；签名到期需要续签。重新签名可能改变安装身份，无法覆盖已有不同签名的安装；不要为了验证流程直接卸载用户的日常应用。

`1.0.0-beta.2` 的未签名候选 HAP 已由维护者使用小白调试助手 **2.4.0** 在 **Mate 60** 上完成签名安装验证。其他设备的安装仍需满足相应系统版本和工具要求。

政策版本在 `FourD4yPrivacyPolicy.ets` 的 `FOUR_D4Y_PRIVACY_POLICY_VERSION` 统一维护，显示日期由它生成，同意存储引用同一版本。修改政策时还须同步 Markdown 政策；离线回归会校验日期、版本及联系方式一致性。

## 测试

本地单元测试：

```powershell
& "$devEcoRoot\tools\hvigor\bin\hvigorw.bat" --mode module -p product=default test --no-daemon
```

额外离线回归：

```powershell
& "$devEcoRoot\tools\node\node.exe" entry/src/test/node/run-regressions.cjs `
  "$devEcoRoot\sdk\default\openharmony\ets\build-tools\ets-loader\node_modules\typescript\lib\typescript.js"
```

这些测试使用合成数据，不向论坛发送请求。设备测试请使用独立测试环境；安装、替换或移除测试模块可能影响日常应用的登录会话。不要使用真实会话或私信作为测试文件。

本仓库中的构建模板不附带可供所有设备安装的签名，也不能直接替代应用商店发布签名。
