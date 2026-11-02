# 可复现测试样本

[English](README.md) | [项目](../README_zh.md)

XML 源文件与合成数据均为本仓库自行编写，遵循仓库的 Apache-2.0 许可，不分发第三方 APK。
`manifest.json` 记录源文件与二进制的 SHA-256、来源、工具版本、许可及生成命令。

## 样本内容

- `valid/manifest_basic.axml`：版本、SDK、两项权限及四种组件。
- `valid/manifest_unicode.axml`：补充平面 Unicode、XML 转义及属性中的换行和制表符。
- `valid/manifest_references.axml` 与 `valid/menu.axml`：应用和系统资源引用、编译后的菜单 XML。
- `valid/synthetic_utf*.axml`：独立构造 UTF-8/UTF-16 字符串池、命名空间、文本，以及使用双字长度编码的 33,000 单元 UTF-16 字符串。
- `invalid/`：十二种截断或字段变异，覆盖块边界、索引、编码、终止符、属性步长与元素不匹配。

## 重新生成

安装 Android SDK Build Tools **36.0.0** 和 **android-36** 平台后执行：

```powershell
uv venv A:\DevEnv\Envs\moonbit-axml --python 3.12
uv pip install --python A:\DevEnv\Envs\moonbit-axml\Scripts\python.exe androguard==4.1.3
& A:\DevEnv\Envs\moonbit-axml\Scripts\python.exe scripts/generate_fixtures.py --sdk $env:ANDROID_HOME
```

生成器验证 aapt2 版本 `2.20-13193326`，记录工具哈希，仅在被忽略的
`_build/fixtures/` 中生成 APK，并提取需要提交的二进制 XML。
`reference/*.aapt2.txt` 和 `*.badging.txt` 来自 aapt2；`*.xml` 和 `*.tree.json`
来自 **androguard 4.1.3**，不依赖 MoonBit 实现。合成样本明确标注来源，
同样经过 androguard 解码。生成的 MoonBit 测试直接嵌入样本，不依赖文件系统。

## 验证

```powershell
python scripts/verify_cli.py
```

验证只需要 Python 标准库、MoonBit 与 Node.js：检查哈希，用 ElementTree
解析 CLI 输出，与独立参考树比较展开名称、属性和文本，并校验清单元数据。
无效输入必须产生含字节偏移的错误。等价资源 ID 写法会被归一化；不比较
XML 排版或命名空间前缀选择。
