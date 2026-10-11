# 2026-10-11 本地改版与 macOS 27 验证记录

本轮在 `codex/native-action-workspace` 实施，基线 `281dd7b`，开始时工作区干净。未修改 main，未 push、创建 PR、合并、发布或部署。测试数据位于 `/tmp/superrclick-ui-after`；没有修改用户已有动作、钥匙串、系统权限或注册 Finder 扩展。

## 仓库与真实反馈

本地 remote 为 `https://github.com/CalvinQin/SuperRClick.git`。2026-10-11 读取 GitHub 得到 9 stars、6 forks、1 个 open issue；Discussions 未启用。Release 下载计数为 v0.2.1 的 247 次及 v0.1.0 的 14 次，共 261 次下载，不能换算成活跃用户。

- Issue #2 报告 macOS 15.6.1 / M1 Pro 无法启动 v0.2.1。README 写 15+，实际构建目标却是 26.0；旧本地 staging 包的 plist 和双架构 Mach-O 均验证为 26.0。
- Issue #1 是推广建议，已关闭，没有描述正文。
- 按本轮后续明确授权，已回复并回读确认 [#1](https://github.com/CalvinQin/SuperRClick/issues/1#issuecomment-6108113942) 与 [#2](https://github.com/CalvinQin/SuperRClick/issues/2#issuecomment-6108124429)。未改变 issue 状态。回复明确说明修复尚未发布、15.6.1 实机测试未完成。

## 实现范围

- 保留 SwiftUI / AppKit / Finder Sync 结构，动作库改为统一分组行、来源与分类筛选、名称/描述搜索、直接固定和 Finder 可见性开关、自定义动作编辑与删除确认、可恢复空状态。
- 共用自定义动作编辑器：独立草稿，保留 UUID 和创建时间，名称/脚本/扩展名校验，切换执行类型保留各自草稿，取消时确认放弃。写盘成功才提交状态；失败保留编辑器及错误，允许重试。
- 补齐文件模板的动作定义。固定、可见性、自定义动作、AI 配置等保存先写磁盘再更新共享状态；空固定列表不再在重启时被默认项目重新填满。
- AI 设置保留在通用设置中。关闭 AI 也能保存；保存失败不再显示成功；配置使用局部草稿，离开未保存的设置后，其他动作保存不会顺带写入 AI 草稿。连接错误完整显示、可选择复制；加载已有密钥不再写回钥匙串。
- 批量重命名在执行中锁住编辑、应用、取消与关闭；重复打开已有面板不会先覆盖上下文或释放安全作用域。
- 主窗口采用原生分栏与工具栏；设置命令复用已有窗口，关闭后仍可从菜单重新打开；共享状态提示可关闭。固定面板执行文件动作时先选择真实文件或目录。
- 所有构建目标统一 macOS 15.0，替换一处仅 macOS 26 可用的标签写入 API，并加入 `scripts/verify_compatibility.sh` 检查主应用、扩展及框架的所有架构。
- Finder 设置改用官方 `FIFinderSyncController.isExtensionEnabled` / `showExtensionManagementInterface()`；应用重新激活后重新检查状态；设置向导不再始终声称扩展已启用。

## macOS 27 实际验证

环境为 macOS 27.0 (26A5425a)、Xcode 27.0 (27A5194q)、macOS SDK 27.0、Apple Silicon。主应用已在该环境实际运行。

新动作库最初出现分栏容器高度 1132、窗口高度 700 的裁切。逐项对照排除了窗口类型、windowResizability 和状态条容器，最终将标题与列表放在同一个 ScrollView 中解决。最终窗口和分栏均为 1000×700；尝试缩至 800×560 时系统保留 800×612 的最小外框，导航与控件正常。此处是实际观察并修复的应用布局问题，不声称 Apple 发布说明记录过相同 bug。

按原生 HIG 方向使用系统字体、语义色、SF Symbols、标准控件及可调整窗口，不改技术栈、不人工仿制玻璃效果。只读已安装的第三方 `apple-hig` 静态参考，未运行任何附带 Python 助手；补充语言选择器辅助标签、状态关闭按钮点击范围、完整可复制错误文本。技能快照不代替 SDK 或实机验证。

官方参考：[Finder 状态 API](https://developer.apple.com/documentation/findersync/fifindersynccontroller/isextensionenabled)、[原生管理入口](https://developer.apple.com/documentation/findersync/fifindersynccontroller/showextensionmanagementinterface())、[系统登录项与扩展设置](https://support.apple.com/guide/mac-help/change-login-items-extensions-settings-mtusr003/mac)、[macOS HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)。

## 验证结果与证据

构建与日志在本地 `output/review/`，该目录按项目现有规则忽略，不会随源码提交。

| 检查 | 结果 |
| --- | --- |
| 最终 Debug 构建 | 通过，`debug-build.log` |
| 最终 Release arm64 + x86_64 构建 | 通过，`release-build.log`；未签名发布、未生成发布包 |
| Bundle 兼容性检查 | 9 项通过，`compatibility-verification.txt` |
| Core XCTest | 26 项通过、0 失败，`final-core-tests.xcresult` / `core-tests.log` |
| 新增 CustomAction 校验测试 | 9 项，包含脚本原样保留、UUID、扩展名规范化及错误输入 |
| UI 回归源码 | 7 个真实 UI 场景，最终 `build-for-testing` 通过，`ui-test-build.log` |
| XCTest UI runner | 未执行测试：启动阶段 `Timed out while enabling automation mode`，见 `regression-tests.xcresult` / `ui-runner-failure.log` |

采用已有 System Events 辅助功能通道补充实际交互，并读取隔离 JSON 确认持久化：

- 空表单禁用保存；填入执行内容后启用。
- 取消后“继续编辑”保留草稿，“放弃更改”不写入动作。
- 创建、编辑、重启保持单个动作及 UUID；扩展名去点、小写、去重；无效通配符显示内联错误。
- 将隔离 JSON 路径临时替换成非空目录制造真实写盘失败：重复保存仍保留编辑器；恢复文件后重试成功，没有重复动作。临时阻塞目录已移除。
- 固定和 Finder 可见性双控制写入磁盘；重启保持状态。
- 自定义来源与 Text 分类组合得到无结果，清除筛选恢复全部动作。
- AI 关闭后仍能保存，重启控件显示关闭；最终草稿隔离检查中，未保存的 AI 开关不会被另一次固定操作写盘，返回设置也恢复已保存值；明确保存开/关均成功。
- 设置菜单连续调用保持一个窗口；关闭主窗口后应用继续存活，再从设置菜单打开一个窗口。
- 工具箱打开批量重命名文件选择器，取消返回主窗口，无文件操作。
- 英文浅色、英文深色、中文深色与窄窗口截图检查。

完整的键盘搜索输入自动化未确认通过，未将辅助控件值变化算作搜索测试成功。UI runner 未跑通，不能把源码中 7 个场景称为 7 项通过。原生菜单/按钮/表单保存的上述检查是独立的实际交互证据。

## 截图

- [改版前](../../output/review/before-actions.png)
- [改版后：英文浅色](../../output/review/after-actions-light.png)
- [改版后：中文深色](../../output/review/after-actions-zh-dark.png)
- [较小窗口](../../output/review/after-actions-small.png)
- [筛选无结果](../../output/review/filters-empty.png)
- [放弃更改确认](../../output/review/editor-discard.png)
- [扩展名校验错误](../../output/review/editor-validation-error.png)
- [真实磁盘保存错误](../../output/review/editor-disk-error.png)
- [自定义动作保存成功](../../output/review/custom-action-saved.png)
- [AI 关闭并保存](../../output/review/ai-disabled-saved.png)

## 仍需人工验证

1. 本机 `pluginkit -m -A -D -p com.apple.FinderSync` 未列出 SuperRClick；本轮未注册或启用扩展。需用户自行安装/启用本地构建后，在一次性测试目录检查 Finder 右键菜单、上下文文件选择、原生扩展设置入口与返回后的状态刷新。
2. 在 macOS 15.6.1 上启动主程序和 Finder 扩展；Intel 也需实际运行。编译双架构和最低系统版本检查不等于这些系统已实测。
3. 手动键盘输入搜索、Command-N / Command-,、Tab 导航、VoiceOver，及增加对比度/减少透明度组合。标准设置菜单动作已经实测，快捷键按键本身未充分验证。
4. 批量重命名选择一次性文件，预览并取消，再应用；运行期间重复点击和关闭面板。执行中的防重入已实现并审查，但本轮没有实际执行文件重命名来验证该阶段。
5. 真实 AI 服务连接、钥匙串错误、远程请求与需要权限的桌面增强未运行。测试隔离会跳过这些操作。

## 复现命令

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
```

Debug 单独验证会清除测试构建的签名权限配置以支持临时目录，但未改变仓库中的生产 entitlements。隔离界面运行方式：

```bash
SUPERRCLICK_TEST_STORAGE=/tmp/superrclick-ui-review \
SUPERRCLICK_TEST_APPEARANCE=light \
build/review/Build/Products/Debug/SuperRClick.app/Contents/MacOS/SuperRClick \
  -app_selected_language en -AppleLanguages '(en)' -showInDock YES
```

`SUPERRCLICK_TEST_APPEARANCE` 仅在 Debug 且已使用隔离存储时生效；设为 `dark` 可检查深色，中文参数为 `-app_selected_language zh-Hans -AppleLanguages '(zh-Hans)'`。Release 忽略隔离配置。没有新增产品内外观设置。
