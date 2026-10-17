import { PageInfo, uiObserver, window } from '@kit.ArkUI';
import { Log } from '@zycore/common';
import ADUtil from '../util/ADUtil';

export interface UnifiedRouteEvent {
  routeType: 'router' | 'nav';
  pageName: string;
  pagePath: string;
  navigationId: ResourceStr; // 仅Nav导航有效
  pageId: string;
  params?: ESObject;
  timestamp: number;
  eventType: string;
}

export class LRUCache {
  private maxSize: number = 30;
  private cacheList: Array<PageInfo> = new Array();

  add(info: PageInfo): void {
    // 移除已存在的相同条目
    const index = this.cacheList.findIndex((item) =>
    item.routerPageInfo?.path === info.routerPageInfo?.path &&
      item.navDestinationInfo?.navigationId === info.navDestinationInfo?.navigationId
    );
    if (index !== -1) {
      this.cacheList.splice(index, 1);
    }

    // 添加到头部
    this.cacheList.unshift(info);

    // 如果超过最大大小，移除最旧的
    if (this.cacheList.length > this.maxSize) {
      this.cacheList.pop();
    }
  }

  getLatest(): PageInfo | undefined {
    return this.cacheList.length > 0 ? this.cacheList[0] : undefined;
  }

  getAll(): Array<PageInfo> {
    return this.cacheList;
  }
}

export class RouteEventBus {
  private static instance: RouteEventBus;
  private listeners: Map<string, (event: UnifiedRouteEvent) => void> = new Map();
  private lastEvent?: UnifiedRouteEvent
  private lastPublishedEvent: UnifiedRouteEvent | null = null;
  private lastPublishTime: number = 0;
  public static pageInfoCache = new LRUCache();

  static getInstance() {
    if (!RouteEventBus.instance) {
      RouteEventBus.instance = new RouteEventBus();
    }
    return RouteEventBus.instance;
  }

  subscribe(listener: (event: UnifiedRouteEvent) => void, key?: string): () => void {
    const listenerKey = key || listener.toString();
    if (!this.listeners.has(listenerKey)) {
      this.listeners.set(listenerKey, listener);
    }
    return () => this.unsubscribe(listenerKey);
  }

  unsubscribe(key: string | ((event: UnifiedRouteEvent) => void)): void {
    if (typeof key === 'function') {
      const entries = Array.from(this.listeners.entries());
      entries.forEach((entry) => {
        const k = entry[0];
        const v = entry[1];
        if (v === key) {
          this.listeners.delete(k);
        }
      })
    } else {
      this.listeners.delete(key);
    }
  }

  publish(event: UnifiedRouteEvent) {
    const safeCopy = (obj: ESObject | undefined): ESObject | undefined => {
      if (!obj) {
        return undefined;
      }
      try {
        return JSON.parse(JSON.stringify(obj));
      } catch (e) {
        console.error('Failed to deep copy params:', e);
        return undefined;
      }
    };

    const safeEvent: UnifiedRouteEvent = {
      routeType: event.routeType,
      pageName: event.pageName,
      pagePath: event.pagePath,
      navigationId: event.navigationId,
      pageId: event.pageId,
      timestamp: event.timestamp,
      eventType: event.eventType,
      params: safeCopy(event.params)
    };

    const isDuplicate = this.lastPublishedEvent?.pageId === safeEvent.pageId
      && this.lastPublishedEvent?.eventType === safeEvent.eventType
      && safeEvent.timestamp - this.lastPublishTime < 300
      && this.lastPublishedEvent?.routeType === safeEvent.routeType;

    if (!isDuplicate) {
      this.lastEvent = safeEvent;
      this.lastPublishedEvent = safeEvent;
      this.lastPublishTime = Date.now();
      this.listeners.forEach(listener => {
        try {
          listener(safeEvent);
        } catch (e) {
          console.error('Error in route event listener:', e);
        }
      });
    }
  }

  getLastEvent(): UnifiedRouteEvent | undefined {
    return this.lastEvent;
  }
}

