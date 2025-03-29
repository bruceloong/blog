---
date: "2023-03-31T23:30:23+08:00"
draft: true
title: "React Event System"
---

# 揭秘 React 事件系统：从源码看原理与优化

最近在研发团队内做了一次关于 React 事件系统的分享，反响不错，决定整理成文章分享出来。这是我读 React 源码系列的第二篇，上次分析了虚拟 DOM 的实现细节，这次聚焦事件系统。

## 事件系统：被误解的 React 核心机制

大多数 React 开发者可能知道 React 有自己的事件系统，但很少有人能说清它到底做了什么。翻开源码后才发现，React 的事件系统是个精心设计的复杂机制，远不止是简单的"语法糖"。

```jsx
// 常见的React事件绑定
<button onClick={handleClick}>点击</button>
```

这行看似普通的代码背后，隐藏着一整套事件处理机制。

## 事件委托：理解 React 的事件绑定

第一个关键发现：**React 并不会把事件直接绑定在 DOM 元素上**。

在 React 17 之前，所有事件都被委托到 document 节点上；React 17 之后，改为委托到 React 树的根 DOM 容器上：

```javascript
// React 17前后的事件绑定位置变化（简化的源码）
// React 16
document.addEventListener("click", dispatchEvent);

// React 17+
rootNode.addEventListener("click", dispatchEvent);
```

通过查看 Chrome DevTools 的 Event Listeners 面板，你会发现真正的事件监听器并不在你写 JSX 的元素上，而是在根节点上。

这种事件委托有几个重要好处：

- 减少内存占用（不用为每个元素都绑定事件）
- 动态添加的元素也能响应事件
- 简化了 React Fiber 树的更新逻辑

## 合成事件：不只是包装原生事件那么简单

React 的`SyntheticEvent`对象是对原生 DOM 事件的包装，但它做了很多额外工作：

```javascript
// React 17中合成事件的创建（简化版）
function createSyntheticEvent(
  reactName,
  reactEventType,
  targetInst,
  nativeEvent,
  nativeEventTarget
) {
  const event = new SyntheticBaseEvent(
    nativeEvent.type,
    nativeEventTarget ? nativeEventTarget.ownerDocument : null,
    nativeEvent,
    nativeEventTarget
  );

  // 添加特定事件类型的属性
  accumulateEventHandleNonManagedNodeListeners(
    targetInst,
    dispatchListener,
    event,
    true
  );

  return event;
}
```

有趣的是，React 合成事件实现了 W3C 标准，**解决了各浏览器的兼容性差异**。比如：

- 统一了事件属性名和行为
- 标准化了事件冒泡和捕获
- 处理了 IE 等浏览器的兼容问题

在一个跨境电商项目中，我们发现国内外用户使用的浏览器版本差异很大，但 React 的合成事件让我们几乎不用担心兼容性问题。

## 事件流与执行机制：从捕获到冒泡

源码中，React 的事件处理分为三个阶段：

1. 收集阶段：沿着 DOM 树收集所有注册的事件处理器
2. 排序阶段：根据事件类型和阶段（捕获/冒泡）排序
3. 执行阶段：按顺序触发事件处理器

```javascript
// 收集事件处理函数的简化代码
function traverseTwoPhase(inst, fn, arg) {
  const path = [];
  while (inst) {
    path.push(inst);
    inst = getParent(inst);
  }

  // 捕获阶段 - 从上往下
  for (let i = path.length; i-- > 0; ) {
    fn(path[i], "captured", arg);
  }

  // 冒泡阶段 - 从下往上
  for (let i = 0; i < path.length; i++) {
    fn(path[i], "bubbled", arg);
  }
}
```

这解释了为什么 React 支持`onClickCapture`这样的捕获阶段事件处理。

在一个拖拽组件库的开发中，我曾利用 React 的事件流机制在捕获阶段拦截和处理鼠标事件，避免了拖拽过程中的事件冲突。

## 事件池的变化：React 17 的重大改进

在 React 16 及之前的版本中，有一个常见陷阱是异步访问事件对象：

```javascript
function handleClick(event) {
  setTimeout(() => {
    console.log(event.target.value); // React 16: null, React 17+: 正常值
  }, 100);
}
```

源码中可以看到，React 16 使用了事件池来重用事件对象，这导致事件处理函数执行完毕后，事件对象的属性会被清空：

```javascript
// React 16的事件池机制
class SyntheticEvent {
  constructor(dispatchConfig, targetInst, nativeEvent, nativeEventTarget) {
    // ...初始化事件属性
  }

  // 在事件处理完成后调用
  release() {
    const EventConstructor = this.constructor;
    if (EventConstructor.eventPool.length < EVENT_POOL_SIZE) {
      EventConstructor.eventPool.push(this);
    }
    // 清空所有属性
    this.destructor();
  }
}
```

而 React 17 完全移除了事件池，解决了这个常见问题。源码中不再有`release()`方法和对象复用逻辑，让事件对象的行为更符合直觉。

## React 17 的事件系统重构：为什么要改？

