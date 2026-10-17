import { window } from '@kit.ArkUI';
import { Ohos } from '@zycore/common';
import { AdSwitchManager } from '../../helper/core/AdSwitchManager';
import { AdSlotManager } from '../../helper/core/AdSlotManager';
import { GlobalAdLoadLogStore, GlobalAdLogEntry } from '../../helper/core/GlobalAdLoadLogStore';
import { AdDebugFloatController } from '../../helper/core/AdDebugFloatController';
import { AdModeManager } from '../../helper/core/AdModeManager';
import { ForceChannelManager } from '../../helper/core/ForceChannelManager';
import { PlatformType, SERVER_SEQUENCE_MAP, getPlatformName } from '../../model/PlatformType';
import { VIPRepo } from '../../storage/VIPData';
import { AdType } from '../../model/AdType';
import { SDKCore } from '../../application/SDKCore';
import { LogEntry, LogLevel, LogManager } from '../../helper/logger/LogManager';

// ==================== 形态尺寸 ====================

/** 图标列宽(vp) */
const ICON_COL_W = 56;
/** 合并形态总宽(vp) = 图标列 + 面板 */
const DOCK_W = 336;
/** 合并形态总高(vp) */
const DOCK_H = 430;
/** 轮询间隔(ms) */
const POLL_INTERVAL = 1000;
/** 空闲自动收起(ms) */
const IDLE_TIMEOUT = 8000;

// ==================== 页签与数据模型 ====================

interface TabItem {
  key: string;
  /** 图标字符（中文单字，规避 emoji 字体差异） */
  glyph: string;
  label: string;
  color: string;
}

/** L1 图标列功能入口（对应参考图左侧应用图标位） */
const DOCK_TABS: TabItem[] = [
  { key: 'config', glyph: '配', label: '配置', color: '#FFB300' },
  { key: 'log', glyph: '志', label: '日志', color: '#42A5F5' },
  { key: 'slot', glyph: '槽', label: '槽位', color: '#66BB6A' }
];

interface LogFilterItem {
  label: string;
  level: LogLevel | null;
}

/** 日志级别过滤（最低级别语义：≥W 含 ERROR） */
const LOG_FILTERS: LogFilterItem[] = [
  { label: '全部', level: null },
  { label: '≥D', level: LogLevel.DEBUG },
  { label: '≥I', level: LogLevel.INFO },
  { label: '≥W', level: LogLevel.WARN },
  { label: '≥E', level: LogLevel.ERROR }
];

interface ConfigSnapshot {
  adOpen: boolean;
  vip: boolean;
  modeName: string;
  ssText: string;
  /** 服务器顺序 chips（ss 原文映射） */
  ssOrder: string[];
  /** 生效瀑布顺序 chips */
  waterfall: string[];
  forceChannel: string;
  csjText: string;
  txText: string;
  hwText: string;
}

interface SlotPlatformId {
  name: string;
  /** 真实广告 ID，空串表示未注册 */
  realId: string;
}

interface SlotRow {
  slot: string;
  ids: SlotPlatformId[];
}

function emptyConfig(): ConfigSnapshot {
  return {
    adOpen: false,
    vip: false,
    modeName: '未知',
    ssText: '未获取',
    ssOrder: [],
    waterfall: [],
    forceChannel: '未设置',
    csjText: '-',
    txText: '-',
    hwText: '-'
  };
}

/**
 * 调试悬浮球两级交互（小米游戏工具箱式，L1 与 L2 合并出现）
 *
 * L0 球：48vp 渐变玻璃球，点击展开合并形态
 * L1 图标列：配置 / 日志 / 槽位 三个功能入口（无开关，对应参考图左侧图标位）
 * L2 面板：与图标列合并为一个窗口，展示当前页签内容
 *   - 配置：广告开关、服务器规定顺序、渠道启用状态
 *   - 日志：LogManager 日志输出 + 请求记录
 *   - 槽位：已注册槽位及各渠道真实 ID
 */
