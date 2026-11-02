# 产品说明

<!-- impeccable:product-schema 1 -->

[English](PRODUCT.md)

## 平台

web

## 技术栈

已确认：Vite、TypeScript、Tailwind CSS、pnpm。演示为可部署到 GitHub Pages 的静态站点。
直接通过代码制作，工作流偏好保存在 `.impeccable/config.json`。
[线上工作台](https://ling71671.github.io/moonbit-axml/)已部署到 GitHub Pages。

## 用户

评估 MoonBit AXML 库或检查已提取 Android 编译 XML 的开发者。主要任务是选择样例或本地
文件，查看解码 XML、Manifest 声明、结构及资源引用。

## 产品目的

通过浏览器工作台使用真实 MoonBit 解码器。访问者可以加载输入、理解结果或诊断，
复制或下载所需输出，无需安装 Android 工具链。

## 能力与约束

纯 MoonBit 核心支持边界检查、AXML 解码、XML 重建、Manifest 与 Intent Filter 检查、
统计及带位置的类型引用。浏览器适配层提供独立 ESM 桥接；Node CLI 的专用 I/O 不进入浏览器产物。
库与 CLI 提供有界、可选的 XML 格式化输出。结构与引用支持本地字面搜索；结构保持
1,000 条事件预览，筛选不缩小导出结果。
本地文件在客户端处理，不上传、不调用服务端 API；影响操作的输入预算和显示截断应明确。
演示不负责 APK 提取、资源表解析、修复或安全判断。普通资源 XML 的 Manifest 检查不适用时，
其他结果仍可使用。耗时解析放在可取消的 Worker 中。

## 品牌约定

名称为 MoonAXML。图标方向已确定为 XML 括号与二进制块。
页面是交互工作台，使用简短、客观的产品文案，不增加装饰性的引导流程。
采用深色优先的工作区。选定的连续图谱方向将暖纸色转换为炭黑、象牙白、棕褐细线与克制的朱红控件。

## 已有证据

提交 `ef6591b` 的 Linux/Windows CI 在每个宿主通过 wasm-gc 130 项、JavaScript 133 项、
native 130 项及前端 18 项测试。相同修订已部署到 Pages；[两轮验证记录](evidence/verification-two-rounds.json)
记录运行及线上搜索/下载检查。`fixtures/` 包含 19 份自有合法或
畸形输入及固定的独立参考。`docs/ACCEPTANCE_zh.md`、`evidence/` 记录对应源码修订。
不虚构客户、性能排名或部署状态。

## 产品原则

- 调用真实编译的 MoonBit 实现。
- 本地文件内容和名称留在用户设备。
- 某个检查阶段失败时保留其他可用视图。
- 区分显式声明、未解析值与平台推断。
- 文件选择、结果导航及诊断支持键盘操作。