export function lifecycleCallbackTest(windowStage: window.WindowStage) {
  const context = windowStage.getMainWindowSync().getUIContext();
  const eventBus = RouteEventBus.getInstance();

  // Nav切换监听
  uiObserver.on('navDestinationSwitch', context, (info: uiObserver.NavDestinationSwitchInfo) => {
    ADUtil.logD('RouterEvent', 'navDestinationSwitch--')
    const from = info.from as NavDestinationInfo;
    const to = info.to as NavDestinationInfo;
    Log.warn(`event: ${info.to}`)
    if (from.state == uiObserver.NavDestinationState.ON_HIDDEN) {
      eventBus.publish({
        routeType: 'nav',
        pageName: `${from.name}`,
        pagePath: `nav://${from.name}`,
        navigationId: from.navigationId,
        pageId: `${from.navigationId}`,
        timestamp: Date.now(),
        eventType: 'hide'
      });
    }

    if (to.state === uiObserver.NavDestinationState.ON_SHOWN) {
      eventBus.publish({
        routeType: 'nav',
        pageName: `${to.name}`,
        pagePath: `nav://${to.name}`,
        navigationId: to.navigationId,
        pageId: `${to.navigationId}`,
        timestamp: Date.now(),
        eventType: 'show'
      });
    }

  });

  // Nav更新监听
  uiObserver.on('navDestinationUpdate', (info: uiObserver.NavDestinationInfo) => {
    ADUtil.logD('RouterEvent', `navDestinationUpdate--${info.name}_${info.state}`)
    // AppStorage.setOrCreate('currentNavDestination', info);
    const pageInfo = {
      routerPageInfo: undefined,
      navDestinationInfo: info
    } as PageInfo
    RouteEventBus.pageInfoCache.add(pageInfo)

    Log.warn(`event: ${info.name}`)
    const eventTypeMap = new Map([
      [uiObserver.NavDestinationState.ON_SHOWN, 'show'],
      [uiObserver.NavDestinationState.ON_HIDDEN, 'hide'],
      [uiObserver.NavDestinationState.ON_APPEAR, 'appear'],
      [uiObserver.NavDestinationState.ON_DISAPPEAR, 'disappear']
    ]);

    const eventType = eventTypeMap.get(info.state);
    if (eventType) {
      eventBus.publish({
        routeType: 'nav',
        pageName: `${info.name}`,
        pagePath: `nav://${info.name}`,
        navigationId: info.navigationId,
        pageId: `${info.navigationId}`,
        params: info.param,
        timestamp: Date.now(),
        eventType: eventType
      });
    }
  });

  // 路由监听
  uiObserver.on('routerPageUpdate', context, (info: uiObserver.RouterPageInfo) => {
    // AppStorage.setOrCreate('currentRouterPage', info);

    const pageInfo = {
      routerPageInfo: info,
      navDestinationInfo: undefined
    } as PageInfo

    RouteEventBus.pageInfoCache.add(pageInfo)

    const eventTypeMap = new Map([
      [uiObserver.RouterPageState.ON_PAGE_SHOW, 'show'],
      [uiObserver.RouterPageState.ON_PAGE_HIDE, 'hide'],
      [uiObserver.RouterPageState.ABOUT_TO_APPEAR, 'appear'],
      [uiObserver.RouterPageState.ABOUT_TO_DISAPPEAR, 'disappear']
    ]);

    const eventType = eventTypeMap.get(info.state);
    if (eventType) {
      eventBus.publish({
        routeType: 'router',
        pageName: info.name,
        pagePath: info.path,
        navigationId: '',
        pageId: info.pageId,
        params: undefined,
        timestamp: Date.now(),
        eventType: eventType
      });
    }
  });
}

export function subscribeToRouteChanges(listener: (event: UnifiedRouteEvent) => void) {
  return RouteEventBus.getInstance().subscribe(listener);
}

export function getLastEvent() {
  return RouteEventBus.getInstance().getLastEvent()
}

export function getPageInfo(): PageInfo {
  let r: RouterPageInfo = AppStorage.get('currentRouterPage') as RouterPageInfo;
  let n: NavDestinationInfo = AppStorage.get('currentNavDestination') as NavDestinationInfo;

  // return {
  //   routerPageInfo: AppStorage.get('currentRouterPage'),
  //   navDestinationInfo: AppStorage.get('currentNavDestination')
  // };
  return RouteEventBus.pageInfoCache.getLatest() as PageInfo
}

export function getUniqueID(info?: PageInfo) {
  let id = '';
  if (info?.routerPageInfo) {
    id += info.routerPageInfo.name;
    id += '_';
    id += info.routerPageInfo.path;
  }
  id += '_';
  if (info?.navDestinationInfo) {
    id += info.navDestinationInfo.name;
    id += info.navDestinationInfo.uniqueId;
  }
  return id;
}

export function getPageName(info: PageInfo) {
  let name = '';

  if (info.navDestinationInfo) {
    name += info.navDestinationInfo.name;
  } else {
    name += info.routerPageInfo?.name;
  }
  return name;
}