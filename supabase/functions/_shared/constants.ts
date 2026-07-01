// Tab2 scene category fixed list (MVP).
// AI picks from these options when classifying a scene material.
// Order matches PRD Page2_PRD_v1.md §3.0.
export const SCENE_CATEGORIES = [
  "家庭与人际",
  "工作与学业",
  "日常起居",
  "饮食",
  "购物消费",
  "出行交通",
  "运动健康",
  "休闲娱乐",
  "科技数码",
  "天气环境",
  "情绪社交",
  "其他",
] as const;

export type SceneCategory = typeof SCENE_CATEGORIES[number];
