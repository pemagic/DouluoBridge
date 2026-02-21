### 安卓端根本性修复 (Android Root-cause Fix) - v1.8.5
- **所有渲染 bug 根因修复**：`startGame()` 在 UI 线程直接调用，导致 `generatePlatforms()` + `drawBackground()` 创建 Texture 在错误线程执行，造成背景丢失、平台不显示、所有视觉元素渲染失败。
- **修复**：开始/重开/继续按钮全部改为 `Gdx.app.postRunnable { ... }`，配合 v1.8.4 的功能按钮修复，所有 UI → GL 线程调用问题彻底解决。