@ComponentV2
export struct AdDebugFloatPanel {
  /** 0=球 1=合并形态(图标列+面板) */
  @Local level: number = 0;
  /** 当前页签：config / log / slot */
  @Local activeTab: string = 'config';
  /** 图标列是否在右侧（球贴右半屏时镜像） */
  @Local mirrored: boolean = false;
  @Local expandProgress: number = 0;
  @Local edgeRatio: number = 0.5;
  @Local cfg: ConfigSnapshot = emptyConfig();
  @Local logEntries: LogEntry[] = [];
  @Local logFilter: LogLevel | null = null;
  @Local slotRows: SlotRow[] = [];
  @Local requestLogs: GlobalAdLogEntry[] = [];
  private win: window.Window | null = null;
  private idleTimer: number = -1;
  private pollTimer: number = -1;
  private logFirstTs: number = -1;
  private logCount: number = -1;
  private logFilterKey: number = -2;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.win = AdDebugFloatController.getInstance().getWindow();
    this.refreshAll();
    this.startPolling();
    this.armIdleTimer();
  }

  aboutToDisappear(): void {
    this.clearIdleTimer();
    this.stopPolling();
  }

  // ==================== 生命周期 ====================

  /** 空闲计时：仅用户交互续期，轮询不续期（否则永远不触发） */
  private armIdleTimer(): void {
    this.clearIdleTimer();
    this.idleTimer = setTimeout(() => {
      this.autoCollapseToBall();
    }, IDLE_TIMEOUT);
  }

  private clearIdleTimer(): void {
    if (this.idleTimer >= 0) {
      clearTimeout(this.idleTimer);
      this.idleTimer = -1;
    }
  }

  private startPolling(): void {
    this.stopPolling();
    this.pollTimer = setInterval(() => {
      if (this.level === 1) {
        this.refreshActive();
      }
    }, POLL_INTERVAL);
  }

  private stopPolling(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  // ==================== 数据刷新 ====================

  private refreshAll(): void {
    this.refreshConfig(true);
    this.refreshLogs();
    this.refreshSlots();
    this.refreshRequestLogs();
  }

  /** 轮询：仅刷新当前页签数据 */
  private refreshActive(): void {
    if (this.activeTab === 'log') {
      this.refreshLogs();
      this.refreshRequestLogs();
    } else if (this.activeTab === 'slot') {
      this.refreshSlots();
    } else {
      this.refreshConfig(false);
    }
  }

  /** 手动刷新（头部刷新按钮）：配置页签走深刷新，重算瀑布顺序 */
  private manualRefresh(): void {
    if (this.activeTab === 'config') {
      this.refreshConfig(true);
    } else {
      this.refreshActive();
    }
  }

  /**
   * 刷新配置快照
   * @param deep 是否计算生效瀑布顺序（getAvailableAdPlatforms 对未知平台码会打日志，
   *              轮询路径关闭以避免日志面板被自身刷屏；展开与手动刷新时计算）
   */
  private refreshConfig(deep: boolean): void {
    const next: ConfigSnapshot = emptyConfig();
    next.adOpen = AdSwitchManager.isAdOpen;
    try {
      next.vip = VIPRepo.instance.props.vip;
    } catch (e) { /* ignore */ }

    try {
      const off = SDKCore.OFF;
      if (off && off.ss) {
        const codes: string[] = off.ss.split(',').filter((s: string) => s.trim() !== '');
        next.ssText = codes.join(', ');
        next.ssOrder = codes.map((c: string) => SERVER_SEQUENCE_MAP.get(c) ?? c);
        try {
          next.modeName = AdModeManager.getADModeName(AdModeManager.getADMode(off));
        } catch (e) { /* ignore */ }
        if (deep) {
          try {
            next.waterfall = AdModeManager.getAvailableAdPlatforms(off)
              .map((p: PlatformType) => getPlatformName(p));
          } catch (e) { /* ignore */ }
        } else {
          next.waterfall = this.cfg.waterfall;
        }
        const csj: string = `${AdSwitchManager.isCsj ? '启用' : '关闭'} (c=${off.c})`;
        const tx: string = `${AdSwitchManager.isTx ? '启用' : '关闭'} (t=${off.t})`;
        const hw: string = `${AdSwitchManager.isHw ? '启用' : '关闭'} (h=${off.h})`;
        next.csjText = csj;
        next.txText = tx;
        next.hwText = hw;
      }
    } catch (e) {
      // SDKCore.OFF 未就绪（请求未完成），保持默认占位
    }

    try {
      if (ForceChannelManager.isForceAdChannelEnabled()) {
        const p: PlatformType | null = ForceChannelManager.toPlatformType();
        next.forceChannel = p ? getPlatformName(p) : '已设置';
      }
    } catch (e) { /* ignore */ }

    this.cfg = next;
  }

  private refreshLogs(): void {
    const entries: LogEntry[] = LogManager.getLogEntriesByLevel(this.logFilter);
    const firstTs: number = entries.length > 0 ? entries[0].timestamp : -1;
    const filterKey: number = this.logFilter === null ? -1 : this.logFilter;
    if (entries.length === this.logCount && firstTs === this.logFirstTs
      && filterKey === this.logFilterKey) {
      // 无变化（含过滤条件未变），跳过重复渲染
      return;
    }
    this.logEntries = entries;
    this.logFirstTs = firstTs;
    this.logCount = entries.length;
    this.logFilterKey = filterKey;
    if (this.isScrollAtTop()) {
      this.scrollToTop();
    }
  }

  /** 日志列表是否停在顶部（决定新日志到来时是否自动吸顶） */
  private isScrollAtTop(): boolean {
    try {
      const offset = this.scroller.currentOffset();
      return offset.yOffset <= 8;
    } catch (e) {
      return true;
    }
  }

  private refreshSlots(): void {
    const rows: SlotRow[] = [];
    try {
      const slots: string[] = AdSlotManager.getInstance().getAllAdSlots();
      const platforms: PlatformType[] = [PlatformType.CSJ, PlatformType.TENCENT, PlatformType.HUAWEI];
      for (const slot of slots) {
        const ids: SlotPlatformId[] = [];
        for (const p of platforms) {
          const item: SlotPlatformId = {
            name: getPlatformName(p),
            realId: AdSlotManager.getInstance().peekRealAdId(slot, p) ?? ''
          };
          ids.push(item);
        }
        const row: SlotRow = { slot: slot, ids: ids };
        rows.push(row);
      }
    } catch (e) { /* ignore */ }
    this.slotRows = rows;
  }

  private refreshRequestLogs(): void {
    try {
      this.requestLogs = GlobalAdLoadLogStore.getInstance().getLogs();
    } catch (e) { /* ignore */ }
  }

  private scrollToTop(): void {
    try {
      this.scroller.scrollEdge(Edge.Top);
    } catch (e) { /* ignore */ }
  }

  // ==================== 层级切换 ====================

  /** 展开合并形态（图标列 + 面板） */
  private async openDock(): Promise<void> {
    this.clearIdleTimer();
    this.level = 1;
    this.runExpandAnimation(280, Curve.EaseOut, 1);
    const ctrl = AdDebugFloatController.getInstance();
    const mirrored: boolean = await ctrl.expandDock(DOCK_W, DOCK_H);
    this.mirrored = mirrored;
    this.refreshAll();
    this.armIdleTimer();
  }

  /** 收起为球，并把球移回图标列锚点 */
  private async collapseToBall(): Promise<void> {
    this.clearIdleTimer();
    this.level = 0;
    this.runExpandAnimation(220, Curve.EaseIn, 0);
    const ctrl = AdDebugFloatController.getInstance();
    await ctrl.collapseToBall(this.mirrored, this.mirrored ? DOCK_W - ICON_COL_W : 0);
    this.snapToEdge();
    this.armIdleTimer();
  }

  private autoCollapseToBall(): void {
    this.level = 0;
    this.runExpandAnimation(250, Curve.EaseIn, 0);
    const ctrl = AdDebugFloatController.getInstance();
    ctrl.collapseToBall(this.mirrored, this.mirrored ? DOCK_W - ICON_COL_W : 0);
    this.snapToEdge();
  }

  /**
   * 展开/收起过渡动画
   * 使用 UIContext.animateTo（替代 API 12 起废弃的全局 animateTo）；
   * 获取 UIContext 失败时直接应用终态，避免状态残留
   */
  private runExpandAnimation(duration: number, curve: Curve, progress: number): void {
    try {
      this.getUIContext().animateTo({ duration: duration, curve: curve }, () => {
        this.expandProgress = progress;
      });
    } catch (e) {
      this.expandProgress = progress;
    }
  }

  /** 点击图标列页签：切换页签；再次点击当前页签则收起 */
  private onTabTap(tab: string): void {
    if (tab === this.activeTab) {
      this.collapseToBall();
      return;
    }
    this.activeTab = tab;
    this.refreshActive();
    this.scrollToTop();
    this.armIdleTimer();
  }

  // ==================== 贴边 ====================

  /** 松手/超时：根据当前屏幕位置贴最近边（球半露） */
  private snapToNearestEdge(): void {
    const win = this.win;
    if (!win) return;
    try {
      const rect: window.Rect = win.getWindowProperties().windowRect;
      const uiCtx = Ohos.getUIContext();
      const screenW: number = uiCtx ? uiCtx.vp2px(360) : 360;
      const ballCenterX: number = rect.left + rect.width / 2;
      const isRight: boolean = ballCenterX > screenW / 2;
      // 球半露：贴左 x=-24，贴右 x=screenW-24
      const targetX: number = isRight ? screenW - 24 : -24;
      this.edgeRatio = isRight ? 1 : 0;
      win.moveWindowTo(targetX, rect.top);
    } catch (e) {
      // ignore
    }
  }

  /** 贴边：球一半露出，吸附最近屏幕边缘（超时/收起自动调用） */
  private snapToEdge(): void {
    this.snapToNearestEdge();
    AdDebugFloatController.getInstance().savePosition();
  }

  /** 从贴边恢复到屏幕内 */
  private restoreFromEdge(): void {
    const win = this.win;
    if (!win) return;
    try {
      const rect = win.getWindowProperties().windowRect;
      const targetX = this.edgeRatio === 1 ? rect.left - 28 : rect.left + 28;
      win.moveWindowTo(targetX, rect.top);
      this.edgeRatio = 0.5;
      AdDebugFloatController.getInstance().savePosition();
    } catch (e) {
      this.edgeRatio = 0.5;
    }
  }

  // ==================== 拖拽 ====================

  /** 拖拽：仅 L0 悬浮球可拖拽；松手后自动贴最近边；超时半隐 */
  private onDragTouch(event: TouchEvent): void {
    // 合并形态不可拖拽
    if (this.level > 0) {
      return;
    }
    this.clearIdleTimer();
    if (event.type === TouchType.Down) {
      try {
        this.win?.startMoving();
      } catch (e) {
        // ignore
      }
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      // 松手：根据当前屏幕位置贴最近边（半露）
      this.snapToNearestEdge();
      AdDebugFloatController.getInstance().savePosition();
      this.armIdleTimer();
    }
  }

  // ==================== 展示辅助 ====================

  private tabTitle(): string {
    switch (this.activeTab) {
      case 'log':
        return '日志';
      case 'slot':
        return '槽位';
      default:
        return '配置';
    }
  }

  private adTypeName(type: AdType): string {
    switch (type) {
      case AdType.SPLASH: return 'SPLASH';
      case AdType.VIDEO: return 'VIDEO';
      case AdType.INTERSTITIAL: return 'INTER';
      case AdType.FEED: return 'FEED';
      case AdType.BANNER: return 'BANNER';
      case AdType.NATIVE: return 'NATIVE';
      default: return 'UNK';
    }
  }

  private levelColor(level: LogLevel): string {
    switch (level) {
      case LogLevel.DEBUG: return '#90CAF9';
      case LogLevel.INFO: return '#81C784';
      case LogLevel.WARN: return '#FFB74D';
      case LogLevel.ERROR: return '#EF5350';
      default: return '#AAAAAA';
    }
  }

  private levelChar(level: LogLevel): string {
    switch (level) {
      case LogLevel.DEBUG: return 'D';
      case LogLevel.INFO: return 'I';
      case LogLevel.WARN: return 'W';
      case LogLevel.ERROR: return 'E';
      default: return '?';
    }
  }

  private formatTime(ts: number): string {
    try {
      const d: Date = new Date(ts);
      const pad = (n: number): string => n < 10 ? `0${n}` : `${n}`;
      return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}.${d.getMilliseconds()}`;
    } catch (e) {
      return '--:--:--';
    }
  }

  // ==================== UI ====================

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.level === 0) {
        this.BallView()
      } else {
        this.DockView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .hitTestBehavior(this.level === 0 ? HitTestMode.Transparent : HitTestMode.Default)
    .onTouch((e: TouchEvent) => {
      this.onDragTouch(e);
    })
  }

  // ---------- L0 悬浮球 ----------
  @Builder
  private BallView() {
    Stack({ alignContent: Alignment.Center }) {
      Text('AD')
        .fontSize(12)
        .fontColor('#333333')
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1)
    }
    .width(52)
    .height(52)
    .translate({ x: this.edgeRatio === 1 ? 24 : (this.edgeRatio === 0 ? -24 : 0) })
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .borderRadius(99)
    .clip(true)
    .scale({ x: 0.92 + 0.08 * this.expandProgress, y: 0.92 + 0.08 * this.expandProgress })
    .onClick(() => {
      // 半隐状态：第一次点击仅恢复全露，不展开
      if (this.edgeRatio !== 0.5) {
        this.restoreFromEdge();
        return;
      }
      // 全露状态：点击展开合并形态（L1 图标列 + L2 面板）
      this.openDock();
    })
  }

  // ---------- 合并形态：图标列 + 面板 ----------
  @Builder
  private DockView() {
    Row() {
      if (this.mirrored) {
        // 球贴右半屏：面板在左、图标列在右（镜像，保证不超出屏幕）
        this.PanelView()
        this.IconColumnView()
      } else {
        this.IconColumnView()
        this.PanelView()
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .backgroundBlurStyle(BlurStyle.Regular)
    .backgroundColor('#E61A1A2E')
    .shadow({ radius: 20, color: '#70000000', offsetX: 0, offsetY: 8 })
    .border({ width: 1, color: '#22FFFFFF' })
    .clip(true)
    .scale({
      x: 0.9 + 0.1 * this.expandProgress,
      y: 0.9 + 0.1 * this.expandProgress,
      centerX: this.mirrored ? '100%' : '0%',
      centerY: '0%'
    })
    .opacity(this.expandProgress)
  }

  // ---------- L1 图标列（仅功能入口，无开关） ----------
  @Builder
  private IconColumnView() {
    Column({ space: 12 }) {
      ForEach(DOCK_TABS, (tab: TabItem) => {
        Column() {
          Text(tab.glyph)
            .fontSize(15)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
          Text(tab.label)
            .fontSize(7)
            .fontColor('#E6FFFFFF')
            .margin({ top: 1 })
        }
        .width(44)
        .height(50)
        .borderRadius(12)
        .backgroundColor(tab.color)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .opacity(this.activeTab === tab.key ? 1 : 0.5)
        .border({ width: this.activeTab === tab.key ? 1.5 : 0, color: '#FFFFFF' })
        .animation({ duration: 180, curve: Curve.EaseOut })
        .onClick(() => {
          this.onTabTap(tab.key);
        })
      }, (tab: TabItem) => tab.key)
    }
    .width(ICON_COL_W)
    .height('100%')
    .padding({ top: 12, bottom: 12 })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .clip(true)
  }

  // ---------- L2 面板 ----------
  @Builder
  private PanelView() {
    Column() {
      // 头部：收起 + 标题 + 刷新
      Row() {
        Text('‹')
          .fontSize(18)
          .fontColor('#00E5FF')
          .padding({ left: 2, right: 8 })
          .onClick(() => {
            this.collapseToBall();
          })
        Text(this.tabTitle())
          .fontSize(13)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('刷新')
          .fontSize(10)
          .fontColor('#00E5FF')
          .padding({ left: 8, right: 2 })
          .onClick(() => {
            this.manualRefresh();
            this.armIdleTimer();
          })
      }
      .width('100%')
      .height(38)
      .padding({ left: 10, right: 10 })

      Divider().color('#22FFFFFF')

      Scroll(this.scroller) {
        Column() {
          if (this.activeTab === 'config') {
            this.ConfigContent()
          } else if (this.activeTab === 'log') {
            this.LogContent()
          } else {
            this.SlotContent()
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .layoutWeight(1)
    .height('100%')
    .clip(true)
  }

  // ---------- 配置页签 ----------
  @Builder
  private ConfigContent() {
    Column() {
      this.SectionHeader('广告开关')
      Row() {
        Text('广告总开关')
          .fontSize(10)
          .fontColor('#CCCCCC')
          .layoutWeight(1)
        this.SwitchPill(this.cfg.adOpen)
      }
      .width('100%')
      .margin({ bottom: 3 })

      this.Row2('VIP', this.cfg.vip ? '是' : '否', '#FFC107')
      this.Row2('当前模式', this.cfg.modeName, '#00E5FF')
      this.Row2('强制渠道', this.cfg.forceChannel,
        this.cfg.forceChannel === '未设置' ? '#777777' : '#FF8A65')

      this.SectionHeader('服务器规定顺序')
      this.Row2('ss 原文', this.cfg.ssText, '#00E5FF')
      this.ChipRow(this.cfg.ssOrder)

      this.SectionHeader('渠道启用')
      this.Row2('穿山甲 CSJ', this.cfg.csjText,
        this.cfg.csjText.startsWith('启用') ? '#4CAF50' : '#F44336')
      this.Row2('腾讯 TENCENT', this.cfg.txText,
        this.cfg.txText.startsWith('启用') ? '#4CAF50' : '#F44336')
      this.Row2('华为 HUAWEI', this.cfg.hwText,
        this.cfg.hwText.startsWith('启用') ? '#4CAF50' : '#F44336')

      this.SectionHeader('生效瀑布顺序')
      if (this.cfg.waterfall.length > 0) {
        this.ChipRow(this.cfg.waterfall)
      } else {
        Text('无可用平台（开关未开或全部熔断）')
          .fontSize(9)
          .fontColor('#777777')
          .margin({ bottom: 4 })
      }
    }
    .width('100%')
  }

  /** 广告总开关指示（调试态仅支持强制开启，与旧交互保持一致） */
  @Builder
  private SwitchPill(on: boolean) {
    Row() {
      Text(on ? 'ON' : 'OFF')
        .fontSize(9)
        .fontColor(on ? '#4CAF50' : '#F44336')
        .fontWeight(FontWeight.Bold)
    }
    .width(46)
    .height(20)
    .borderRadius(10)
    .backgroundColor(on ? '#334CAF50' : '#33F44336')
    .border({ width: 1, color: on ? '#4CAF50' : '#66F44336' })
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (!AdSwitchManager.isAdOpen) {
        AdSwitchManager.forceAdOpen();
      }
      this.refreshActive();
      this.armIdleTimer();
    })
  }

  // ---------- 日志页签 ----------
  @Builder
  private LogContent() {
    Column() {
      // 过滤条 + 清空
      Row() {
        ForEach(LOG_FILTERS, (f: LogFilterItem) => {
          Text(f.label)
            .fontSize(8)
            .fontColor(this.logFilter === f.level ? '#1E1E2E' : '#AAAAAA')
            .backgroundColor(this.logFilter === f.level ? '#00E5FF' : '#1AFFFFFF')
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .margin({ right: 4 })
            .onClick(() => {
              this.logFilter = f.level;
              this.refreshLogs();
              this.scrollToTop();
              this.armIdleTimer();
            })
        }, (f: LogFilterItem) => f.label)
        Blank()
        Text('清空')
          .fontSize(8)
          .fontColor('#FF8A65')
          .onClick(() => {
            LogManager.clearLogEntries();
            this.refreshLogs();
            this.armIdleTimer();
          })
      }
      .width('100%')
      .margin({ bottom: 6 })

      if (this.logEntries.length === 0) {
        Text('暂无日志')
          .fontSize(9)
          .fontColor('#777777')
          .margin({ top: 24 })
      }

      ForEach(this.logEntries, (entry: LogEntry, idx: number) => {
        Column() {
          Row() {
            Text(this.formatTime(entry.timestamp))
              .fontSize(7)
              .fontColor('#666666')
            Text(this.levelChar(entry.level))
              .fontSize(7)
              .fontColor(this.levelColor(entry.level))
              .fontWeight(FontWeight.Bold)
              .margin({ left: 4 })
            Text(entry.tag)
              .fontSize(7)
              .fontColor('#00B8D4')
              .margin({ left: 4 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')

          Text(entry.message)
            .fontSize(8)
            .fontColor('#DDDDDD')
            .width('100%')
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 1 })
        }
        .width('100%')
        .padding({ left: 6, right: 6, top: 4, bottom: 4 })
        .backgroundColor(idx % 2 === 0 ? '#0DFFFFFF' : Color.Transparent)
        .borderRadius(4)
        .margin({ bottom: 2 })
        .alignItems(HorizontalAlign.Start)
      }, (entry: LogEntry, idx: number) => `${entry.timestamp}_${idx}`)

      // 请求记录（瀑布加载日志）
      this.SectionHeader('请求记录')
      if (this.requestLogs.length === 0) {
        Text('暂无请求记录')
          .fontSize(9)
          .fontColor('#777777')
      }
      ForEach(this.requestLogs.slice(0, 6), (entry: GlobalAdLogEntry, idx: number) => {
        Column() {
          Row() {
            Text(this.adTypeName(entry.adType))
              .fontSize(8)
              .fontColor('#00E5FF')
            Text(entry.adSlot)
              .fontSize(8)
              .fontColor('#AAAAAA')
              .margin({ left: 4 })
            Blank()
            Text(entry.isSuccess ? 'OK' : 'FAIL')
              .fontSize(8)
              .fontColor(entry.isSuccess ? '#4CAF50' : '#F44336')
            Text(`${entry.totalDuration}ms`)
              .fontSize(8)
              .fontColor('#666666')
              .margin({ left: 4 })
          }
          .width('100%')

          if (entry.diagnosticText) {
            Text(entry.diagnosticText)
              .fontSize(7)
              .fontColor('#777777')
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
          }
        }
        .width('100%')
        .padding(5)
        .backgroundColor('#0DFFFFFF')
        .borderRadius(5)
        .margin({ bottom: 3 })
        .alignItems(HorizontalAlign.Start)
      }, (entry: GlobalAdLogEntry, idx: number) => `req_${entry.timestamp}_${idx}`)
    }
    .width('100%')
  }

  // ---------- 槽位页签 ----------
  @Builder
  private SlotContent() {
    Column() {
      if (this.slotRows.length === 0) {
        Text('暂无注册槽位')
          .fontSize(9)
          .fontColor('#777777')
          .margin({ top: 24 })
      }

      ForEach(this.slotRows, (row: SlotRow) => {
        Column() {
          Row() {
            Text(row.slot)
              .fontSize(10)
              .fontColor('#FFC107')
              .fontWeight(FontWeight.Bold)
            Blank()
            Text(`${row.ids.filter((i: SlotPlatformId) => i.realId !== '').length}/${row.ids.length}`)
              .fontSize(8)
              .fontColor('#888888')
          }
          .width('100%')

          ForEach(row.ids, (item: SlotPlatformId) => {
            Row() {
              Text(item.name)
                .fontSize(8)
                .fontColor('#00B8D4')
                .backgroundColor('#1A00B8D4')
                .borderRadius(3)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              Text(item.realId !== '' ? item.realId : '未注册')
                .fontSize(9)
                .fontColor(item.realId !== '' ? '#E0E0E0' : '#666666')
                .margin({ left: 6 })
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .margin({ top: 3 })
          }, (item: SlotPlatformId) => `${row.slot}_${item.name}`)
        }
        .width('100%')
        .padding(6)
        .backgroundColor('#0DFFFFFF')
        .borderRadius(6)
        .margin({ bottom: 6 })
        .alignItems(HorizontalAlign.Start)
      }, (row: SlotRow) => row.slot)
    }
    .width('100%')
  }

  // ==================== 子组件 ====================

  @Builder
  private SectionHeader(title: string) {
    Text(title)
      .fontSize(10)
      .fontColor('#FFC107')
      .fontWeight(FontWeight.Bold)
      .width('100%')
      .margin({ top: 8, bottom: 4 })
  }

  @Builder
  private Row2(key: string, value: string, valueColor: string) {
    Row() {
      Text(key).fontSize(9).fontColor('#999999').layoutWeight(1)
      Text(value).fontSize(9).fontColor(valueColor)
    }
    .width('100%')
    .margin({ bottom: 2 })
  }

  @Builder
  private ChipRow(items: string[]) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(items, (item: string) => {
        Text(item)
          .fontSize(9)
          .fontColor('#00E5FF')
          .backgroundColor('#2200E5FF')
          .borderRadius(4)
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .margin({ right: 5, bottom: 4 })
      }, (item: string) => item)
    }
    .width('100%')
    .margin({ bottom: 4 })
  }
}
