# 发行与 Homebrew Cask

## 发布流程

推送格式为 `vX.Y.Z` 的标签后，`.github/workflows/release.yml` 会自动：

1. 校验标签版本与 `Support/Info.plist` 一致并运行测试。
2. 分别构建 arm64 和 x86_64 可执行文件，合成为通用应用。
3. 使用 ad-hoc 签名和 Hardened Runtime 签署应用。
4. 校验签名并生成 ZIP、SHA-256 和 GitHub Release。

该流程不需要 Developer ID、Apple 公证凭据或 Homebrew Tap Token。Release 包含：

- `miniTools-X.Y.Z.zip`
- `miniTools-X.Y.Z.zip.sha256`

## 发布版本

先更新 `Support/Info.plist` 中的 `CFBundleShortVersionString`，提交并确认 CI 通过，再创建标签：

```bash
git tag -a v0.1.0 -m "miniTools 0.1.0"
git push origin v0.1.0
```

标签必须使用 `vX.Y.Z`，并与 Info.plist 版本一致。`CFBundleVersion` 在 GitHub Actions
中使用当次 `GITHUB_RUN_NUMBER`，无需每次手动修改。

## Homebrew Tap

`omzcj/homebrew-omzcj` 中的 `minitools` Cask 固定下载对应版本的 GitHub Release。
Tap 的定时 Autobump 工作流发现新版本后，会自动创建更新 Cask 版本和 SHA-256 的 PR。

用户可执行：

```bash
brew install --cask omzcj/omzcj/minitools
```

## Gatekeeper

Release 使用 ad-hoc 签名，未经过 Apple 公证。macOS 首次启动时可能阻止运行；此时在
“系统设置 → 隐私与安全性”中为 miniTools 选择“仍要打开”。应用还需要辅助功能权限，
用于全局快捷键、Safari 窗口切换和窗口管理。

## 公开发行前检查

项目包含第三方图稿和商标相关素材。面向个人设备或私有分发的风险较小；提交 Homebrew
官方 Cask 或公开推广前，应替换为原创素材并复核 `THIRD_PARTY_NOTICES.md` 中的许可状态。
