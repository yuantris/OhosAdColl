/**
 * ExclusiveNotification 测试示例
 * 竞争响应通知类测试
 */

import { ExclusiveNotification, createNotification } from '../main/ets/ohos/helper/core/ExclusiveNotification';

// 测试函数
export function testExclusiveNotification() {
  console.log('=== ExclusiveNotification 测试开始 ===\n');

  // 测试1: 基本用法
  testBasicUsage();

  // 测试2: 优先级测试
  testPriority();

  // 测试3: 节流测试
  testThrottle();

  // 测试4: 多次触发测试
  testMultipleEmits();

  // 测试5: 自动移除监听者测试
  testAutoRemoveListener();

  console.log('=== ExclusiveNotification 测试结束 ===');
}

/**
 * 测试1: 基本用法
 */
function testBasicUsage() {
  console.log('--- 测试1: 基本用法 ---');

  // 创建通知实例
  const notification = ExclusiveNotification.getInstance<string>('test-basic', 1000);

  // 添加多个监听者
  let listenerACount = 0;
  let listenerBCount = 0;

  notification.on((data) => {
    listenerACount++;
    console.log('监听者A 收到:', data, ` (第${listenerACount}次)`);
  }, 'listener-A');

  notification.on((data) => {
    listenerBCount++;
    console.log('监听者B 收到:', data, ` (第${listenerBCount}次)`);
  }, 'listener-B');

  // 发送通知
  console.log('发送第一次通知...');
  const result1 = notification.emit('通知1');
  console.log('通知1 是否触发:', result1);
  console.log('当前监听者数量:', notification.getListenerCount());
  console.log('');

  // 发送第二次通知（应该会触发另一个监听者）
  console.log('发送第二次通知...');
  const result2 = notification.emit('通知2');
  console.log('通知2 是否触发:', result2);
  console.log('当前监听者数量:', notification.getListenerCount());
  console.log('');

  // 发送第三次通知（没有监听者了）
  console.log('发送第三次通知...');
  const result3 = notification.emit('通知3');
  console.log('通知3 是否触发:', result3);
  console.log('当前监听者数量:', notification.getListenerCount());
  console.log('');
}

/**
 * 测试2: 优先级测试
 */
function testPriority() {
  console.log('--- 测试2: 优先级测试 ---');

  // 创建通知实例
  const notification = ExclusiveNotification.getInstance<string>('test-priority', 1000);

  // 添加不同优先级的监听者
  let highPriorityCount = 0;
  let mediumPriorityCount = 0;
  let lowPriorityCount = 0;

  notification.on((data) => {
    highPriorityCount++;
    console.log('高优先级监听者 收到:', data, ` (第${highPriorityCount}次)`);
  }, 'high-priority', 100); // 优先级100

  notification.on((data) => {
    mediumPriorityCount++;
    console.log('中优先级监听者 收到:', data, ` (第${mediumPriorityCount}次)`);
  }, 'medium-priority', 50); // 优先级50

  notification.on((data) => {
    lowPriorityCount++;
    console.log('低优先级监听者 收到:', data, ` (第${lowPriorityCount}次)`);
  }, 'low-priority', 0); // 优先级0

  // 发送通知（应该优先触发高优先级监听者）
  console.log('发送通知，优先级高的应该先响应...');
  notification.emit('优先级测试');
  console.log('');

  // 清理
  ExclusiveNotification.removeInstance('test-priority');
}

/**
 * 测试3: 节流测试
 */
function testThrottle() {
  console.log('--- 测试3: 节流测试 ---');

  // 创建通知实例（节流时间500ms）
  const notification = ExclusiveNotification.getInstance<string>('test-throttle', 500);

  let triggerCount = 0;

  notification.on((data) => {
    triggerCount++;
    console.log('监听者 收到:', data, ` (第${triggerCount}次)`);
  }, 'throttle-listener');

  // 第一次发送
  console.log('发送第一次通知...');
  const result1 = notification.emit('通知1');
  console.log('触发结果:', result1);
  console.log('是否在节流时间内:', notification.isThrottled());
  console.log('');

  // 立即第二次发送（应该在节流时间内，不会触发）
  console.log('立即发送第二次通知（应该在节流时间内）...');
  const result2 = notification.emit('通知2');
  console.log('触发结果:', result2);
  console.log('是否在节流时间内:', notification.isThrottled());
  console.log('');

  // 等待500ms后发送（应该触发）
  setTimeout(() => {
    console.log('等待500ms后发送第三次通知...');
    const result3 = notification.emit('通知3');
    console.log('触发结果:', result3);
    console.log('是否在节流时间内:', notification.isThrottled());
    console.log('');

    // 清理
    ExclusiveNotification.removeInstance('test-throttle');
  }, 600);
}

