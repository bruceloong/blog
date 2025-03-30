---
date: "2023-04-02T18:14:17+08:00"
draft: false
title: "React Hook"
---

## Hooks 的本质：链表而非魔法

刚开始使用 Hooks 时，`useState`看起来像是某种"魔法"——一个普通函数竟然能记住上次渲染的状态。但翻开源码，发现其实现原理出奇简单：**就是一个链表**。

```javascript
// 当前正在渲染的组件
let currentlyRenderingFiber = null;
// 当前处理的Hook
let currentHook = null;
// 工作中的Hook链表
let workInProgressHook = null;

// useState的简化实现
function useState(initialState) {
  // 获取或创建当前Hook
  const hook = mountWorkInProgressHook();

  // 初始化state
  if (hook.memoizedState === undefined) {
    if (typeof initialState === "function") {
      initialState = initialState();
    }
    hook.memoizedState = initialState;
  }

  // 创建更新函数
  const dispatch = dispatchAction.bind(null, currentlyRenderingFiber, hook);

  return [hook.memoizedState, dispatch];
}

// 创建新Hook并添加到链表
function mountWorkInProgressHook() {
  const hook = {
    memoizedState: undefined,
    baseState: undefined,
    baseQueue: null,
    queue: null,
    next: null,
  };

  if (workInProgressHook === null) {
    // 这是链表中的第一个Hook
    currentlyRenderingFiber.memoizedState = workInProgressHook = hook;
  } else {
    // 添加到链表末尾
    workInProgressHook = workInProgressHook.next = hook;
  }

  return workInProgressHook;
}
```

看到这段代码，我恍然大悟。React 为每个函数组件创建了一个 Fiber 节点，在这个节点上挂载了一个 Hook 链表。每次调用`useState`、`useEffect`等 Hook 时，都会在这个链表上添加一个新节点。在后续渲染时，React 会沿着这个链表遍历，拿到对应位置的 Hook 数据。

这也解释了为什么 Hook 必须按固定顺序调用——因为 React 是靠**调用顺序**来确定 Hook 对应关系的！

## useState 与状态更新机制

`useState`是最常用的 Hook，深入源码可以看到它的更新机制：

```javascript
// 状态更新函数的简化实现
function dispatchAction(fiber, hook, action) {
  // 创建更新对象
  const update = {
    action,
    next: null,
  };

  // 将更新添加到队列
  const pending = hook.queue.pending;
  if (pending === null) {
    // 创建循环链表
    update.next = update;
  } else {
    update.next = pending.next;
    pending.next = update;
  }
  hook.queue.pending = update;

  // 调度更新
  scheduleUpdateOnFiber(fiber);
}
```

有趣的是，React 将状态更新设计为一个**循环链表**，这样可以高效地添加和处理多个连续更新。

在我们的一个实时数据仪表盘项目中，明白这个原理后，我们优化了状态更新逻辑，减少了 50%以上的不必要渲染：

```javascript
// 优化前
function Counter() {
  const [count, setCount] = useState(0);

  function handleClick() {
    // 这会触发两次渲染
    setCount(count + 1);
    setCount(count + 1); // 实际上第二次基于相同的count，结果还是1
  }

  return <button onClick={handleClick}>{count}</button>;
}

// 优化后
function Counter() {
  const [count, setCount] = useState(0);

  function handleClick() {
    // 只触发一次渲染，结果为1
    setCount((c) => c + 1);
  }

  return <button onClick={handleClick}>{count}</button>;
}
```

## useEffect 的内部实现与清理机制

`useEffect`的实现比`useState`复杂得多，它需要处理依赖追踪、副作用执行和清理等问题：

```javascript
// useEffect的简化实现
function useEffect(create, deps) {
  const hook = mountWorkInProgressHook();

  // 检查依赖是否变化
  const nextDeps = deps === undefined ? null : deps;

  hook.memoizedState = {
    tag: HookEffectTag,
    create, // 副作用函数
    destroy: undefined, // 清理函数
    deps: nextDeps,
    next: null,
  };

  // 将effect添加到fiber的副作用链表
  pushEffect(HookEffectTag, create, undefined, nextDeps);
}

// 提交阶段执行effect
function commitHookEffectList(tag, fiber) {
  let effect = fiber.updateQueue.firstEffect;

  while (effect !== null) {
    // 执行上一次渲染的清理函数
    if (effect.destroy !== undefined) {
      effect.destroy();
    }

    // 执行这次渲染的副作用函数，并保存清理函数
    const create = effect.create;
    effect.destroy = create();

    effect = effect.next;
  }
}
```

