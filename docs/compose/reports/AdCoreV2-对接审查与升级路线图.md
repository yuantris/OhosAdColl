---
feature: AdCoreV2 对接审查与升级路线图
status: delivered
specs: []
plans:
  - .mimocode/plans/1792048964653-glowing-rocket.md
branch: AdCoreV2-alpha
commits: pending
---

# AdCoreV2 对接审查与升级路线图 — Final Report

## What Was Built

分析报告 `docs/AdCoreV2_对接审查与升级路线图.md`：对照 `ad_demo` 官方示例（GDT 1.5.0 / 穿山甲 GroMore 7.6.0.6），系统审查 `AdCoreV2` 广告聚合 SDK 的对接正确性、实现问题与结构性缺点，并产出 Phase 0–3 分阶段升级路线图。本交付为纯文档分析，未改动任何业务代码。

报告覆盖 9 章：背景与范围、V2 现状深查（初始化/平台/降级/回调/网络/缓存/API）、官方 demo 对照、对接正确性结论（含 6 项已核实 bug）、实现问题清单（AdCache 专项、IAd 抽象专项、宿主使用侧）、结构性缺点 A–E、升级路线图、风险与兼容性、关键文件索引。

## Architecture

报告按审查维度组织，核心结论：

- **对接偏差**：load/show 融合（TxAdLoader `onAdLoad` 内自动 show）、原生 ad 闭包泄漏、destroy 仅翻标志位、成功语义不一致。
- **已核实 bug**：HealthChecker 键解析失效（数值 key vs 字符串 switch）、华为插屏 `publisherBundleName` 写死错误包名、`BaseAdManager.loadAd` 永不 resolve 的 Promise、AdCache 清理死代码、华为 appId 占位符、华为信息流 `bind()` 空壳。
- **AdCache 定性**：半成品 + 负资产（命中不消费、不失效、与 destroy 脱节、preload 未接线、Banner 绕过）。
- **IAd 抽象**：撑不起 Banner/自渲染，需重构为「生命周期 + RenderMode 三态 + NativeAdMaterial」。
- **路线图**：Phase 0 正确性修复 → Phase 1 生命周期标准化 + 形态补齐 → Phase 2 并发/可观测 → Phase 3 IAd 抽象重构。Bidding 按需求搁置。

### Design Decisions

- AdCache 修复方向给出 A（保留修好）/B（删除简化）二选一，**建议短期选 B**：当前组件路径即请求即展示、preload 从未接线，删缓存更安全。
- load/show 分离采用双轨过渡（`autoShow` 开关 + `@deprecated` 旧入口），避免破坏现有宿主。
- Bidding 明确移出本期路线图，待单独立项。

## Usage

报告为分析型交付，供后续 Phase 0 修复立项时直接引用。关键 file:line 引用均已与源码核对一致，可按「§4.2 已核实 Bug」和「§7 Phase 0 表」直接开工。

交付物路径：`docs/AdCoreV2_对接审查与升级路线图.md`

## Verification

- 抽查 Grep 核对关键 file:line 引用（PublisherBundleName、永不 resolve Promise、AdCache 死代码、HealthChecker 键失配、TxAdLoader 自动 show、华为 appId 占位符、IAd getAd/bind 等）均与源码一致。
- 未运行 build/test/lint（分析型交付，按计划验证以文档自洽与证据可追溯为准）。
- 报告结构与计划第七章要求一致，无 TBD/占位符。

## Journey Log

- [lesson] 计划文件在同一路径被更新过（先前版本是 AdCoreV3 实施计划），执行前需重新读取确认当前版本，避免按旧计划开工。

## Source Materials

| File | Role | Notes |
|------|------|-------|
| `.mimocode/plans/1792048964653-glowing-rocket.md` | 实施计划 | 分析报告型交付 |
| `docs/AdCoreV2_对接审查与升级路线图.md` | 交付物 | 正式审查报告 |
| `AdCoreV2/src/main/ets/ohos/` | 审查对象 | 只读 |
| `ad_demo/**` | 对照基准 | GDT / 穿山甲官方 demo |
