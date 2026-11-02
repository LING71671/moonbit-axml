---
name: MoonAXML
description: 用于检查二进制 XML 的暖色深色工作台。
colors:
  ground: "#24231f"
  plate: "#292823"
  ink: "#ece5d4"
  muted: "#b6ac98"
  faint: "#8e8573"
  rule: "#615743"
  soft-rule: "#443e32"
  accent: "#ce6857"
  accent-hover: "#df806f"
typography:
  display:
    fontFamily: "Alegreya, Georgia, serif"
    fontSize: "2.15rem"
    fontWeight: 500
    lineHeight: 1
    letterSpacing: "-0.035em"
  headline:
    fontFamily: "Alegreya, Georgia, serif"
    fontSize: "1.5rem"
    fontWeight: 400
    lineHeight: 1.15
  title:
    fontFamily: "Alegreya, Georgia, serif"
    fontSize: "1.25rem"
    fontWeight: 400
  label:
    fontFamily: 'Arial, "Noto Sans SC", "Microsoft YaHei", sans-serif'
    fontSize: "0.875rem"
  data:
    fontFamily: '"SFMono-Regular", Consolas, "Liberation Mono", monospace'
    fontSize: "0.875rem"
    lineHeight: 1.9
  metadata:
    fontFamily: '"SFMono-Regular", Consolas, "Liberation Mono", monospace'
    fontSize: "0.75rem"
    lineHeight: 1.6
  search:
    fontFamily: 'Arial, "Noto Sans SC", "Microsoft YaHei", sans-serif'
    fontSize: "1rem"
spacing:
  compact: "0.75rem"
  standard: "1rem"
  section: "1.5rem"
  folio-inline: "1.6rem"
components:
  button-primary:
    backgroundColor: "#b34e3e"
    textColor: "#fff4df"
    typography: "{typography.label}"
    padding: "0.65rem 1rem"
  button-primary-hover:
    backgroundColor: "#9e4134"
  button-primary-active:
    backgroundColor: "#a14638"
  button-text:
    textColor: "{colors.muted}"
    typography: "{typography.label}"
    padding: "0.4rem 0.2rem"
  folio:
    backgroundColor: "{colors.plate}"
    textColor: "{colors.ink}"
  tab-selected:
    textColor: "{colors.ink}"
  table-search:
    backgroundColor: "{colors.ground}"
    textColor: "{colors.ink}"
    typography: "{typography.search}"
    padding: "0.65rem 0.8rem"
---

# 设计系统：MoonAXML

[English](DESIGN.md)

## 概述

**创意基准：「连续卷册」**

MoonAXML 采用连续、有分隔线的卷册结构：暖炭色承托象牙色内容，衬线标题标记阅读上下文，紧凑的操作控件将主要空间留给被检查的文件。XML 尖括号与二进制方块组成专用标志。

系统保持平面、克制的表达。颜色用于操作、选中态和诊断；间距与棕褐色分隔线组织信息。英文和中文使用相同的控件与阅读层级。

**主要特征：**

- 暖色深色表面、象牙色文字和棕褐色分隔线。
- Alegreya 品牌文字与标题；系统无衬线控件与等宽数据文字。
- 方角控件和连续的结果表面。
- 固定阅读字号，并在明确的响应式条件下调整。

本文件记录已实现的浏览器工作台，以[样式表](playground/src/style.css)、[页面结构](playground/index.html)和[控制器](playground/src/main.ts)为依据。搜索扩展的审查截图位于 `.impeccable/review/round2/`，覆盖桌面（1440 px）、手机（390 px）和用户指定宽度（723 px）。页面构图由[界面简报](.impeccable/surfaces/playground-index-html.md)记录，产品能力由 [PRODUCT_zh.md](PRODUCT_zh.md)记录。本文件不声明部署状态。

## 颜色

文件头部记录可复用调色板。界面采用一个朱红强调色系，搭配暖中性色。

### 主色

- **朱红强调色**（`accent`）：用于选中视图下划线、处理状态指示点和源位置选中边框。
- **浅朱红色**（`accent-hover`）：用于键盘焦点、源位置链接、按下的文字控件和错误标题。
- 主要文件操作使用较深朱红背景和暖色浅文字；默认、悬停及按下的精确值记录在文件头部的组件变体中。

