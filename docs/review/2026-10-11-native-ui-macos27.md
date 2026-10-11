# Super RClick：界面、原创图标与功能验证报告

日期：2026-10-11。工作分支：`codex/native-action-workspace`；基线：`281dd7b`；第一阶段本地提交：`9329f3d`。开始时工作区干净，现有 main 未修改。没有 push、PR、合并、正式发布或部署。界面测试使用 `/tmp/superrclick-ui-after`，文件操作使用独立临时目录；没有读取剪贴板、访问真实 AI 凭据、修改系统权限或安装/注册 Finder 扩展。

## 调查依据

本地 remote 确认为 `https://github.com/CalvinQin/SuperRClick.git`。调查时 GitHub 返回 9 stars、6 forks、1 个 open issue；Discussions 未启用。Release 下载计数：v0.2.1 为 247 次，v0.1.0 为 14 次，共 261 次。下载数不能换算为活跃用户。

Issue #2 报告 macOS 15.6.1 / M1 Pro 无法启动 v0.2.1。README 写 15+，原实际构建目标却是 26.0；旧包 plist 与双架构 Mach-O 均确认这一差异。Issue #1 是已关闭的推广建议，无正文。

按后续明确授权，已回复并回读确认 [#1](https://github.com/CalvinQin/SuperRClick/issues/1#issuecomment-6108113942) 与 [#2](https://github.com/CalvinQin/SuperRClick/issues/2#issuecomment-6108124429)。未改变 issue 状态；回复明确说明修复尚未发布，15.6.1 实机验证尚未完成。

## 界面与状态管理

保持 SwiftUI / AppKit / Finder Sync 技术结构。动作库统一为分组行，提供来源、分类、名称/描述搜索、固定、Finder 显示、自定义编辑与删除确认。空状态可以清除条件或创建动作。所有文件模板纳入动作库。

共用动作编辑器采用独立草稿，编辑保留 UUID 和创建时间；名称、执行内容、扩展名明确校验，切换执行类型保留各自内容。取消时确认放弃；写盘成功才提交，失败显示完整错误并保留草稿重试。固定、显示、自定义动作及 AI 配置保存先写盘再替换共享状态。清空固定列表不再在重启时被自动填回。

AI 设置仍位于通用设置。关闭 AI 可以保存；配置草稿不会被其他动作的保存带入磁盘。保存失败不显示成功，连接错误可完整阅读。真实钥匙串行为未做集成验证；API Key 字段仍沿用原有编辑时保存机制，不将其称为配置草稿测试的覆盖范围。

主窗口使用原生分栏与标准控件；设置命令复用窗口，关闭后可从菜单重新打开。自绘图标的侧栏按钮可反复隐藏/恢复导航。批量重命名运行中禁止修改、重复应用、取消和关闭；重复打开面板保留原上下文。图片格式弹窗先冻结所选文件上下文。

macOS 27 上曾实测出现分栏内容高 1132、窗口高 700 的裁切。将动作库标题与列表放进同一 ScrollView 后，最终窗口与分栏均为 1000×700。第一阶段也检查了系统实际允许的 800×612 最小外框。

## 完整原创图标体系

按用户最新要求，全部应用可控图标改为原创矢量。品牌使用“折角文件＋指针切口”，深墨、蓝绿色与暖橙色组成主图标；界面使用统一 24 单位画布、1.8 单位圆角笔画及适量实心形状。

- 72 个原创语义图形，159 个兼容键；源码 96 个静态图标键全部覆盖，遗漏 0。
- 应用、Finder 扩展、菜单栏、侧栏、工具栏、动作、设置、状态、空状态、自定义图标选择器均接入同一渲染器。
- 旧 `systemImageName` 字符串仅保留为已有配置的兼容键；运行时不调用 SF Symbol 渲染器，未知旧值使用原创通用图形。
- 固定与未固定分别使用实心、轮廓形状；选中侧栏图标继承系统高对比前景色，已在浅/深界面目视核查。
- 删除远程服务商 Logo 请求及未使用的第三方图片资源，改用原创服务类别图标。
- 两套 AppIcon 的 20 张 PNG、README 图片、Support 主图/iconset/ICNS、发布说明 SVG 全部同步。ICNS 十个尺寸槽及原生 1024px 解码已检查。
- PDF 支撑的模板图像可缩放；16/20/24/32 尺寸，以及浅色、深色、选中、禁用、高对比渲染都有联系表。

原生搜索框内部放大镜/清除按钮、窗口交通灯、选择器箭头、复选框和开关标记等由系统控件绘制，保留系统交互与可访问性行为。没有通过更换控件去仿制这些系统细节。图标高对比联系表是渲染验证；未更改用户系统的“增加对比度/减少透明度”设置。

[设计说明](icons-design.md) · [完整消费点清单](icons-inventory.md) · [覆盖记录](icons-source-coverage.json) · [主图标](icons-app-master.png) · [浅色全套](icons-light.png) · [深色全套](icons-dark.png) · [状态联系表](icons-states.png)

## 实测发现并修复的功能问题

| 范围 | 修复后的行为 |
| --- | --- |
| 新建文件 | 18 种模板真实创建；RTF 使用有效内容，Office 模板校验 ZIP、XML 和内部关系。重复新建不覆盖已有文件。 |
| 安全输出 | 主应用和 Finder 共用独占 staging 与 `RENAME_EXCL` 原子发布；保护既有文件、目录、悬空符号链接及晚到冲突。失败只清理本次 staging。 |
| 压缩 | 主应用与 Finder 共用 `ZipArchivePlan`，以选中目录的父目录为工作目录；支持同目录文件/文件夹混合、空格、中文、前导横线和字面通配符。连续压缩输出独立文件，输入消失时不留下部分压缩包。 |
| 图片转换 | PNG/JPEG/TIFF/HEIC 真实生成并解码，部分失败准确报告成功数与失败项；原文件及已有输出保留。 |
| 批量重命名 | 拒绝路径分隔符；途中失败回滚之前改名。回滚遭新冲突时保留双方文件，并报告仍处于新名称的路径。 |
| 重复执行 | 进度任务同步拒绝重入；任务 ID 阻止迟到回调污染下一任务。重命名被其他任务占用时不残留 busy 状态。 |
| 桌面自定义动作 | 修复 `custom-UUID` 路由，接通异步 Shell/AppleScript/打开应用执行器；执行前读取当前启用状态和条件，旧菜单不能运行已禁用或删除的动作。真实退出码和错误输出可见。 |
| Finder 可见性 | 菜单与动作引擎共用可见性规则；关闭远程 AI 时保留本地 OCR、抠图。桌面菜单行为同步。 |
| AI 重命名 | 模型文件名经过 basename 校验，不能利用 `../`、分隔符等跨目录移动；目的文件存在时报错并保留两方。 |
| OCR | 多张图片逐张识别，合并带文件名的结果；空选择不再静默成功。 |
| 本地抠图 | 使用唯一输出保护已有结果和符号链接；修复透明背景无限 extent 导致 PNG 渲染失败，按原图边界输出。 |
| Ollama | 允许确实无需认证的本地配置省略 Key；其他服务仍要求密钥。 |
| 文案 | 移除没有实现的“查找替换”“可配置步长”“20+模板/YAML”“WEBP 导出”等承诺，明确目前整个 home 的 Finder 覆盖方式。 |

## 最终验证矩阵

实际环境：macOS **27.0 (26A5425a)**、Xcode **27.0 (27A5194q)**、SDK 27.0、Apple Silicon。主应用在此环境实际运行。只读使用了第三方 `apple-hig` 静态参考，没有运行其附带 Python 助手；技能快照不代替 SDK 或实机结论。

PASS 表示对应检查实际执行且断言通过，包含“预期失败被正确拒绝”的用例；不同 harness 的计数不等同于独立的完整端到端用户流程。

| 检查 | 状态 | 证据/边界 |
| --- | --- | --- |
| Debug / UI 测试源码最终构建 | PASS | `output/review/final-ui-test-build.log`；7 个 UI 场景编译成功 |
| Release arm64 + x86_64 构建 | PASS | `final-functional-release-build.log`；未签名发布、未制作发布 DMG |
| macOS 15 最低版本 | PASS，9 项 | `final-compatibility-verification.txt`；App、扩展、框架 plist 和双架构 Mach-O |
| Core XCTest | PASS，27/27 | `final-functional-core-tests.xcresult`、`final-functional-core-tests.log` |
| 核心真实文件操作 | PASS，62/62 | [完整矩阵](../../output/review/functional-core/matrix.md)，真实模板、ZIP、转换、重命名、并发与独占发布；Finder reveal 替换为空操作 |
| 协调器/桌面自定义路由 | PASS，45/45 | [完整矩阵](../../output/review/functional-coordinator/matrix.md)，真实 Shell、纯本地 AppleScript、保存/回滚；窗口展示被替换 |
| AI 执行边界 | PASS，12/12 | [完整矩阵](../../output/review/functional-ai-run-91j43qaq/matrix.md)，假 LLM/部分假 Vision，真实文件改名和输出保护 |
| 本地 Vision | PASS，2/2 | 同上；真实双图 OCR，真实抠图 PNG 为 1200×700、有透明像素且保留前景 |
| LLM 请求层 | PASS，9/9 | 同上；假 HTTP，验证 Ollama 空 Key、鉴权、请求错误及取消，不代表真实服务连通 |
| Finder 菜单离线构造 | PASS，94/94 | [完整矩阵](../../output/review/functional-finder-menu/matrix.md)，规则、上下文、动态项和图标；不代表扩展已被 Finder 加载 |
| Finder 全源类型检查 | PASS | `functional-finder-menu/finder-extension-typecheck.log`，Swift 6 严格并发、macOS 15 目标 |
| 原创图标 | PASS | 编译、96 键覆盖、PNG/ICNS 尺寸、浅深及状态联系表；实机发现并修正选中对比不足 |
| XCTest UI runner | BLOCKED | 第一阶段启动即 `Timed out while enabling automation mode`，`ui-runner-failure.log`；没有把 7 个场景计作已通过 |
| 真实 Finder 安装/加载/点击 | BLOCKED | 本机未登记此扩展，安装/注册/启用尚待额外授权 |
| 剪贴板内容验证 | BLOCKED / 未重试 | 读取现有剪贴板的先前方案被自动审批拒绝；本次无读取或绕过 |
| 真实远程 AI、Keychain 集成 | NOT RUN | 未发送付费请求、访问凭据或创建密钥 |
| Terminal / 打开已安装应用 / Quick Jump 真正跳转 | NOT RUN | 测了不存在应用的失败分支，未启动其他应用 |
| macOS 15.6.1、Intel 实机 | NOT RUN | 双架构和最低版本检查不能替代实际启动 |
| VoiceOver、完整键盘、系统高对比开关 | NOT RUN | 搜索键盘自动输入未确认成功；未改变系统设置 |
| Services / Run Placeholder AppIntent | NOT IMPLEMENTED | 现有代码占位；不能以“缺权限”解释或宣称功能已通过 |

早期失败与修复前基线已保留：例如目录压缩、部分成功误报、AI 越界及输出覆盖、本地 Vision 无限画布。最终上表已执行的检查没有残留失败。HEIC 和 Vision 在工具沙箱内曾受运行环境限制，经批准仅对临时合成素材在本机执行后通过，没有改系统权限。

## 原生界面实际交互

第一阶段通过已有 System Events 通道完成并核对隔离 JSON：空表单禁用保存；填写后启用；取消的“继续编辑”保留草稿、“放弃更改”不保存；创建/编辑/重启保持单个 UUID；扩展名规范化及通配符错误可见；真实磁盘写失败仍保留编辑器，恢复后重试成功且无重复动作。AI 草稿不会被其他动作保存带入磁盘。文件选择器取消不改文件。关闭主窗口后从设置菜单可重新打开一个窗口。

原创图标接入后再次实际检查：

- 侧栏按钮只出现一枚；连续隐藏、恢复时分栏数为 **2 → 1 → 2**，窗口数始终 1。
- 新建空动作保存禁用，取消后 sheet 数为 0；工具箱与动作库可往返。
- 固定和显示开关实际写入临时 JSON，再通过界面恢复原测试状态；重启后状态保留。
- AI 关闭时保存按钮仍启用，连续保存两次后 JSON 为 false；测试连接按钮禁用，重启后仍关闭。
- 设置菜单连续调用后窗口数 **1 → 1**。
- 最终英文浅色、中文深色目视检查；选中图标对比已修正。所有最终截图都来自原创图标版本。

键盘注入未能可靠触发 SwiftUI 搜索输入，不把 AX 值变化当作搜索实际成功；后续仍需人工键入、Command-N / Command-, / Control-Command-S、Tab 与 VoiceOver 检查。

## 最终截图与文件

- [最终：中文深色](../../output/review/final-actions-zh-dark.png)
- [最终：英文浅色](../../output/review/final-actions-light.png)
- [原创图标版本的 AI 关闭并保存](../../output/review/final-settings-zh-dark.png)
- [原创主图标](icons-app-master.png)
- [多尺寸与状态联系表](icons-states.png)
- [真实本地抠图产物](../../output/review/functional-ai-run-91j43qaq/samples/real-transparent.png)
- [双图 OCR 文字](../../output/review/functional-ai-run-91j43qaq/samples/recognized-text.txt)

`before-actions.png`、`after-actions*.png`、`editor-*` 等保留为第一阶段过程证据，不作为本轮最终视觉交付。构建日志、xcresult、功能 fixture 与界面截图位于现有 gitignore 排除的 `output/review/`；可复跑代码和图标设计资产纳入源码。

## Finder 真机验证需要的最小额外授权

此部分仅描述，尚未执行。经用户同意后，将本地 Release 副本按 Shared framework → Finder appex（保留扩展 entitlements）→ App（保留 App entitlements）签名，安装到 `~/Applications/SuperRClick.app`；如该位置已有应用立即停下，不覆盖。启动后仅在系统未登记时注册内嵌扩展，并由用户在“系统设置 → 通用 → 登录项与扩展”启用 Finder 扩展。

测试仅使用本项目 `output/functional-finder-fixtures` 下新建临时子目录，因为扩展当前监听 home。普通 Finder 菜单不需要新增辅助功能或输入监控权限，也不需要重启 Finder。不会自动执行复制路径；如用户自己验证复制，会替换剪贴板。

首次真实 launch 仅 preflight 检查 DesktopBridge 权限，不主动弹授权；但若两项权限原已授予，会启动监听。真实启动也会读取/迁移现有配置并处理待执行外部命令，因此这一步不能等同于当前隔离预览。注册可能使同标识已启用扩展加载。完整后续步骤见 [FINDER.md](../../Tests/Functional/FINDER.md)。

启用后应检查：动作显示/隐藏、文件与文件夹及空白上下文、自定义禁用后的旧菜单、重复点击、目录压缩、图片部分失败、重命名面板取消/应用/运行中关闭，以及返回 App 后扩展状态刷新。真实远程 AI 则应另行指定提供商、模型、一次请求及潜在费用，仅使用生成的测试素材。

## 复现入口

```bash
xcodegen generate
xcodebuild -project SuperRClick.xcodeproj -scheme SuperRClick \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/review CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  CODE_SIGN_ENTITLEMENTS= DEVELOPMENT_TEAM= -only-testing:SuperRClickCoreTests test

xcodebuild -project SuperRClick.xcodeproj -scheme SuperRClick \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build/release-review ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build

scripts/verify_compatibility.sh build/release-review/Build/Products/Release/SuperRClick.app
bash Support/Assets/generate_app_icons.sh
```

功能复跑及边界：[文件操作](../../Tests/Functional/CORE_FILE_ACTIONS.md)、[协调器](../../Tests/Functional/COORDINATOR.md)、[AI](../../Tests/Functional/AI.md)、[Finder 菜单](../../Tests/Functional/FINDER.md)。每次使用新的临时目录，并保留日志、结果及源码快照/哈希。

Debug 隔离运行：

```bash
SUPERRCLICK_TEST_STORAGE=/tmp/superrclick-ui-review \
SUPERRCLICK_TEST_APPEARANCE=light \
build/review/Build/Products/Debug/SuperRClick.app/Contents/MacOS/SuperRClick \
  -app_selected_language en -AppleLanguages '(en)' -showInDock YES
```

中文深色使用 `dark`、`zh-Hans`、`'(zh-Hans)'`。隔离配置仅在 Debug 生效，Release 忽略；生产 entitlements 未移除。上述 Debug 构建为隔离测试清除签名权益，不能直接拿它验证 Finder/App Group 集成。

官方参考：[Finder 状态 API](https://developer.apple.com/documentation/findersync/fifindersynccontroller/isextensionenabled)、[原生管理入口](https://developer.apple.com/documentation/findersync/fifindersynccontroller/showextensionmanagementinterface())、[登录项与扩展设置](https://support.apple.com/guide/mac-help/change-login-items-extensions-settings-mtusr003/mac)、[macOS HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)。
