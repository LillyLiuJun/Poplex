# Tab2（Mine 页）数据逻辑梳理

> 版本：v1 · 2026-07-04  
> 范围：前端数据模型、请求链路、状态管理、已知问题

---

## 一、数据模型

Tab2 的所有素材统一用 `Material` struct 表示，对应 Supabase `materials` 表的一条记录。

```
Material
├── id: UUID
├── createdAt: Date
├── status: String          "pending" | "categorized"
├── sceneCategory: String?  分类标签，仅 scene 类型有值
├── materialType: String    "scene" | "vocabulary"
└── rawContent: MaterialContent
      ├── .scene(SceneMaterial)
      │     ├── nativeEnglish     地道英文表达
      │     ├── chineseOriginal   用户原始中文
      │     └── keyPhrases[]      重点词组 + 注释
      └── .vocabulary(VocabMaterial)
            ├── word / phonetic / pos
            ├── definition
            └── exampleEn / exampleZh
```

两种类型共用同一个 struct，通过 `materialType` 字段在解码时分发到不同的 `rawContent`。这符合 CLAUDE.md 中"两种素材结构不同、不能强行合并字段"的约束——共用容器，但内容完全隔离。

---

## 二、后端端点一览

| 端点 | 方法 | 作用 |
|---|---|---|
| `get-materials` | GET | 拉取 scene 类型素材列表 |
| `get-vocabs` | GET | 拉取 vocabulary 类型素材列表 |
| `delete-material` | POST `{ id }` | 软删除（标记 deleted） |
| `restore-material` | POST `{ id }` | 撤销软删除 |

所有请求通过 Supabase Edge Function 中转，客户端使用 `anonKey`（publishable key），由 RLS 保护。

---

## 三、数据流：两条独立链路

```
Tab2（MineView）
│
├── 主链路：场景素材
│     MineViewModel.loadScenes()
│       ├── GET get-materials → [Material(scene)]  → vm.scenes
│       └── GET get-vocabs    → count only          → vm.vocabCount（仅用于徽章显示）
│
└── 词汇链路：词汇素材
      VocabBookView（用户点击 Vocabulary 胶囊后打开）
        └── 自行 GET get-vocabs → [Material(vocabulary)] → 本地 @State vocabs
```

**关键点**：`get-vocabs` 被调用了两次——MineViewModel 调一次只取 `.count`，VocabBookView 打开后再调一次取完整数据。同一份数据，两次网络请求。

---

## 四、MineViewModel 状态机

### 加载时机

```
进入 Tab2（onAppear）
  └── loadScenesIfStale()
        └── 距上次加载 > 30 秒 → loadScenes()
              ├── 并行拉 scenes + vocabCount
              ├── 成功后写 UserDefaults "mine_last_scene_count"
              └── 失败时 errorMessage 非空，但不清空已有 scenes（静默失败）
```

### MineView 渲染优先级

| 条件 | 展示内容 |
|---|---|
| `isLoading && scenes.isEmpty` | 骨架屏（占位数量取 UserDefaults 缓存值，首次默认 3） |
| `errorMessage != nil && scenes.isEmpty` | 错误态 + Retry 按钮 |
| `scenes.isEmpty` | 空态（ContentUnavailableView） |
| 其他 | 场景列表 + 分类筛选栏 + Vocabulary 胶囊 |

### 筛选逻辑

- `availableCategories`：从已加载的 scenes 中动态提取，不依赖固定枚举
- `filteredScenes`：`selectedCategory == nil` 时返回全部，否则按 `sceneCategory` 过滤

---

## 五、删除 / 撤销流程（乐观删除）

两个页面（MineViewModel + VocabBookView）各自实现了同一套逻辑：

```
用户触发删除
  Step 1  立即从本地列表移除（UI 即时响应，不等后端）
  Step 2  记录 lastDeletedMaterial，显示 Undo Toast（4 秒倒计时）
  Step 3  调 delete-material 后端（fire & forget，不等结果）

  [用户在 4 秒内点 Undo]
    → 取消计时器
    → 调 restore-material 后端
    → 重新 loadScenes() / loadVocabs() 刷新列表

  [4 秒到期，未撤销]
    → lastDeletedMaterial = nil
    → Toast 消失
    → 后端软删除保持生效
```

---

## 六、已知问题 / 技术债

### 1. 删除逻辑重复
MineViewModel 和 VocabBookView 各维护一套完全相同的 delete + undo timer 逻辑（代码复制）。修改一处另一处不会同步。
**建议**：将删除逻辑提取为共用函数或单独的 service 层。

### 2. 日期解码重复
`MineViewModel.fetchScenes()` 和 `VocabBookView.fetchVocabs()` 里各写了一份相同的 ISO8601 自定义解码器。
**建议**：提取为 `JSONDecoder` 扩展或工厂方法。

### 3. `get-vocabs` 重复请求
MineViewModel 调一次只用 count，VocabBookView 再调一次取全量。进入 Vocabulary 页后可能在短时间内发出两次相同请求。
**建议**：MineViewModel 直接存储 `[Material]` 级别的 vocab 数据，VocabBookView 从 ViewModel 读取，或把 vocab 管理移入 MineViewModel。

### 4. VocabBookView 状态孤立
Vocab 的加载状态（isLoading、error、vocabs 数组）全在 View 里用 `@State` 管理，没有对应 ViewModel。删除后 MineView 的 vocabCount 徽章不会实时更新（要等下次进 Tab2 触发 loadScenesIfStale 才刷新）。
**建议**：将 vocab 相关状态迁入 MineViewModel，或把 vocabCount 改为由 VocabBookView 通过 binding 回写。

---

## 七、文件索引

| 文件 | 职责 |
|---|---|
| `Models/Material.swift` | 数据模型（Material / SceneMaterial / VocabMaterial） |
| `Mine/MineViewModel.swift` | 场景数据加载、筛选、乐观删除 |
| `Mine/MineView.swift` | 主列表 UI、状态分支渲染、筛选栏 |
| `Mine/SceneDetailView.swift` | 场景详情页（只读 + 删除入口） |
| `Mine/VocabBookView.swift` | 词汇本页（独立加载 + 独立删除逻辑） |
| `Mine/Components/SceneCardRow.swift` | 场景卡片列表行 |
| `Mine/Components/VocabCardRow.swift` | 词汇卡片列表行 |
| `Mine/Components/ContextFilterBar.swift` | 分类筛选胶囊栏 |
| `Mine/Components/SkeletonCardRow.swift` | 骨架屏占位行 |
| `Mine/Components/UndoToast.swift` | 撤销 Toast 组件 |
| `Services/SupabaseConfig.swift` | 后端端点 URL 配置 |