### 中性色

- **炭色底面**（`ground`）承托外部工作区；**暖炭色面板**（`plate`）承托结果卷册。
- **象牙色正文**（`ink`）用于标题及主要信息；**旧纸色次要文字**（`muted`）用于辅助标签和上下文。
- **棕褐分隔线**（`rule`）划分主要区域；**柔和棕褐分隔线**（`soft-rule`）划分行和内部区域。
- **浅棕褐色**（`faint`）用于搜索字段边框，与底面保持可辨识的控件边界（对比度 4.31:1）。

**克制朱红规则。** 朱红用于可操作控件、选中视图标记、源位置链接、焦点和诊断；长篇结果数据保持中性色。

附属 JSON 中的色阶为合成的预览元数据，不代表额外实现的调色板令牌。

## 字体

Alegreya 赋予品牌文字和标题印刷品特征。Arial 配合 Noto Sans SC、Microsoft YaHei 后备字体承载功能文字。数据依次采用 SFMono-Regular、Consolas、Liberation Mono 和 monospace；中文字符由可用的后备字体提供。

### 层级

- **品牌标题：** 标志文字使用 display 角色，AXML 后缀为斜体；窄屏缩小至 1.75rem。
- **主标题和子标题：** 结果标题使用 headline 角色，内容子标题使用 title 角色。四个视图标签采用 Alegreya（桌面 1.3125rem，窄屏 1.0625rem）。
- **标签：** 主要操作、文字操作、样例选择和页头导航使用 label 角色；辅助界面文字通常采用较小阅读档位（0.75rem）。
- **搜索：** 原生搜索字段采用系统无衬线字体的 search 角色（16px），窄屏保持相同阅读字号。
- **数据：** XML 使用 data 角色；窄屏改为 0.8125rem，行高 1.85。表格单元格使用等宽文字（0.8125rem），包名使用较大的等宽档位（1rem）；元数据在适当位置启用等宽数字。

**固定阅读字号规则。** 按阅读角色确定数据与控件字号。优先调整布局，再考虑缩小文字。

构建通过 `@fontsource/alegreya` 导入 Alegreya 拉丁字符常规体（400）、中等字重（500）和常规斜体（400），字体随静态应用一同提供。保留[附带的 SIL OFL 声明](playground/public/third-party/Alegreya-OFL.txt)。这些导入不依赖外部字体服务。

## 布局

居中工作区最大宽度为 92rem，桌面宽度为 `min(100% - 7rem, 92rem)`。页头、输入行、视图标签、结果标题、结果正文和上下文栏共用左右边界。四个等宽视图标签在支持的所有宽度下保持单行。

| 条件 | 已实现的调整 |
| --- | --- |
| 大于 100rem | 外部宽度改为 `min(100% - 10rem, 92rem)`。 |
| 不大于 68em | 单侧留白为 1.75rem；文件元数据可以换行；统计区改为两列。 |
| 不大于 45em | 单侧留白为 1rem；隐藏品牌说明；输入控件占满一行；结果操作移至标题下方；上下文栏允许换行。 |

结果内容在桌面采用 folio-inline 内边距，窄屏采用 standard 内边距。声明行使用标签与值的网格，窄屏标签列宽为 7rem。统计区桌面为三列，较窄宽度为两列。表格在自身区域内滚动，不撑宽页面。

结果面板具有最小高度（桌面 27rem，窄屏 24rem）。XML 阅读区域有垂直上限（42rem），在区域内滚动。XML 默认开启换行，换行时隐藏行号栏。关闭换行后恢复行号栏和水平滚动。这些仅改变显示，不编辑解码输出。

## 层次与深度

已实现的系统采用色调分层和分隔线，没有投影样式。结果面板仅略亮于底面。悬停、选中态和文件拖入覆盖层表达状态，不抬升组件。

**色调分隔规则。** 用底面与面板的色差及单像素棕褐色分隔线区分区域；不增加卡片抬升投影。

状态颜色使用短过渡（160ms，ease-out）。加载线和处理指示点原地明暗变化（1 秒，ease-in-out）。减少动态效果媒体查询关闭动画和过渡。没有入场编排。