/**
 * 测试4: 多次触发测试
 */
function testMultipleEmits() {
  console.log('--- 测试4: 多次触发测试 ---');

  const notification = ExclusiveNotification.getInstance<string>('test-multiple', 1000);

  let listener1Count = 0;
  let listener2Count = 0;
  let listener3Count = 0;

  notification.on((data) => {
    listener1Count++;
    console.log('监听者1 收到:', data);
  }, 'listener-1');

  notification.on((data) => {
    listener2Count++;
    console.log('监听者2 收到:', data);
  }, 'listener-2');

  notification.on((data) => {
    listener3Count++;
    console.log('监听者3 收到:', data);
  }, 'listener-3');

  console.log('初始监听者数量:', notification.getListenerCount());

  // 连续发送3次通知
  console.log('\n发送第1次通知...');
  notification.emit('第1次');
  console.log('当前监听者数量:', notification.getListenerCount());

  console.log('\n发送第2次通知...');
  notification.emit('第2次');
  console.log('当前监听者数量:', notification.getListenerCount());

  console.log('\n发送第3次通知...');
  notification.emit('第3次');
  console.log('当前监听者数量:', notification.getListenerCount());

  console.log('\n最终统计:');
  console.log('监听者1 触发次数:', listener1Count);
  console.log('监听者2 触发次数:', listener2Count);
  console.log('监听者3 触发次数:', listener3Count);
  console.log('');

  // 清理
  ExclusiveNotification.removeInstance('test-multiple');
}

/**
 * 测试5: 自动移除监听者测试
 */
function testAutoRemoveListener() {
  console.log('--- 测试5: 自动移除监听者测试 ---');

  const notification = ExclusiveNotification.getInstance<number>('test-autoremove', 1000);

  let tempListenerCount = 0;

  // 添加临时监听者
  notification.on((data) => {
    tempListenerCount++;
    console.log('临时监听者 收到:', data);
  }, 'temp-listener');

  console.log('添加临时监听者后，监听者数量:', notification.getListenerCount());

  // 发送通知
  notification.emit(1);
  console.log('发送第一次通知后，监听者数量:', notification.getListenerCount());

  // 再次发送通知
  notification.emit(2);
  console.log('发送第二次通知后，监听者数量:', notification.getListenerCount());

  console.log('临时监听者触发次数:', tempListenerCount);
  console.log('');

  // 清理
  ExclusiveNotification.removeInstance('test-autoremove');
}

/**
 * 实际应用示例：广告展示通知
 */
export function testAdShowNotification() {
  console.log('--- 实际应用: 广告展示通知 ---');

  const adShowNotification = ExclusiveNotification.getInstance<{
    adId: string;
    adType: string;
  }>('ad-show', 2000);

  let splashCount = 0;
  let feedCount = 0;
  let rewardCount = 0;

  // 开屏广告监听
  adShowNotification.on((data) => {
    if (data.adType === 'splash') {
      splashCount++;
      console.log('开屏广告展示:', data.adId);
    }
  }, 'splash-ad');

  // 信息流广告监听
  adShowNotification.on((data) => {
    if (data.adType === 'feed') {
      feedCount++;
      console.log('信息流广告展示:', data.adId);
    }
  }, 'feed-ad');

  // 激励视频监听（优先级最高）
  adShowNotification.on((data) => {
    if (data.adType === 'reward') {
      rewardCount++;
      console.log('激励视频展示:', data.adId);
    }
  }, 'reward-ad', 100);

  // 展示激励视频
  console.log('展示激励视频...');
  adShowNotification.emit({ adId: 'reward_001', adType: 'reward' });
  console.log('当前监听者数量:', adShowNotification.getListenerCount());
  console.log('');

  // 展示信息流广告
  console.log('展示信息流广告...');
  adShowNotification.emit({ adId: 'feed_001', adType: 'feed' });
  console.log('当前监听者数量:', adShowNotification.getListenerCount());
  console.log('');

  console.log('统计: 开屏广告=' + splashCount + ', 信息流广告=' + feedCount + ', 激励视频=' + rewardCount);
  console.log('');

  // 清理
  ExclusiveNotification.removeInstance('ad-show');
}
