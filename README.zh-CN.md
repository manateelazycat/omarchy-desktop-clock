# Omarchy Desktop Clock

简体中文 | [English](README.md)

https://github.com/user-attachments/assets/7a5fbda6-b6e8-4cb1-bf4b-3e2f967ec501

Omarchy 终端风格桌面时钟，颜色跟随主题，多显示器共享拖拽位置。

## 功能

- 只在每个显示器当前的空工作区显示；打开应用窗口后，隐藏该显示器上的时钟。
- 颜色与字体跟随 Omarchy 主题；使用本地时间、24 小时制，显示秒数、日期和本地化的星期短名称，中文为“周一”至“周日”。
- 鼠标左键拖动即可定位；保存的相对位置在所有显示器与工作区间共享。
- 鼠标停住后不继续缓动；松开时保留同一个显示窗口，位置只保存一次。
- 位于壁纸上方，不预留屏幕空间，不获取键盘焦点；侧边任务栏和 Wave 等桌面图层不算应用窗口。
- 使用独立的软件渲染进程，将时钟渲染与 Omarchy、Wave 分开；所有显示器的当前工作区都有窗口时停止计时。

## 安装

需要 Omarchy（Quickshell）环境，以及使用 Lua 配置的 Hyprland。安装器还使用 Bash、Python 3、jq 和 GNU coreutils，Omarchy 已包含这些工具。

```sh
git clone https://github.com/manateelazycat/omarchy-desktop-clock.git
cd omarchy-desktop-clock
bash install.sh
```

安装器将配置备份到 `~/.local/state/omarchy/desktop-clock/backups/`，并将插件安装到 `~/.config/omarchy/plugins/io.github.manateelazycat.desktop-clock/`。
安装时添加时钟专用动画规则，重新加载 Hyprland 并检查配置错误；其他桌面动画保持当前设置。
设置了 `XDG_CONFIG_HOME` 或 `XDG_STATE_HOME` 时，使用对应目录。

更新代码并保持当前启用状态：

```sh
git pull
bash install.sh --no-enable
```

如果通过插件商店或 `omarchy plugin add` 安装，需要额外执行一次以下设置，添加时钟专用的 Hyprland 动画规则：

```sh
bash "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/io.github.manateelazycat.desktop-clock/install.sh" --no-enable
omarchy plugin enable io.github.manateelazycat.desktop-clock
```

## 卸载

```sh
omarchy plugin remove io.github.manateelazycat.desktop-clock
```

确认后，该命令会停止时钟并移除插件安装目录。对于未通过 Git 安装的目录，Omarchy 会先保留备份。
插件移除后，`~/.config/hypr/hyprland.lua` 中的受保护加载代码不再执行任何操作。如需一并清理，删除从 `-- >>> omarchy-desktop-clock >>>` 到 `-- <<< omarchy-desktop-clock <<<` 的整个代码块，然后执行 `hyprctl reload`。
配置备份保留在 `~/.local/state/omarchy/desktop-clock/backups/`，便于恢复。

## 配置

在 `~/.config/omarchy/shell.json` 的现有插件条目中调整：

```json
{
  "id": "io.github.manateelazycat.desktop-clock",
  "positionX": 0.5,
  "positionY": 0.52,
  "scale": 1,
  "opacity": 1
}
```

`positionX` 和 `positionY` 范围为 0–1：0 为左边缘或上边缘，1 为右边缘或下边缘，0.5 为居中。
`scale` 范围为 0.5–2，`opacity` 范围为 0.2–1；时钟保留 24 像素边距，小屏幕会自动缩小，保证完整可见。

拖动期间暂停秒数刷新，松开后恢复计时，位置保存一次并在登录后恢复。
当前显示器上的固定窗口，以及打开的特殊工作区内的窗口，也会使时钟隐藏。

设置或重置共享位置：

```sh
omarchy-shell desktop-clock setPosition 0.5 0.52
omarchy-shell desktop-clock resetPosition
```

## 启用或禁用

```sh
omarchy plugin disable io.github.manateelazycat.desktop-clock
omarchy plugin enable io.github.manateelazycat.desktop-clock
omarchy-shell desktop-clock status
```

禁用插件会停止渲染进程，并移除内联配置条目；安装备份保留之前的设置。
`status` 返回版本、渲染器 PID、保存的位置和各显示器的显示状态。
如果更新后仍返回旧版本，执行 `omarchy restart shell` 清除宿主的 QML 缓存。

## 开发

```sh
omarchy plugin validate .
node --test tests/position.test.cjs
bash tests/run-runtime.sh
python tests/bridge.py
python tests/stop.py --output profiles/current-drag-stop.json --expect-stable
```

运行时检查使用独立 Quickshell 进程和合成鼠标事件，不移动系统指针，不写用户设置。
Wave 并行测量与性能剖析结果见[性能报告](PERFORMANCE.md)。

## 许可证

[GPL-3.0-only](LICENSE)。Copyright (C) 2026 ManateeLazyCat.
