# 发布流程

1. 更新 `VERSION`（三段数字）、`BUILD_NUMBER`（递增整数）与 `CHANGELOG.md`。
2. 运行模型/请求校验测试，构建 universal 应用，验证签名与两种架构。公开预览只能使用 `CreditSnapshot.preview`。
3. 推送到 GitHub，等待 CI 通过。CI 会测试 Apple 芯片与 Intel 运行器，并提供临时签名通用构建产物。
4. 在 GitHub 创建与 VERSION 一致的 `v版本` 标签及预发布 Release，上传 `scripts/package.sh` 生成的 ZIP 和 SHA-256 文件。标明是否公证、实机验证范围和已知限制。

发布包目前是临时签名，没有开发者身份验证及 Apple 公证。不要在说明中称它为已公证正式版。未来若使用 Developer ID，先设置 `WORKBUDDY_SIGN_IDENTITY` 构建，再按 Apple 官方流程使用自己的凭据进行公证、装订票据，最后重新打包并生成校验值。证书、私钥和公证凭据不得进入 Git 历史。

源代码归档应来自 Git 跟踪文件，不要直接压缩开发目录；开发目录的 build/ 可能含私有诊断文件。应用分发包只包含新构建的 .app，不包含登录会话或本地缓存。
