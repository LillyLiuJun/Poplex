# Tab1的目标：即时解惑+生成素材
## 架构调整
内容展示方式卡片：每次输入一张卡牌，然后点击展开。
内容来源：
	文字即时翻译（已上线）单独prompt，之前是生成4种卡片，这种方式是不是太复杂了，排版问题
	图片（已上线）单独prompt
	语音对话 未来单独prompt
	 文件 单独prompt
	 邮箱，聊天记录上传等
需要考虑这些输入在TAB1输入后生成什么？包含哪些内容？
	我认为越短的素材或者说即时的素材越细，而长文件颗粒度可以大
需要考虑页面排版
	即使是文字的即时翻译也可能是长度较长

## 内容调整

在《输入到成长》这个文件中我已经标注了一些prompt和结构调整的部分，下面是一些补充要调整的部分
**现状 · SYSTEM_PROMPT 骨架**（10 块，供统一优化）：
1. 角色 persona（English Buddy）--现在的人设感觉不太对，结合品牌气质重新优化一下角色
	- 品牌色：`#FF7622`（暖橙，饱和度要保持，不要降调）
	- 整体调性：温润极简（Warm Minimalism）注重效率

2. CARD SELECTION（选 1 类卡；现写"优先 s1–s4，chat 最后手段"）--结合架构一起调整
3. GRANULARITY RULE（有谓语 → 句级，无谓语 → 词级）--结合架构分析存在的目的
4. LANGUAGE INTENT RULE（按意图判中英）-结合架构分析存在的目的
5. SELF-REFERENCE EXTRACTION（抽 `extracted_concept`）
6. OUTPUT SCHEMAS（逐卡字段，含 `scene_trigger`）
7. TONE--这块的内容我忘了你查下
8. MULTI-TURN CONTEXT（带 1 轮）
9. 输出 JSON 形状---结合架构分析存在的目的

---

## 待优化需求（记录，暂不做）

### N1 · 第三语言（other）输入应判 comprehend，而非 express（2026-07-28 记）

**现象**：Slice 0.5 验收时，输入纯日文 `お疲れ様です`，模型判成 `direction=express`，并给 `intent` 填了一句释义（"表达对他人辛勤工作的感谢或慰问"）。

**为什么算问题**：
- 现行 direction 规则（第 8 刀定的）是"OBJECT 含任何非目标语言内容 → express"，所以第三语言一律 express——字面没错。
- 但语义上，用户查一句外语（既非母语也非目标语言）真实意图是**"想看懂"**，属 comprehend，不是"想表达"。
- 连带副作用：comprehend 本该 `intent=null`；现在 other 被判 express，`intent` 装了个**释义**，而 §5.2.7 的 `intent` 是"用户想表达的归一化母语意图"。两者语义不同，若直接拿去做 Slice 1 的意图频率聚合/同义组，会污染账本。

**⚠️ 调研结论（2026-07-28，勿再走"翻 direction"这条路）**：
最初设想是"把纯第三语言判 comprehend"。**读 flow 后否掉了——它有害**：comprehend 侧
（s1/s2）是为目标语言输入造的（判词形/改英文句），把日文路由过去，s1 会把日文原样
当词条 + 只给中文释义、**完全给不出英文怎么说**，比现状更差。而现在的 express flow
（s3）产出的内容其实是对的（`target_expression` = 英文等价表达、`native_meaning` = 该
含义）——**只是"标签 express"和"intent 装了释义"两点别扭，标签下游不靠它区分**
（`input_lang='other'` 已能单独识别第三语言）。

**真正该修的两点（以后优化时）**：
1. prompt 里 `intent` 加一句"`input_lang='other'` 时为 null"——第三语言查询没有"母语想
   表达的意图"，从源头掐掉污染，flow 一行不动。（本可现在做，PM 决定连同整块以后再调。）
2. 记账层兜底：`input_lang='other'` 时不把 intent 写入 `intent_text`（Slice 1 落地时一并处理）。

**优先级**：非阻塞，不影响 Slice 0.5/1 主链路。归入模型 intent 归一化质量的整体优化。

### N2 · intent 归一化力度（2026-07-28 记）

模型对情绪化模糊表达归一化得好（`累死了`/`太累了` 都归成 `很累`，§5.2.7 聚合成立）；但对具体陈述倾向忠实复述（`I have a 会议 at 3pm` → `我下午三点有个会议`，未进一步归一）。当前够用，待有真实数据后再评估是否需要更强的归一化规则。

### N3 · 收紧 learnable_units 的 kind 枚举输出（2026-07-28 记）

**现象**：Slice 1 记账实测时，模型对 `set up` 输出 `"kind":"phrasal verb"`——但 prompt 的 `LEARNABLE UNITS` 段明确规定 `kind` 只能是六个值之一：`word | phrase | collocation | slang | idiom | pattern`。`phrasal verb` 不在其中，属**prompt 合规漂移**。

**影响与现状**：`entry_kind` 列有 CHECK 约束，`phrasal verb` 会撞约束、把整批记账带崩。已在 `record_lexicon_material_units` RPC 里做了**服务端收敛兜底**（`phrasal verb → phrase`，其余不认识的 → null），所以**当前不阻塞、账本数据是干净的**。

**待优化（不紧急）**：从 prompt 侧收紧 `kind` 的输出，让模型稳定只吐六个合法值之一（例如在 schema 里更醒目地列出枚举、或加一句"kind MUST be exactly one of these six, never a variant like 'phrasal verb'"）。这属于"减少对服务端兜底的依赖"，不是 bug 修复。

**优先级**：低。服务端收敛已稳稳兜住；归入模型输出合规性的整体优化，与 N1/N2 同批处理即可。

> 顺带记一笔通用原则（本轮验证过的经验）：**任何被 CHECK 约束的列、只要值来自模型输出，服务端都必须做"合法值或 null"的收敛**——模型枚举是概率性的，会飘。lexicon 的 `kind/input_lang/granularity/direction` 已按此办理。