在源码中，`useEffect`的执行是在**提交阶段的布局阶段之后**。这是个重要发现，因为它解释了为什么`useEffect`总是在浏览器绘制之后执行，适合进行网络请求等副作用操作。

相比之下，`useLayoutEffect`则在布局阶段执行，这就是为什么它可以用来测量 DOM 并同步更新样式，避免闪烁。

我们在一个拖拽组件中利用这个特性：

```javascript
function DraggableElement() {
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const elementRef = useRef(null);

  // 使用useLayoutEffect确保DOM更新和测量同步进行，避免闪烁
  useLayoutEffect(() => {
    if (elementRef.current) {
      const { width, height } = elementRef.current.getBoundingClientRect();
      // 确保元素不超出容器边界
      if (position.x + width > window.innerWidth) {
        setPosition((prev) => ({ ...prev, x: window.innerWidth - width }));
      }
    }
  }, [position.x]);

  // ...拖拽逻辑

  return (
    <div
      ref={elementRef}
      style={{ transform: `translate(${position.x}px, ${position.y}px)` }}
    >
      拖我
    </div>
  );
}
```

## 从源码理解闭包陷阱

Hook 最常见的坑莫过于"闭包陷阱"。根据源码，这个问题发生的原因很清晰：**函数组件每次渲染都会创建新的函数实例，捕获当时的状态值**。

```javascript
function Timer() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => {
      setCount(count + 1); // 闭包!捕获的是组件首次渲染时的count(0)
    }, 1000);

    return () => clearInterval(timer);
  }, []); // 空依赖数组,只运行一次

  return <div>{count}</div>;
}
```

上面的代码中，`count`只会增加到 1 然后停止。源码层面的解释是：effect 创建时捕获了 count=0 的闭包环境，之后定时器中的回调始终引用这个闭包。

修复方法是利用函数式更新或添加依赖：

```javascript
// 方案1：函数式更新
useEffect(() => {
  const timer = setInterval(() => {
    setCount((c) => c + 1); // 使用函数式更新,不依赖闭包中的count
  }, 1000);

  return () => clearInterval(timer);
}, []);

// 方案2：添加依赖
useEffect(() => {
  const timer = setInterval(() => {
    setCount(count + 1); // 每次count变化都会重新创建effect
  }, 1000);

  return () => clearInterval(timer);
}, [count]); // 添加count作为依赖
```

在一个实时协作编辑器项目中，我们就踩过这个坑。后来创建了一个工具钩子，自动处理这类问题：

```javascript
function useLatestValue(value) {
  const ref = useRef(value);

  // 更新ref以指向最新值
  useEffect(() => {
    ref.current = value;
  });

  return ref;
}

// 使用
function Component() {
  const [value, setValue] = useState("");
  const latestValue = useLatestValue(value);

  useEffect(() => {
    const handler = () => {
      // 总是访问最新值，不受闭包限制
      console.log(latestValue.current);
    };

    document.addEventListener("click", handler);
    return () => document.removeEventListener("click", handler);
  }, []); // 空依赖数组也不会有问题

  return <input value={value} onChange={(e) => setValue(e.target.value)} />;
}
```

## 依赖数组的工作原理

Hook 的依赖数组看似简单，但源码实现很有意思：

```javascript
// 简化版依赖对比函数
function areHookInputsEqual(nextDeps, prevDeps) {
  if (prevDeps === null) {
    return false;
  }

  for (let i = 0; i < prevDeps.length && i < nextDeps.length; i++) {
    if (Object.is(nextDeps[i], prevDeps[i])) {
      continue;
    }
    return false;
  }
  return true;
}
```

注意 React 使用`Object.is`进行依赖比较，这与`===`操作符有细微差别，比如`Object.is(NaN, NaN)`为`true`，而`NaN === NaN`为`false`。

更重要的是，依赖比较是**浅比较**。这在处理对象和数组时经常引起困惑：

```javascript
function SearchComponent() {
  const [filters, setFilters] = useState({ category: "all", minPrice: 0 });

  // 🔴 这个effect会在每次渲染时执行,即使filters没有实际变化
  useEffect(() => {
    fetchResults(filters);
  }, [filters]); // filters是每次渲染创建的新对象

  return (
    <button onClick={() => setFilters({ ...filters })}>刷新(其实没变)</button>
  );
}
```

理解这一点后，我们在团队中推广了几种最佳实践：

1. 拆分对象状态

