# 边牧妹妹 · Meteor Meimei

![边牧妹妹动画总览](assets/pet/contact-sheet.png)

这是「陨石边牧妹妹」的独立 Codex Skill 仓库。它不只是提示词：仓库内包含已经验证的 Codex v2 宠物图集、透明桌面宠物 App、可审查的 macOS 源码，以及默认不覆盖现有文件的安装与验证脚本。

妹妹是一只陨石纹边境牧羊犬：石墨黑、银灰和白色毛发，宇宙蓝眼睛，戴一枚铜色名牌。她会在桌面左右散步、发呆、挥爪、跳跃和玩耍；点击她会互动，拖动后会稳定落地，不会再出现头部分层。

## 仓库内容

- `SKILL.md`：Codex 执行边界和标准工作流
- `assets/pet/`：Codex v2 宠物文件及视觉 QA 预览
- `assets/desktop/妹妹.app`：Apple Silicon macOS 桌面宠物
- `assets/desktop-source/`：桌面宠物 Objective-C 源码与 `Info.plist`
- `scripts/install.sh`：带预演、拒绝静默覆盖和自动备份的安装器
- `scripts/verify_assets.sh`：检查清单、图集尺寸、App 架构及签名
- `scripts/build_desktop_app.sh`：从源码重新构建本地 App

## 安装这个 Skill

推荐通过 Skills CLI 安装：

```bash
npx -y skills add https://github.com/ielcharme/meteor-meimei-pet
```

也可以克隆到 Codex Skills 目录：

```bash
git clone https://github.com/ielcharme/meteor-meimei-pet \
  "${CODEX_HOME:-$HOME/.codex}/skills/meteor-meimei-pet"
```

安装后可以这样使用：

```text
使用 $meteor-meimei-pet 把边牧妹妹安装成我的 Codex 宠物。
使用 $meteor-meimei-pet 把妹妹安装成 macOS 桌面宠物并启动。
使用 $meteor-meimei-pet 检查妹妹的资源是否完整。
```

## 安装妹妹

先在仓库根目录验证资源：

```bash
./scripts/verify_assets.sh
```

安装前先预演；预演只显示目标位置，不写入文件：

```bash
./scripts/install.sh --target codex --dry-run
./scripts/install.sh --target desktop --dry-run
./scripts/install.sh --target all --dry-run
```

确认路径后执行安装：

```bash
./scripts/install.sh --target codex --install
./scripts/install.sh --target desktop --install
./scripts/install.sh --target all --install
```

默认目标：

- Codex 宠物：`${CODEX_HOME:-$HOME/.codex}/pets/meteor-meimei`
- 桌面宠物：`$HOME/Applications/妹妹.app`

如果目标已经存在，安装器会停止。只有明确加入 `--replace` 才会替换；替换前，旧版本会被移动到同级的时间戳备份目录。

```bash
./scripts/install.sh --target all --install --replace
```

安装后验证：

```bash
./scripts/verify_assets.sh --installed all
```

启动或退出桌面妹妹：

```bash
open "$HOME/Applications/妹妹.app"
```

退出时点击 macOS 菜单栏的爪印图标，选择「退出妹妹」。App 不联网、不上传数据、不创建登录启动项，也不请求辅助功能、录屏、麦克风或摄像头权限。

## 从源码构建桌面 App

需要 macOS 13 或更高版本、Apple Silicon，以及已安装的 Xcode Command Line Tools。

```bash
./scripts/build_desktop_app.sh
./scripts/verify_assets.sh --app dist/妹妹.app
```

构建脚本使用系统 Cocoa 框架，并进行本地 ad-hoc 签名。该签名适合本机使用，不等同于 Apple Developer ID 签名或公证。

## 动画规格

- `spriteVersionNumber`: `2`
- 图集：透明 WebP，`1536 × 2288`
- 网格：8 列 × 11 行，每格 `192 × 208`
- 基础动作：待机、向右、向左、挥爪、跳跃、失败、等待、任务中、检查
- 注视动作：16 个顺时针方向，每次 22.5°
- 桌面 App：arm64，Bundle ID `com.lucie.meteor-meimei`

详细资源契约见 [`references/asset-contract.md`](references/asset-contract.md)。修改角色外观或动画时，应使用 `$hatch-pet` 完整重做对应动画行并重新执行视觉 QA，不能只拼接单个方向或混用不同版本的头部。

## 发布与授权说明

仓库当前没有附加开源许可证。公开可见不代表获得复制、改编、再发布或商业使用授权；如需开放授权，应由作者之后明确选择并添加许可证。

## English summary

Meteor Meimei is Lucie's verified Codex v2 animated border-collie pet and optional local-only macOS desktop companion. This repository includes the skill instructions, validated sprite atlas, preview assets, prebuilt Apple Silicon app, auditable Objective-C source, safe installer, verifier, and rebuild script. See the Chinese sections above for the complete installation and safety details.
