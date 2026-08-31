# FullTimeMagic

一款使用 Godot 引擎开发的 2D 角色扮演游戏（RPG）。

## 环境要求

- [Godot 4.7+](https://godotengine.org/download)（标准版即可，无需安装，下载解压即用；项目使用 GDScript，不是 .NET 版）
- 命令行已配置：`godot` 打开编辑器，`godot_console` 用于终端中查看日志输出（安装目录已加入用户 PATH）
- Git 2.28+

## 快速开始

```bash
git clone <仓库地址>
cd FullTimeMagic
```

然后用 Godot 打开项目根目录下的 `project.godot`，按 `F5` 运行即可看到主场景。

## 目录结构

项目按「功能」组织（同一功能的场景与脚本放在同一目录），这是 Godot 社区推荐的做法：

```
FullTimeMagic/
├── project.godot        # 项目配置（入口场景、autoload、输入映射等）
├── icon.svg             # 项目图标
├── autoload/            # 全局单例（自动加载，全局唯一）
│   ├── game_events.gd   #   GameEvents：全局事件总线（信号）
│   └── game_state.gd    #   GameState：全局游戏状态
├── src/                 # 游戏代码（场景 + 对应脚本，按功能分目录）
│   ├── main/            #   主场景
│   ├── player/          #   玩家
│   ├── world/           #   世界 / 关卡
│   └── ui/              #   界面（背包、对话框、HUD 等）
├── assets/              # 原始素材
│   ├── audio/           #   音乐与音效
│   ├── fonts/           #   字体
│   ├── sprites/         #   角色与物件图片
│   └── tilemaps/        #   瓦片地图与图块集
├── resources/           # 自定义 .tres 资源（物品、技能、对话等数据）
├── shaders/             # 着色器
├── themes/              # UI 主题
├── addons/              # 第三方插件
└── docs/                # 设计与开发文档
```

## 开发规范

### 命名

- 文件与目录：`snake_case`（Godot 官方风格）
- 节点：`PascalCase`
- autoload 单例：文件 `snake_case`，注册名 `PascalCase`（如 `GameEvents`）
- GDScript 代码遵循[官方风格指南](https://docs.godotengine.org/zh-cn/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)：缩进使用 Tab，函数与变量 `snake_case`，类名 `PascalCase`

### 场景与脚本

- 一个功能 = 一个场景 + 一个同名脚本，放在同一目录（如 `src/player/player.tscn` + `player.gd`）
- 跨场景通信使用 `GameEvents` 信号总线，避免节点间直接持有引用
- 需要全局访问的数据放入 `GameState`，不要用全局变量散落各处

### 资源

- 素材按类型放入 `assets/` 对应子目录
- 不要提交 `.godot/` 目录（已在 `.gitignore` 中排除）
- 不要手动编辑 `*.import` 文件，导入参数在编辑器的 Import 面板中修改
- 使用 Git LFS 管理大型二进制资源（如需，运行 `git lfs install` 后配置）

## Git 工作流

- `main`：稳定可运行的版本，只接受经过验证的合并
- 功能开发使用 `feat/<功能名>` 分支，例如 `feat/player-movement`
- 提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/)：
  - `feat:` 新功能
  - `fix:` 修复缺陷
  - `docs:` 文档
  - `refactor:` 重构（不改行为）
  - `art:` / `assets:` 美术与音频资源
  - `chore:` 构建与杂项

## 其他说明

- 渲染方式当前为 **gl_compatibility**（2D 项目足够，且对低端设备和 Web 导出友好）；如需 Forward+ 高级特效，可在项目设置中改回
- 如果使用像素美术，建议在「项目设置 → 渲染 → 纹理 → Canvas Textures → Default Texture Filter」中改为 **Nearest**，并把窗口大小调整为整数倍缩放
- 输入映射已在 `project.godot` 中预定义：`WASD/方向键` 移动、`E` 交互、`空格/J` 攻击、`I/Tab` 背包、`Esc` 暂停