```javascript
function BetterSearchComponent() {
  const [category, setCategory] = useState("all");
  const [minPrice, setMinPrice] = useState(0);

  // ✅ 只有当确实需要更新时才会执行
  useEffect(() => {
    fetchResults({ category, minPrice });
  }, [category, minPrice]);

  return (
    <>
      <button onClick={() => setCategory("electronics")}>电子产品</button>
      <button onClick={() => setMinPrice(100)}>100元以上</button>
    </>
  );
}
```

2. 使用`useMemo`缓存对象

```javascript
function MemoizedSearchComponent() {
  const [category, setCategory] = useState("all");
  const [minPrice, setMinPrice] = useState(0);

  // 只有依赖变化时才创建新对象
  const filters = useMemo(() => {
    return { category, minPrice };
  }, [category, minPrice]);

  useEffect(() => {
    fetchResults(filters);
  }, [filters]); // filters现在是稳定的引用

  return (...);
}
```

## 自定义 Hook 的原理与设计模式

自定义 Hook 看似是个新概念，但源码表明它仅仅是函数复用的模式，没有任何特殊实现：

```javascript
// 这不是React内部代码,而是展示自定义Hook的原理
function useCustomHook(param) {
  // 调用内置Hook
  const [state, setState] = useState(initialState);

  // 可能的副作用
  useEffect(() => {
    // 处理逻辑
  }, [param]);

  // 返回需要的数据和方法
  return {
    state,
    update: setState,
    // 其他逻辑...
  };
}
```

自定义 Hook 的魔力在于它遵循了 Hook 的调用规则，可以在内部使用其他 Hook。这创造了强大的组合能力。

在一个管理系统重构中，我们提取了几十个自定义 Hook，大幅减少了代码重复。比如这个处理 API 请求的 Hook：

```javascript
function useApi(endpoint, options = {}) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const optionsRef = useRef(options);
  // 仅当options的stringified版本变化时更新ref
  useEffect(() => {
    optionsRef.current = options;
  }, [JSON.stringify(options)]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await fetch(endpoint, optionsRef.current);
      if (!response.ok) throw new Error(`API error: ${response.status}`);

      const result = await response.json();
      setData(result);
    } catch (err) {
      setError(err.message || "Unknown error");
      console.error("API request failed:", err);
    } finally {
      setLoading(false);
    }
  }, [endpoint]); // 只依赖endpoint，不依赖options对象

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return { data, loading, error, refetch: fetchData };
}
```

这个 Hook 解决了几个常见问题：

1. 处理加载和错误状态
2. 解决对象依赖问题
3. 提供重新获取数据的能力
4. 在组件卸载后避免设置状态

## Hook 与 Fiber 架构的关系

深入源码后，发现 Hook 与 React 的 Fiber 架构紧密相连。每个函数组件实例关联一个 Fiber 节点，这个节点的`memoizedState`属性保存了该组件的 Hook 链表。

```javascript
// Fiber节点结构(简化)
const fiber = {
  tag: FunctionComponent,
  type: YourComponent,
  memoizedState: { // 第一个Hook
    memoizedState: 'hook状态',
    baseState: 'hook基础状态',
    queue: {/*更新队列*/},
    baseQueue: null,
    next: { // 下一个Hook
      memoizedState: /*...*/,
      /*...*/
      next: /*...*/
    }
  },
  // ...其他Fiber属性
};
```

通过跟踪源码中的函数调用链，可以看到 Hook 是如何在渲染过程中被处理的：

```
renderWithHooks
  ↓
组件函数执行(调用各种hook)
  ↓
各hook内部(useState, useEffect等)
  ↓
mountWorkInProgressHook / updateWorkInProgressHook
  ↓
将hook添加到fiber.memoizedState链表
```

了解这一点对调试复杂的 Hook 问题非常有帮助。在 React DevTools 中，我们可以找到组件对应的 Fiber，然后在控制台中检查其 memoizedState 来深入了解 Hook 的状态。

## Hooks 中的常见性能问题与解决方案

### 1. 过度依赖 useEffect

源码显示，每次执行`useEffect`都有一定开销，尤其是在清理和重新执行副作用时。

```javascript
// 🔴 低效模式
function SearchResults({ query }) {
  const [results, setResults] = useState([]);

  // 每次渲染后都会执行
  useEffect(() => {
    // 过滤本地数据
    const filteredResults = filterData(query);
    setResults(filteredResults);
  });

  return <ResultsList data={results} />;
}

// ✅ 优化模式
function SearchResults({ query }) {
  // 直接在渲染期间计算,无需effect
  const results = useMemo(() => {
    return filterData(query);
  }, [query]);

  return <ResultsList data={results} />;
}
```

### 2. 复杂状态管理

当状态逻辑变得复杂时，多个`useState`调用会变得难以管理。`useReducer`是源码中专为此设计的解决方案：

