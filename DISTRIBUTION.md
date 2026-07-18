# 发行与 Homebrew Cask

## 发布产物

推送格式为 `vX.Y.Z` 的标签后，`.github/workflows/release.yml` 会执行以下流程：

1. 校验标签版本与 `Support/Info.plist` 一致并运行完整测试。
2. 分别构建 arm64 和 x86_64 可执行文件，再合成为通用二进制。
3. 使用 Developer ID Application 证书和 Hardened Runtime 签名。
4. 使用 App Store Connect API Key 提交 Apple 公证并等待结果。
5. 将公证票据装订到应用，重新生成 ZIP 和 SHA-256。
6. 生成与该版本、校验和一致的 `minitools.rb`。
7. 为 ZIP 创建 GitHub 构建来源证明并发布 GitHub Release。

Release 包含：

- `miniTools-X.Y.Z.zip`
- `miniTools-X.Y.Z.zip.sha256`
- `minitools.rb`

## Apple 侧配置

需要有效的 Apple Developer Program 会员资格，并准备：

- `Developer ID Application` 证书及其私钥，导出为带密码的 `.p12`。
- App Store Connect API Key 的 Key ID、Issuer ID 和下载一次后妥善保存的 `.p8` 私钥。

将 `.p12` 转为 Base64 后复制：

```bash
base64 -i DeveloperID.p12 | pbcopy
```

在 GitHub 仓库的 `Settings → Secrets and variables → Actions` 中添加：

| Secret | 内容 |
| --- | --- |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | `.p12` 的 Base64 内容 |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | 导出 `.p12` 时设置的密码 |
| `APPLE_API_KEY_ID` | App Store Connect API Key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect Issuer ID |
| `APPLE_API_PRIVATE_KEY` | `.p8` 文件的完整文本，包括首尾标记 |

流水线只在标签发布任务中导入证书，并使用临时 Keychain；任务结束后会删除临时证书和私钥文件。

## 发布版本

先更新 `Support/Info.plist` 中的 `CFBundleShortVersionString`，提交并确认 CI 通过，再创建标签：

```bash
git tag v0.1.0
git push origin v0.1.0
```

标签必须严格使用 `vX.Y.Z`，并与 Info.plist 版本一致。`CFBundleVersion` 在 GitHub Actions
中使用当次 `GITHUB_RUN_NUMBER`，无需每次手动修改。

## Homebrew Tap

建议单独创建 `omzcj/homebrew-tap` 仓库，并将 Release 中生成的 `minitools.rb` 放到其
`Casks/minitools.rb`。Homebrew 对 Tap 仓库使用 `homebrew-` 前缀，用户即可执行：

```bash
brew install --cask omzcj/tap/minitools
```

Cask 模板位于 `Packaging/Homebrew/minitools.rb.template`，发布脚本会自动写入版本与
ZIP 的 SHA-256。创建 Tap 后，可以再给 Release 工作流增加一个仅能写入
`omzcj/homebrew-tap` 的细粒度 Token，实现自动更新 Cask。

## 公开发行前检查

以下事项不会阻塞 CI，但应在首次公开 Release 前解决：

1. 项目原创代码使用 MIT License，但该许可不包含第三方图稿或相关商标。
2. 锤子图标基于 Smartisan 标志，仓库中没有商标或图稿再分发授权。
3. `THIRD_PARTY_NOTICES.md` 中列出的 Fugaku 图稿没有明确的逐文件许可信息。
4. 写轮眼相关角色和设计的知识产权不因 SVG 文件采用 CC BY-SA 而自动获得授权。

如果 Release 只用于个人设备或私有分发，上述风险范围较小；提交 Homebrew 官方 Cask 或向
公众推广前，建议替换为原创图标与原创动画素材，并复核第三方许可状态。
