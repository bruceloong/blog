---
date: "2023-03-29T23:26:33+08:00"
draft: false
title: "React Virtual Dom"
---

# 拆解 React 虚拟 DOM：源码分析与实战思考

最近几周在重构公司的一个核心项目，借此机会深入研读了 React 源码，尤其是虚拟 DOM 相关的实现。虽然网上关于虚拟 DOM 的文章不少，但很多停留在表面概念上，没有真正深入到源码细节。这篇文章我想从源码角度分享一些发现和思考。

## 虚拟 DOM 的本质：不只是性能优化

我们常听说虚拟 DOM 是为了提高性能，但读源码后发现，性能优化其实只是它的附加效果之一。虚拟 DOM 更本质的价值在于提供了一个中间抽象层，简化了 UI 编程模型。

React 中的虚拟 DOM 实际上是一个普通的 JavaScript 对象，大致结构如下:

```javascript
// React元素的简化结构
{
  $$typeof: Symbol(react.element),
  type: 'div',
  key: null,
  props: {
    className: 'container',
    children: [
      {
        $$typeof: Symbol(react.element),
        type: 'h1',
        props: { children: 'Hello' },
        // ...其他属性
      }
    ]
  },
  ref: null,
  // ...其他内部属性
}
```

`$$typeof`是防止 XSS 攻击的安全措施，它是一个 Symbol，不能在 JSON 中被表示。

## Fiber 架构中的虚拟 DOM

在 React 16 引入 Fiber 架构后，虚拟 DOM 的实现变得更加复杂。Fiber 节点不仅包含了虚拟 DOM 的信息，还包含了调度和渲染相关的额外字段:

```javascript
// Fiber节点简化结构
{
  // 静态数据结构
  tag: WorkTag,
  key: null | string,
  elementType: any,
  type: any,
  stateNode: any,

  // Fiber链表结构
  return: Fiber | null,
  child: Fiber | null,
  sibling: Fiber | null,
  index: number,

  // 工作相关
  pendingProps: any,
  memoizedProps: any,
  memoizedState: any,
  updateQueue: UpdateQueue<any> | null,

  // 副作用相关
  flags: Flags,
  subtreeFlags: Flags,
  deletions: Array<Fiber> | null,

  // 优先级相关
  lanes: Lanes,
  childLanes: Lanes,

  // 交替Fiber（双缓冲）
  alternate: Fiber | null,
}
```

从这个结构可以看出，Fiber 节点远比虚拟 DOM 复杂，它不仅代表 UI，还承载了整个渲染和调度的实现细节。

## Diff 算法：不是想象中那么复杂

通过阅读源码，我发现 React 的 diff 算法比想象中简单，它基于三个假设:

1. 不同类型的元素会产生不同的树
2. 开发者可以通过 key 属性暗示哪些子元素在不同渲染中保持稳定
3. 同级比较，不跨层级

实际的 diff 实现主要在`reconcileChildFibers`函数中:

```javascript
function reconcileChildFibers(
  returnFiber: Fiber,
  currentFirstChild: Fiber | null,
  newChild: any,
  lanes: Lanes
): Fiber | null {
  // 处理单个元素
  if (typeof newChild === "object" && newChild !== null) {
    switch (newChild.$$typeof) {
      case REACT_ELEMENT_TYPE:
        return placeSingleChild(
          reconcileSingleElement(
            returnFiber,
            currentFirstChild,
            newChild,
            lanes
          )
        );
      // ... 其他类型处理
    }
  }

  // 处理文本节点
  if (typeof newChild === "string" || typeof newChild === "number") {
    return placeSingleChild(
      reconcileSingleTextNode(
        returnFiber,
        currentFirstChild,
        "" + newChild,
        lanes
      )
    );
  }

  // 处理数组/列表
  if (Array.isArray(newChild)) {
    return reconcileChildrenArray(
      returnFiber,
      currentFirstChild,
      newChild,
      lanes
    );
  }

  // 其他情况处理...

  // 如果都不匹配，删除所有旧子节点
  return deleteRemainingChildren(returnFiber, currentFirstChild);
}
```

核心算法很直观：根据新子节点的类型选择不同的协调策略。

## 渲染时机与批量更新

在实际项目中经常遇到的一个问题是：React 何时真正更新 DOM？源码分析发现，渲染流程分为两大阶段:

1. 渲染阶段(Render Phase): 执行 diff，这个过程是可中断的
2. 提交阶段(Commit Phase): 将 diff 结果实际应用到 DOM，这个过程不可中断

React 18 引入了自动批处理(Automatic Batching)，这在源码中通过`ensureRootIsScheduled`函数实现:

```javascript
function ensureRootIsScheduled(root: FiberRoot, currentTime: number) {
  const existingCallbackNode = root.callbackNode;
  // ...

  // 根据优先级确定调度策略
  let schedulerPriorityLevel;
  switch (lanesToEventPriority(nextLanes)) {
    case DiscreteEventPriority:
      schedulerPriorityLevel = ImmediateSchedulerPriority;
      break;
    case ContinuousEventPriority:
      schedulerPriorityLevel = UserBlockingSchedulerPriority;
      break;
    case DefaultEventPriority:
      schedulerPriorityLevel = NormalSchedulerPriority;
      break;
    case IdleEventPriority:
      schedulerPriorityLevel = IdleSchedulerPriority;
      break;
    default:
      schedulerPriorityLevel = NormalSchedulerPriority;
      break;
  }

  // 调度新的渲染工作
  newCallbackNode = scheduleCallback(
    schedulerPriorityLevel,
    performConcurrentWorkOnRoot.bind(null, root)
  );

  // ...
}
```