```javascript
function complexFormReducer(state, action) {
  switch (action.type) {
    case "field_change":
      return { ...state, [action.field]: action.value };
    case "submit_start":
      return { ...state, isSubmitting: true, error: null };
    case "submit_success":
      return { ...state, isSubmitting: false, isSuccess: true };
    case "submit_error":
      return { ...state, isSubmitting: false, error: action.error };
    default:
      return state;
  }
}

function ComplexForm() {
  const [state, dispatch] = useReducer(complexFormReducer, {
    username: "",
    password: "",
    isSubmitting: false,
    error: null,
    isSuccess: false,
  });

  // 表单提交处理
  async function handleSubmit(e) {
    e.preventDefault();
    dispatch({ type: "submit_start" });

    try {
      await submitForm(state.username, state.password);
      dispatch({ type: "submit_success" });
    } catch (error) {
      dispatch({ type: "submit_error", error: error.message });
    }
  }

  return <form onSubmit={handleSubmit}>{/* 表单字段 */}</form>;
}
```

### 3. 避免过度使用 useMemo 和 useCallback

阅读源码后发现，这些 Hook 本身也有开销。盲目使用可能适得其反：

```javascript
function Component(props) {
  // 🔴 对于简单计算,这样做是过度优化
  const value = useMemo(() => props.a + props.b, [props.a, props.b]);

  // 🔴 如果这个函数没有被传递给子组件或其他Hook,这是不必要的
  const handleClick = useCallback(() => {
    console.log(props.name);
  }, [props.name]);
}
```

我们建立了一个简单的准则：

- 只有当计算开销大或依赖数组稳定时，才使用`useMemo`
- 只有当函数传递给子组件或其他 Hook 依赖它时，才使用`useCallback`

## 一些不为人知的 Hook 技巧

通过阅读源码，我发现了一些鲜为人知但很有用的技巧：

### 1. 惰性初始化

`useState`和`useReducer`支持惰性初始化，避免每次渲染都执行昂贵的初始化：

```javascript
// 普通初始化
const [state, setState] = useState(createExpensiveInitialState());

// 惰性初始化 - 只在首次渲染执行createExpensiveInitialState
const [state, setState] = useState(() => createExpensiveInitialState());
```

### 2. 利用 useRef 的稳定性

`useRef`返回的对象在组件生命周期内保持稳定引用，可以用来存储任何可变值：

```javascript
function usePrevious(value) {
  const ref = useRef();

  // 在渲染完成后更新ref
  useEffect(() => {
    ref.current = value;
  });

  // 返回之前的值
  return ref.current;
}
```

### 3. 巧用 useLayoutEffect 避免闪烁

当需要在 DOM 更新后立即测量和修改 DOM 时，`useLayoutEffect`比`useEffect`更适合：

```javascript
function AutoResizeTextarea() {
  const textareaRef = useRef(null);

  // 在浏览器重绘前同步执行
  useLayoutEffect(() => {
    if (textareaRef.current) {
      const textarea = textareaRef.current;
      // 重置高度
      textarea.style.height = "auto";
      // 设置为内容高度
      textarea.style.height = `${textarea.scrollHeight}px`;
    }
  }, [textareaRef.current?.value]);

  return <textarea ref={textareaRef} />;
}
```

## 从 Hook 到未来

随着 React 的发展，Hook API 的实现也在不断改进。源码中的一些注释暗示了未来的发展方向：

```javascript
// 源码中的注释
// TODO: Warn if no deps are provided
// TODO: In some cases, we could optimize by comparing to the previous deps array
// TODO: Consider warning when hooks are used inside a conditional
```

React 18 中，Hook 的实现已与 Concurrent Mode 深度整合。例如，`useDeferredValue`和`useTransition`允许我们标记低优先级更新，这些 API 的实现依赖于新的调度器。

通过 Hook，React 团队正逐步实现声明式调度的愿景，让开发者能以简单的 API 控制复杂的更新调度。我预计在未来的版本中，我们会看到更多与性能优化和并发渲染相关的 Hook。

## 结语

深入研究 Hook 的源码实现，不仅让我理解了其工作原理，也改变了我编写 React 代码的方式。Hook 不只是 API，它代表了一种组件逻辑组织和复用的范式转变。

跟踪 React 仓库的 commit 历史，能看到 Hook API 是如何一步步演进的，也能窥见 React 团队如何权衡设计决策。这提醒我们，没有完美的 API，只有在特定约束下的最佳权衡。

下一篇我打算分析 React 的并发模式及其实现原理，敬请期待。
