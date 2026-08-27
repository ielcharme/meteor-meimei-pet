# 边牧妹妹 · Meteor Meimei

> 把同一只「陨石边牧妹妹」带进 Codex，或者让她作为独立宠物在 macOS 桌面散步和玩耍。

![边牧妹妹待机动画](assets/pet/idle-preview.gif)

## 这是干嘛用的？

这个仓库把妹妹做成了一个可以安装和复用的 **Codex Skill**，并同时附带一款 **macOS 桌面宠物 App**。

它解决的是三件事：

1. 保存妹妹已经确认好的形象和动画，不必每次重新生成。
2. 让 Codex 知道怎样安全地安装、检查、修复和重新构建妹妹。
3. 让你可以直接把妹妹放到 Mac 桌面，她会自己走动，也可以被点击、拖动和召回。

妹妹是一只陨石纹边境牧羊犬：石墨黑、银灰和白色毛发，宇宙蓝眼睛，戴铜色名牌。当前版本已经处理拖动后的方向问题：拖动时使用完整待机帧，松手后挥爪，再继续散步，不会把向左跑的头部错误叠到身体上。

## 两种使用方式

| 你想要的效果 | 应该使用什么 | 她在哪里出现 |
| --- | --- | --- |
| 在 Codex 工作时显示妹妹，并跟随任务状态切换动画 | Codex v2 宠物 | Codex 界面内 |
| 让妹妹在电脑桌面底部自己左右散步和玩耍 | macOS 桌面 App | Mac 桌面，独立于 Codex |
| 两种效果都要 | 安装 `all` | Codex 和 Mac 桌面 |

这两个模式彼此独立：安装 Codex 宠物不会自动让她在 Mac 桌面散步；桌面 App 也不会读取你的 Codex 对话或任务内容。

## 最快开始：让妹妹在桌面散步

适用于 Apple Silicon Mac，系统要求 macOS 13 或更高版本。

```bash
git clone https://github.com/ielcharme/meteor-meimei-pet.git
cd meteor-meimei-pet

# 1. 检查 App、动画图集、架构和签名
./scripts/verify_assets.sh

# 2. 先查看将要安装到哪里；这一步不会修改文件
./scripts/install.sh --target desktop --dry-run

# 3. 安装到 ~/Applications/妹妹.app
./scripts/install.sh --target desktop --install

# 4. 启动妹妹
open "$HOME/Applications/妹妹.app"
```

启动后，妹妹会出现在当前屏幕底部并自动选择动作：

- 自己向左或向右散步
- 偶尔待机、挥爪、跳跃或玩耍
- 点击妹妹：立刻触发一次互动
- 水平拖动妹妹：把她放到新的位置；松手后她会挥爪
- 点击菜单栏的爪印：叫妹妹过来、和她玩、暂停散步、隐藏或退出

关闭窗口不会作为主要操作入口；要完全退出，请点击菜单栏爪印并选择「退出妹妹」。App 不会自动设置开机启动。

## 安装 Codex Skill

如果你希望以后直接对 Codex 说“安装妹妹”“检查妹妹”或“重新构建桌面妹妹”，先安装这个 Skill：

```bash
npx -y skills add https://github.com/ielcharme/meteor-meimei-pet
```

也可以手动安装：

```bash
git clone https://github.com/ielcharme/meteor-meimei-pet \
  "${CODEX_HOME:-$HOME/.codex}/skills/meteor-meimei-pet"
```

然后在新的 Codex 任务中这样调用：

```text
使用 $meteor-meimei-pet，把妹妹安装成我的 Codex 宠物。
使用 $meteor-meimei-pet，把妹妹安装成 macOS 桌面宠物并启动。
使用 $meteor-meimei-pet，同时安装 Codex 宠物和桌面宠物。
使用 $meteor-meimei-pet，检查妹妹的资源是否完整。
```

这个 Skill 会先验证仓库内的资源，再显示实际安装位置。写入 Codex 宠物目录或 `~/Applications` 前，它会请求确认；如果目标已经存在，不会静默覆盖。

## 不通过 Codex，直接使用安装脚本

所有安装命令都要在仓库根目录运行。

### 只安装 Codex 宠物

```bash
./scripts/install.sh --target codex --dry-run
./scripts/install.sh --target codex --install
```

安装位置：

```text
${CODEX_HOME:-$HOME/.codex}/pets/meteor-meimei
```

### 只安装桌面宠物

