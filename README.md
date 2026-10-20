# WorkBuddy 积分小组件

适用于 macOS 的 WorkBuddy 积分菜单栏应用和桌面小组件。打开桌面即可查看剩余积分、已用量与当前套餐，提供深色卡片和浅色纸张两种样式。

**非腾讯官方项目。** 本项目不隶属于腾讯，也未获得腾讯背书。WorkBuddy 名称归其权利人所有。当前为社区测试版，官网接口变化可能导致查询失效。

![两种卡片样式，均为示例数据](docs/preview.png)

[下载测试版](https://github.com/sanliqingfeng3378-star/workbuddy-credit-widget/releases) · [报告问题](https://github.com/sanliqingfeng3378-star/workbuddy-credit-widget/issues) · [English](docs/README.en.md)

## 系统要求

- macOS 14 Sonoma 或更新版本，Apple 芯片或 Intel Mac。
- 一个能登录 [WorkBuddy 官网](https://www.workbuddy.cn) 的账号。
- 运行时无需安装 Python、Node.js 或 Xcode。小组件需要配套应用保持运行。

## 安装与使用

1. 从 Releases 下载 `WorkBuddy-Credits-版本-macOS-universal.zip`，解压后将 **WorkBuddy Credits.app** 拖入“应用程序”。
2. 打开应用。当前版本使用临时签名，**尚未经过 Apple 开发者签名及公证**。macOS 可能阻止启动；确认文件来源后，按照系统“隐私与安全性”中的提示操作。也可以自行从源码构建。不要关闭系统安全保护。
3. 点击“打开官网登录”，在内置窗口登录与 WorkBuddy 客户端相同的账号，再点击“立即刷新”。每位使用者都需要自行登录。
4. 右键桌面 → 编辑小组件 → 搜索“WorkBuddy 积分”，选择深色或纸张样式，支持小号和中号。
5. 可以关闭主窗口，但请保持菜单栏应用运行。需要开机启动时，打开菜单栏或积分面板中的“设置”，开启“开机自启动”。如果提示等待系统允许，可直接打开系统登录项设置。

下载包附有 SHA-256 校验文件，可在下载目录运行 `shasum -a 256 -c 文件名.zip.sha256` 核对完整性。校验值不能替代开发者签名。

## 设置面板

从菜单栏卡片、积分面板右上角的“设置”，或快捷键 `⌘,` 打开设置。

- **开机自启动**：使用 macOS 的登录项服务，显示系统实际状态；默认不替你开启。系统要求允许或注册失败时会给出提示。
- **启动时显示积分面板**：关闭后，下次启动仅保留菜单栏入口；仍可从菜单栏打开面板。应用不显示 Dock 图标。
- **菜单栏显示剩余积分**：关闭后保留 WB 图标与入口，隐藏菜单栏数值。
- **定时自动刷新**：可以暂停定时查询，间隔可选 1、5、10、15 分钟，默认 5 分钟。
- **电脑唤醒后刷新**：独立开关，关闭定时刷新时仍可按需保留唤醒同步。

设置立即保存到当前 Mac，无需重启；“启动时显示积分面板”在下次启动生效。关闭定时刷新不会禁用启动、官网登录完成或手动刷新。

## 多久更新一次？

主应用启动、登录完成、手动刷新和电脑唤醒后会尝试同步；运行期间每分钟检查一次，距离上次查询达到设置的间隔后再次查询，默认 **5 分钟**。错误重试也遵守所选间隔，避免持续失败时频繁请求。睡眠或应用退出期间不会查询。

小组件请求约 5 分钟后的下一次时间线，实际更新时机由 macOS 调度，可能延后，并非秒级实时。界面的同步时间表示最近一次成功获取数据的时间；超过 15 分钟的快照会标为待更新。

“已用”和“总量”来自官网当前积分资源汇总，可能包含订阅和活动赠送，**不表示今天或本月的消费金额**。积分也不是人民币。

## 隐私与数据

- 登录发生在内置 WebKit 窗口中的官网，Cookie 由 WebKit 保存在本机；应用不读取或解密 WorkBuddy 客户端的登录文件。
- 查询仅针对当前账号与积分。不购买、不签到、不提交 WorkBuddy 任务，没有自建后台、统计服务或遥测。
- 本地缓存仅含积分快照与状态信息。登录失效或检测到账号变化时清除读数；网络异常时保留旧快照并显示错误，不会将错误伪装成 0 积分。
- 桌面扩展通过 `127.0.0.1:38348/v1/credits` 读取主应用的快照，服务仅监听本机回环地址，不传递 Cookie、密码或令牌。**同一台电脑上的本地进程仍可读取积分快照**，请勿在不受信任的共享账号环境中使用。
- 公开截图与测试数据都是虚构示例。提交 issue 前请遮盖账号、余额、二维码及任何登录信息。

更多缓存和卸载说明见 [隐私说明](docs/PRIVACY.md)。

## 已知限制与排障

- 个人账号已在开发机器验证；企业账号解析有合成数据测试，尚未用真实企业账号联调。
- 通用二进制包含 arm64 和 x86_64。macOS 14 是最低编译目标，并不代表所有系统版本和机型均已实机验证。
- 官网接口不是对第三方承诺稳定的公共 API；如果官网改版，请提交经过脱敏的问题描述。
- 卡片没有读数：先确认主应用正在运行、官网登录有效，然后手动刷新。不要同时运行两个版本，它们会争用同一个本地端口。
- 更新后卡片仍显示旧样式或空白：macOS 可能仍在运行旧扩展。源码用户可运行 `bash scripts/reload-widget.sh` 后在主应用点击“立即刷新”，重新加载 WorkBuddy 扩展且保留卡片位置。也可以注销再登录 macOS。仍不正常时，再移除旧卡片并重新添加。
- 从早期本机测试版（1.0.x）升级：公开版使用新的应用标识，可能需要重新登录并重新添加卡片；请先退出旧版。

## 从源码构建

需要 macOS、Apple Command Line Tools（或完整 Xcode）、包含 SwiftUI/WidgetKit 的 macOS 14+ SDK、Python 3。使用系统提供的框架，无第三方运行依赖。

```sh
git clone https://github.com/sanliqingfeng3378-star/workbuddy-credit-widget.git
cd workbuddy-credit-widget
bash scripts/test.sh
bash scripts/build.sh                 # 默认构建 Apple 芯片 + Intel 通用包
bash scripts/package.sh               # 输出 zip 和 sha256 到 dist/
```

应用输出：`build/universal/WorkBuddy Credits.app`。只构建一种架构时，给构建与打包脚本传入 `arm64` 或 `x86_64`。可用 `WORKBUDDY_WIDGET_SDK` 指定 SDK 路径；默认临时签名，需要自行配置开发者签名时使用 `WORKBUDDY_SIGN_IDENTITY`。指定签名身份并不会自动完成公证，发布说明见 [RELEASING.md](docs/RELEASING.md)。

源码结构：`App/` 管理官网会话和本地快照服务；`Shared/` 提供积分解析与卡片视图；`Widget/` 提供 WidgetKit 时间线；`Tests/` 包含解析和本地请求校验测试。`scripts/RenderPreview.swift` 只使用固定示例数据生成预览。

## 贡献与许可证

欢迎提交问题和改进，参见 [贡献说明](CONTRIBUTING.md)。源码和原创图标采用 [MIT License](LICENSE)。本项目的许可证不授予腾讯商标或官网内容的权利。

卡片呈现思路受到桌面用量小组件与 [codex-limit-widget](https://github.com/sergeylopukhov/codex-limit-widget) 的启发；本项目不分发其他应用的程序、品牌图标或账号数据。
