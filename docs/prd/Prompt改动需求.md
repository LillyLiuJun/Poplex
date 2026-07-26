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