## 形状

控件、结果区域、表格和分隔线采用方角几何。单像素边框和分隔线提供结构；选中视图标记为短的双像素下划线。锁和文件夹符号使用内联 SVG，品牌使用[专用 SVG 标志](playground/public/brand/moonaxml.svg)。工作台没有随构建发布的位图插画。

## 组件

### 文件控件与操作

原生样例选择器置于矩形边框内。主要文件操作为带内联文件夹图标的朱红实心矩形；两个控件的最小高度均为 2.75rem。文字操作默认使用次要文字色，悬停变为象牙色；开启换行时使用浅朱红文字。禁用按钮透明度降至 0.4。

交互控件的键盘焦点采用浅朱红轮廓（2px，偏移 4px）。跳转结果链接在获得焦点时显示。加载和错误保留明确文字，并通过动态状态区播报。

### 对齐的视图导航

XML、Manifest、结构和引用共用同一输入。分隔线对齐四个等宽列。选中标签结合象牙色文字与朱红下划线。标签使用选中状态、受控面板和单一可进入焦点；左右方向键、Home 和 End 可切换视图。

### 本机表格搜索

结构与引用各自提供带可见标签的原生搜索字段、清除文字操作和礼貌播报的匹配数/可用数。字段采用方角、一像素浅棕褐边框、底面背景、象牙色文字、次要色占位提示和浅朱红光标。键盘焦点使用两像素浅朱红轮廓，偏移三像素。字段与清除操作至少高 44px，在不超过 45em 时增至 48px；窄屏摘要纵向排列。

筛选会去除查询首尾空白并转为小写，按适用字段对原始名称、类型、命名空间 URI、引用来源，以及十进制或十六进制 ID/偏移执行字面子串匹配。更新结果行时保留输入节点，并在输入法组合期间暂缓筛选。Enter 由原生输入行为处理。查询在切换视图或语言时保留，载入新文件或样例时重置。清除恢复可用行并将焦点返回字段。零匹配使用简短事实文字。

结构只搜索最多 1,000 个事件的原始预览。源位置操作会清除结构查询并定位原始预览页。复制与下载均忽略查询；结构 JSON 仍只包含该有界事件预览。表格每页保持 50 行，窄屏表格在局部滚动。

### 结果卷册与数据行

卷册由衬线标题、简短上下文、操作区、数据表面和底部上下文栏组成。XML 是单色、可选中的文字。Manifest 声明采用成对字段、有分隔线的列表和原生可展开原始值。统计与表格行使用等宽数字和细分隔线。

引用与源位置操作采用带下划线的浅朱红控件。操作选中原始字节偏移，打开结构视图，切换至匹配的事件预览页，并在可用时显示原始事件；上下文栏也描述选中位置。

### 诊断与有界预览

诊断采用朱红衬线标题、阶段与源位置，以及简短恢复操作。特定阶段失败时保留其他可用视图。空结果仅显示紧凑的事实文字。

界面标明本机输入上限（16 MiB）、触发后的处理时限（10 秒）、XML 预览上限（100,000 个 UTF-16 单元）和截断后的声明预览数量（每类 50 项）。表格导航每页显示 50 条预览。复制与下载作用于当前视图的完整可用输出，不受可见 XML 或声明截断影响。

本机文件由可取消的模块 Worker 调用编译后的纯 MoonBit 桥接处理。应用会读取自身样例和静态资源，不上传选中文件的内容或文件名。这些约束决定诊断措辞与输入控件行为，属于实现事实，并非仅凭截图得出的结论。

## 应做与不应做

### 应做：

- **应**保留暖色深色调色板、XML 尖括号标志及衬线、无衬线、等宽字体的角色分工。
- **应**通过换行或有界局部滚动保持原始值可读。
- **应**为每项操作提供可见键盘焦点和准确状态。
- **应**保持双语标签简洁，并允许长文件名与值换行。

### 不应做：

- **不应**将整个结果表面染成朱红色或加入装饰性表面效果。
- **不应**用嵌套卡片或圆角推广标签替代连续卷册。
- **不应**暗示资源解析、Android 默认值推断、上传或安全结论。
- **不应**引入装饰性引导、虚构证据或未经验证的部署声明。
