# 高清立绘资产规格（2D 动漫画风）

> 状态：已定案（2026-09-06）。
> 用途：衣柜「穿着预览」与战斗立绘的高清化。地图行走、瓦片、战斗小人**保持像素风**不变。
> 管线已就绪：PNG 按本规格放进 `assets/images/art/` 即自动生效，无需改代码；图缺失时自动回落像素占位。

## 目录与命名

```
assets/images/art/
  mo_fan/
    base.png                  # 基础身体（内衣打底，无外衣）
    portrait.png              # 战斗立绘（可选，缺失用像素占位）
    cloth_knight_hat.png      # 与衣装 id 同名：一衣一图
    cloth_mage_top.png
    ...
  mu_ningxue/
    base.png
    portrait.png
    cloth_xue_maid.png
    ...
```

- 文件名 = 衣装 id（见 `resources/clothes/*.tres`，也在杂货铺货架上）。
- 归属由目录决定：莫凡的衣服放 `mo_fan/`，穆宁雪的放 `mu_ningxue/`，不可混放。

## 尺寸与画布

| 用途 | 尺寸 | 说明 |
|---|---|---|
| base / 衣装部件 | **768 × 1152**（2:3）透明 PNG | 全身站姿，预览缩放显示 |
| portrait（战斗立绘） | **768 × 1152** 透明 PNG | 半身或全身均可，战斗中缩放显示 |

- 统一 **RGBA 透明底**；身体与每件衣装**各自独立一张图**（分层纸娃娃）。
- 游戏内预览约 216×324 显示（高清线性过滤），768 宽足够细腻，不必更大。

## 对齐规则（分层纸娃娃的命门）

1. **所有层共用同一张画布、同一个站姿、同一个位置**——先定稿 `base.png`，之后每件衣装都以 base 垫底对照绘制，确保穿上后严丝合缝。
2. 锚点约定：**角色人体中线对齐画布横向中心；脚底距画布底边 32px**。
3. 各层只画自己覆盖的区域，其余透明：
   - `dress`（连衣裙）：躯干 + 裙摆（会遮住 top/pants，露出小腿）
   - `top` / `pants`：躯干 / 下装，与连衣裙互斥穿着
   - `hosiery`（腿袜）：小腿 + 鞋
   - `hat`：头部饰件
4. 部位遮盖关系由游戏按 渲染顺序自动处理（腿袜 → 下装 → 上装 → 连衣裙 → 帽），出图时不必考虑遮挡。

## AI 出图小抄

- 先出 `base.png`：提示词强调「full body, standing, front view, simple pose, transparent background, anime style, 全职法师风格」；不满意先调到满意再动衣装。
- 衣装层用 **base 垫底重绘（img2img，低强度）**，只改衣服区域——站姿与位置自然对齐。
- 生成后抠底去背（透明 PNG），按上面命名放进目录即可，游戏刷新即见。

## AI 提示语模板（莫凡 base，已定稿 2026-09-06）

### 中文版（即梦 / 通义万相 / 豆包等）

```
2D动漫风格全身立绘，全职法师风格的少年魔法师莫凡：黑色微乱短发、
额前碎发，深蓝色眼眸，剑眉，眉目俊朗带一点桀骜的少年感，身形清瘦
但结实。身穿纯灰色紧身背心和灰色运动短裤（纯色无图案无装饰），赤足，
双手自然垂于身侧微张，双脚分开与肩同宽，全身正面站姿。
平涂上色的日式赛璐璐画风，线条干净，脸部细节精细。
纯白背景，单人全身，头部到脚完整入画，人物居中。
```

### 英文版（SD / NovelAI / MJ 等）

```
full body anime illustration, teenage mage boy (Mo Fan from Quanzhi Fashi
style), messy black short hair with bangs, dark blue eyes, sharp brows,
handsome slightly rebellious look, lean fit build, wearing only a plain
grey tank top and plain grey sport shorts, barefoot, bare arms, standing
front view, arms relaxed at sides slightly apart, feet shoulder-width,
flat cel shading, clean lineart, detailed face, simple anime style,
pure white background, single character, head-to-toe full body, centered
```

### 负面提示词（通用）

```
鞋子，袜子，帽子，饰品，项链，外套，多余衣物，复杂图案，多人，半身，
裁切肢体，文字，水印，背景杂物，写实风格，3D渲染
```

### 参数与操作要点

1. **比例 2:3，出图 768×1152**（或更大再缩放）；MJ 加 `--ar 2:3`
2. AI 多数不能直接出透明底——先生成纯白底，再用抠图工具去背，存透明 PNG
3. **保存种子与参数**——衣装层全部依赖「base 垫底重绘」，base 的姿势定稿后不可再改
4. 打底刻意用灰色素色：任何颜色的衣装叠上去都不脏；赤足是因为鞋归腿袜/下装层

## 衣装层提示语模板（基于 base 图生图）

把 base 提示语中的**衣服描述段**替换为目标服装，其余（站姿/构图/画风/负面词）原样保留，
以 base.png 为底图走 **图生图（img2img）**：

```
（前半段角色描述不变）……身穿【目标服装描述】，赤足，
双手自然垂于身侧微张，双脚分开与肩同宽，全身正面站姿。（后半段不变）
```

示例（女仆装）：`……身穿黑白女仆装配白色围裙与蕾丝边，赤足，……`
示例（君王华服）：`……身穿金色帝王长袍配大红披风与紫宝石胸饰，……`

### 图生图六步工作流

1. **垫底**：把 base.png（白底版）作为图生图的参考图/初始图
2. **重绘幅度**：0.3–0.5——低了衣服改不动，高了姿势会漂移
3. **提示词**：按上面模板只替换服装描述段；**锁定 seed**（与 base 相同）
4. **对齐自检**：把生成图与 base.png 半透明叠放对比——头、手、脚位置重合才算过；不重合回第 2 步调幅度
5. **裁层（最关键）**：AI 画的是"穿着衣服的完整人物"，而衣装层只需要**衣服覆盖的区域**——把脸、手臂、腿等 base 已有的部分**擦成透明**，只留衣服。各槽位保留范围：
   | 槽位 | 保留 | 擦除 |
   | ---- | ---- | ---- |
   | hat | 头部饰件 | 其余全部 |
   | top | 躯干 + 袖 | 头、下装以下 |
   | pants | 腰 → 鞋 | 头、躯干、手臂 |
   | dress | 躯干 + 裙摆 | 头、手臂、裙摆外的小腿 |
   | hosiery | 小腿 + 鞋 | 其余全部 |
6. **入库**：存成透明 PNG（`assets/images/art/<角色>/<衣装id>.png`），跑一次 `--import`，开衣柜即见

### 对齐自检的土办法

任意看图工具（或免费 Photopea）里把衣装图叠在 base.png 上调 50% 透明度：
头、双手、双脚三处与 base 重合即为合格；领口/裙腰与 base 的背心、短裤边缘衔接自然即为合格。

## 现状与回落

- 任何目录为空 / 图缺失：预览与立绘自动使用现有像素占位（双轨兜底）。
- 允许只出部分图：有 base 就切高清轨，缺哪件衣装那层就显示内衣打底；portrait 单独可选。