阅读 React 17 的源码，发现事件系统进行了重大重构，主要变化有：

1. 将事件委托从 document 改为根容器
2. 取消事件池机制
3. 与浏览器事件系统对齐（如 onFocus 和 onBlur 的冒泡行为）
4. 简化内部实现，移除了遗留代码

为什么要做这些改变？官方博客没有详细解释，但通过源码分析，我认为主要原因有：

- 支持 React 多版本并存（不同 React 版本的事件不会相互干扰）
- 减少与第三方库的冲突（比如 modal 库的事件传播问题）
- 简化内部实现，为未来的 Concurrent Mode 铺路

在一个大型应用的微前端迁移过程中，这个变化帮我们解决了多个 React 版本并存时的事件冲突问题。

## 事件系统的性能问题与优化

通过 React DevTools 的 Profiler 分析，发现在高频事件（如滚动、拖拽）中，React 的事件系统可能成为性能瓶颈。源码中的一些注释也提到了这点：

```javascript
// 在React事件源码中的注释
// TODO: This is a "almost-duplicate" of the checkResponderAndRequestId
// function in the touch responder system. We should see if we can share
// some logic.
```

针对这些问题，有几个实用的优化手段：

1. 使用节流/防抖处理高频事件：

```javascript
function useThrottledScroll(callback, delay) {
  const throttledCallback = useCallback(throttle(callback, delay), [
    callback,
    delay,
  ]);

  useEffect(() => {
    window.addEventListener("scroll", throttledCallback);
    return () => window.removeEventListener("scroll", throttledCallback);
  }, [throttledCallback]);
}
```

2. 考虑使用原生事件绕过 React 事件系统（谨慎使用）：

```javascript
function DirectEventComponent() {
  const ref = useRef(null);

  useEffect(() => {
    const handleMouseMove = (e) => {
      // 高性能处理，绕过React事件系统
    };

    const element = ref.current;
    element.addEventListener("mousemove", handleMouseMove);
    return () => element.removeEventListener("mousemove", handleMouseMove);
  }, []);

  return <div ref={ref}>高性能交互区域</div>;
}
```

在一个数据可视化项目中，我们发现 Canvas 上的鼠标交互使用原生事件比 React 合成事件有明显的性能提升。

## 调试 React 事件的技巧

面对复杂的事件处理问题，我总结了几个实用调试技巧：

1. 使用 Chrome DevTools 的 Event Listeners 面板查看真实绑定情况
2. 在事件处理函数中使用`event.nativeEvent`查看原生事件对象
3. 添加断点跟踪事件流经过的路径

```javascript
function debugEvent(event) {
  console.log("合成事件:", event);
  console.log("原生事件:", event.nativeEvent);
  console.log("当前目标:", event.currentTarget);
  console.log("事件目标:", event.target);
  console.log("事件类型:", event.type);
  console.log("事件阶段:", event.eventPhase);
  // 0: 没有事件正在被处理
  // 1: 捕获阶段
  // 2: 目标阶段
  // 3: 冒泡阶段
}
```

这个调试函数帮我解决过很多难以重现的事件问题。

## 事件系统与未来 Concurrent Mode 的关系

React 事件系统的设计与未来的 Concurrent Mode 紧密相关。阅读源码后发现，React 17 的事件系统重构部分原因是为了支持 React 的并发渲染机制：

```javascript
// 简化的React事件处理优先级
function dispatchEvent(
  topLevelType,
  eventSystemFlags,
  targetContainer,
  nativeEvent
) {
  // ...

  // 根据事件类型确定优先级
  const eventPriority = getEventPriority(topLevelType);

  let schedulerPriority;
  switch (eventPriority) {
    case DiscreteEventPriority:
      schedulerPriority = ImmediateSchedulerPriority;
      break;
    case ContinuousEventPriority:
      schedulerPriority = UserBlockingSchedulerPriority;
      break;
    case DefaultEventPriority:
      schedulerPriority = NormalSchedulerPriority;
      break;
    case IdleEventPriority:
      schedulerPriority = IdleSchedulerPriority;
      break;
    default:
      schedulerPriority = NormalSchedulerPriority;
      break;
  }

  // 以适当的优先级调度更新
  runWithPriority(schedulerPriority, () => {
    // 处理事件...
  });
}
```

这段代码展示了事件如何影响更新的优先级，例如键盘输入等离散事件会获得更高的优先级，而滚动等连续事件则获得较低优先级。

在处理复杂表单的项目中，我们利用这种事件优先级机制，使得用户输入保持流畅，同时后台计算不会阻塞 UI 响应。

## 写在最后

深入研究 React 事件系统后，我对 React 的理解更上一层楼。虽然大部分时候我们不需要考虑事件系统的内部实现，但了解其原理对解决复杂问题、性能优化和处理边缘情况非常有价值。

我发现阅读框架源码的最大收获不仅是了解"它是如何实现的"，更重要的是理解"为什么要这样实现"。React 事件系统的设计充分体现了 React 团队对开发体验、跨平台兼容性和性能的平衡考虑。

下次计划分享 React Hook 的实现原理，敬请期待。
