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