```bash
./scripts/install.sh --target desktop --dry-run
./scripts/install.sh --target desktop --install
```

安装位置：

```text
$HOME/Applications/妹妹.app
```

### 两个都安装

```bash
./scripts/install.sh --target all --dry-run
./scripts/install.sh --target all --install
```

### 更新已经安装的妹妹

默认情况下，只要目标位置已有文件，安装器就会停止。确认要更新后使用 `--replace`：

```bash
./scripts/install.sh --target all --install --replace
```

旧版本不会被删除，而是先移动到同级的时间戳备份，例如：

```text
meteor-meimei.backup-20260827-153000
妹妹.app.backup-20260827-153000
```

安装完成后可以再次验证：

```bash
./scripts/verify_assets.sh --installed all
```

## 常见问题

### 为什么安装了 Skill，桌面上却没有妹妹？

Skill 是给 Codex 使用的操作说明和资源包，不是正在运行的桌面程序。要让妹妹在桌面走动，还需要执行桌面安装命令并用 `open` 启动 App。

### 为什么桌面妹妹不会显示 Codex 的任务状态？

桌面 App 是一个独立、本地运行的小程序。她会自主玩耍，但不会读取 Codex 对话、屏幕内容或账户信息。

### 拖动妹妹后，她为什么回到屏幕底部？

妹妹的活动区域设计在当前屏幕底部。拖动用于调整她的水平位置；松手后她会回到底部基线并继续活动。

### 提示目标已经存在怎么办？

先确认现有版本是否需要保留。需要更新时加入 `--replace`，安装器会自动保留一份带时间戳的备份。

### 支持 Intel Mac 或 Windows 吗？

仓库内预编译的桌面 App 是 Apple Silicon `arm64` 版本，不支持 Windows。Codex 宠物资源本身不依赖桌面 App。

## 从源码重新构建桌面 App

需要 macOS 13 或更高版本，以及 Xcode Command Line Tools。

```bash
./scripts/build_desktop_app.sh
./scripts/verify_assets.sh --app dist/妹妹.app
```

输出文件位于 `dist/妹妹.app`。构建脚本使用系统 Cocoa 框架并执行本地 ad-hoc 签名；这适合本机使用，但不等于 Apple Developer ID 签名或 Apple 公证。

## 仓库里有什么？

```text
meteor-meimei-pet/
├── SKILL.md                         # Codex 使用的核心指令
├── agents/openai.yaml               # Skill 在 Codex 中的名称与默认提示
├── assets/
│   ├── pet/                         # Codex v2 图集、清单和 QA 预览
│   ├── desktop/妹妹.app             # 已构建的 Apple Silicon App
│   └── desktop-source/              # 可审查的 Objective-C 源码
├── references/asset-contract.md     # 动画行、尺寸和替换规则
└── scripts/
    ├── install.sh                   # 安装、预演、备份
    ├── verify_assets.sh             # 确定性检查
    └── build_desktop_app.sh         # 从源码构建 App
```

## 动画与安全说明

- Codex v2 图集：透明 WebP，`1536 × 2288`
- 网格：8 列 × 11 行，每格 `192 × 208`
- 动作：待机、左右跑、挥爪、跳跃、失败、等待、任务中、检查和 16 个注视方向
- 桌面 App：`arm64`，Bundle ID `com.lucie.meteor-meimei`
- 无网络请求、遥测、账户读取或凭据存储
- 不申请辅助功能、录屏、麦克风或摄像头权限
- 不创建开机启动项

修改角色外观或动画时，应使用 `$hatch-pet` 完整更新对应动画行并重新执行视觉 QA。不要把不同版本的单帧或头部拼进现有图集。详细规格见 [`references/asset-contract.md`](references/asset-contract.md)。

<details>
<summary>查看全部动画帧</summary>

![边牧妹妹动画总览](assets/pet/contact-sheet.png)

</details>

## 授权说明

仓库当前没有附加开源许可证。公开可见不代表获得复制、改编、再发布或商业使用授权；如需开放授权，应由作者之后明确选择并添加许可证。

## English summary

Meteor Meimei is Lucie's reusable Codex v2 pet package and a separate local-only macOS desktop companion. Install the Skill when you want Codex to manage, verify, or restore the pet. Install the desktop app when you want Meimei to roam along the bottom of your Mac screen, react to clicks and horizontal dragging, and expose pause, hide, recall, play, and quit controls from the menu bar.