这段代码展示了 React 如何根据任务优先级来调度渲染工作，这是批处理和并发渲染的核心。

## 真实项目中的优化技巧

在前段时间的性能优化项目中，发现了一些与虚拟 DOM 相关的实战经验:

### 1. key 的正确使用极其重要

很多人知道要用 key，但不知道为什么。源码中，`reconcileChildrenArray`函数会利用 key 进行高效的节点复用:

```javascript
// 简化后的数组diff逻辑
function reconcileChildrenArray(
  returnFiber,
  currentFirstChild,
  newChildren,
  lanes
) {
  // ...
  // 第一轮: 同时遍历新旧数组，比较相同位置节点
  for (; oldFiber !== null && newIdx < newChildren.length; newIdx++) {
    // ...
    if (
      oldFiber.key === newChild.key &&
      oldFiber.elementType === newChild.type
    ) {
      // 可以复用节点
      // ...
    } else {
      // 不能复用，跳出第一轮循环
      break;
    }
  }

  // 第二轮: 根据key建立映射，尝试复用剩余旧节点
  if (oldFiber === null) {
    // 旧节点用完，剩下的新节点全部创建
    // ...
  } else {
    // 将剩余旧节点放入map中
    const existingChildren = mapRemainingChildren(returnFiber, oldFiber);

    // 遍历剩余新节点，尝试从map中复用
    for (; newIdx < newChildren.length; newIdx++) {
      const newFiber = updateFromMap(
        existingChildren,
        returnFiber,
        newIdx,
        newChildren[newIdx],
        lanes
      );
      // ...
    }

    // 删除未被复用的旧节点
    // ...
  }

  return resultingFirstChild;
}
```

这里清晰地展示了 React 如何利用 key 提高 diff 效率 - 它首先尝试同位置匹配，然后利用 key 构建映射进行复用。在实际项目中，对于频繁变化的列表，正确使用 key 可以显著提升性能。

### 2. 减少不必要的嵌套

我们发现，过度嵌套的组件结构会导致更多的虚拟 DOM 节点，增加 diff 开销。在一个后台系统重构中，通过减少不必要的组件嵌套，渲染性能提升了约 15%。

### 3. 合理拆分组件边界

这是个有趣的经验 - 过度拆分组件并不总是好事。有时候，将紧密关联的 UI 逻辑保持在一个组件内可以减少虚拟 DOM 的处理开销。比如，一个高频更新的数据面板，如果拆分成过多小组件，反而可能增加协调开销。

## 进阶技巧与陷阱

### shouldComponentUpdate 与 React.memo 的内部实现

翻阅源码，发现`shouldComponentUpdate`和`React.memo`在内部实际上是通过跳过整个子树的协调来优化性能的:

```javascript
// Class组件的简化判断流程
if (oldProps === newProps && oldState === newState && !hasContextChanged() &&
    !updateFiberHasScheduledUpdateOrContext) {
  // 没有变化，跳过此组件及其子组件的更新
  return false;
}

// memo组件的简化判断
function updateMemoComponent(...) {
  // ...
  if (
    current !== null &&
    !didReceiveUpdate &&
    shallowEqual(prevProps, nextProps)
  ) {
    // props相等，直接复用旧Fiber
    return bailoutOnAlreadyFinishedWork(current, workInProgress, renderLanes);
  }
  // ...
}
```

这解释了为什么这些优化在大型应用中如此有效 - 它们可以整体剪除大块的虚拟 DOM 比较工作。

### 避免过度优化

源码阅读让我意识到，React 内部已经做了大量优化工作。过早的性能优化可能是有害的。比如，我们曾遇到一个案例，开发者过度使用`useMemo`和`React.memo`，导致代码复杂度上升，而性能提升却不明显。

React 源码中有个有趣的注释:

```javascript
// 在React源码中确实存在这样的注释
// Profiling indicates this function is a wasteful hot path.
// But the majority of its runtime are caused by instances where we won't
// be able to memoize anyway, due to direct mutation.
// TODO: Make sure this function gets optimized.
```

这提醒我们，要基于测量而非猜测来优化，也要留意 React 团队正在解决的热点问题。

## 未来发展趋势

### React 的优化方向

研究 React 的 Fiber 架构和最新的 concurrent mode 实现，发现 React 团队的优化思路已经从"减少 DOM 操作"转向"提高用户体验的流畅度"。这是一个重要的范式转换。

新的 concurrent features 允许 React:

- 中断渲染以响应高优先级更新
- 在后台准备新 UI 而不阻塞主线程
- 有选择性地 hydrate 服务端渲染内容

这些能力远超传统虚拟 DOM 的设计目标。

### 反思虚拟 DOM

有趣的是，React 团队的 Dan Abramov 曾表示:

> "Virtual DOM 这个术语可能被过度炒作了。它只是一种实现细节，而不是 React 的核心特性。"

这一点在源码中也能得到印证 - 虚拟 DOM 更多是一种实现手段，而 React 的核心价值在于它的编程模型和组件抽象。

## 写在最后

通过深入源码，我对虚拟 DOM 有了更清晰的认识。它不仅仅是一种优化技术，更是一种强大的抽象，让我们能够用声明式的方式构建复杂 UI。

在日常开发中，与其过度关注虚拟 DOM 本身，不如专注于编写符合 React 设计理念的组件 - 保持单向数据流、适当拆分组件、明确状态管理边界。这些才是真正影响应用质量的关键因素。

源码是最好的老师。每当我遇到 React 相关的疑难问题，总是会回到源码寻找答案，每次都有新的收获。推荐每位 React 开发者都尝试阅读源码，这会让你对框架有更本质的理解。

下次分享计划深入 React 的事件系统，欢迎关注。
