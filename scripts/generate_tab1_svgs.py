#!/usr/bin/env python3
"""
生成 Tab1 对话时间线生产级矢量 SVG 资产（v3 · 像素级色彩与字重极致校准版）
彻底解决：
1. 气泡背景色: 严格锁定实机采样的 #F4F0EB (来源于 rgba(240, 237, 230, 0.68) 在 #FBF8F5 底上叠加)，外加 0.5px rgba(230, 225, 218, 0.55) 浅暖边框
2. 气泡字色: 严格锁定 Theme.swift 的 Primitive.neutral700 即 #4B4640 (绝非近黑 #211811)，消除视觉光学膨胀
3. 气泡高度: 实机精准 35px (非 40px)，左右内边距 14px，字号 15px 优美清瘦居中
4. 抗锯齿: 注入 -webkit-font-smoothing: antialiased 与 text-rendering: optimizeLegibility，杜绝字体发粗发糊
5. 卡片与间距: 严格遵守 12px 与 28px 节奏，卡片 400px 宽，大标题 Charter 20px，英文 Charter 17px
"""

import os

SVG_DIR = "store_screenshots/assets"
os.makedirs(SVG_DIR, exist_ok=True)

SVG_DEFS = """  <defs>
    <style>
      @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&amp;display=swap');
      
      text {
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
        text-rendering: optimizeLegibility;
      }
      .font-serif {
        font-family: "Charter", "Charter-Bold", "New York", Georgia, serif;
      }
      .font-sans {
        font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Hiragino Sans GB", "SF Pro Text", "Plus Jakarta Sans", sans-serif;
      }
      .font-mono {
        font-family: "SF Mono", Menlo, Monaco, Consolas, monospace;
      }
      .bubble-text {
        font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Hiragino Sans GB", "SF Pro Text", sans-serif;
        font-size: 15px;
        font-weight: 400;
        fill: #4B4640;
      }
      .card-filter {
        filter: drop-shadow(0px 1.5px 4px rgba(33, 24, 17, 0.035)) drop-shadow(0px 4px 8px rgba(46, 40, 32, 0.025));
      }
    </style>
  </defs>"""

# ==============================================================================
# 1. 完整三组流式长 SVG: tab1_conversations.svg (w: 400, h: 606)
# ==============================================================================
# 高度与坐标精确计算：
# 组 1:
# - 气泡 1 (摸鱼): y = 0, h = 35. 宽 58, x = 400 - 58 = 342.
# - 间距: 12px
# - 卡片 1 (Word): y = 47. 高度 188px.
# - 组间距: 28px
# 
# 组 2:
# - 气泡 2 (热水器坏了...): y = 47 + 188 + 28 = 263. h = 35. 宽 235, x = 400 - 235 = 165.
# - 间距: 12px
# - 卡片 2 (Sentence express): y = 263 + 35 + 12 = 310. 高度 122px.
# - 组间距: 28px
# 
# 组 3:
# - 气泡 3 (Running 10 min late...): y = 310 + 122 + 28 = 460. h = 35. 宽 271, x = 400 - 271 = 129.
# - 间距: 12px
# - 卡片 3 (Sentence comprehend): y = 460 + 35 + 12 = 507. 高度 99px.
# 
# 总高度: 507 + 99 = 606px.

full_svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 606" width="400" height="606" fill="none">
{SVG_DEFS}

  <!-- ======================================================== -->
  <!-- 第 1 组: 摸鱼 -> WORD (slack off)                          -->
  <!-- ======================================================== -->

  <!-- 用户气泡 1 (y: 0, h: 35) -->
  <g transform="translate(0, 0)">
    <rect x="342" y="0" width="58" height="35" rx="14" fill="#F4F0EB" />
    <rect x="342.25" y="0.25" width="57.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
    <text x="371" y="22.5" text-anchor="middle" class="bubble-text">摸鱼</text>
  </g>

  <!-- 间距: 12px -->

  <!-- AI 卡片 1 (y: 47, h: 188) -->
  <g transform="translate(0, 47)">
    <rect x="0" y="0" width="400" height="188" rx="20" fill="#FFFFFF" class="card-filter" />
    <rect x="0.25" y="0.25" width="399.5" height="187.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />

    <!-- 1. CardTypeChip: 纯文本 uppercase，无底框 -->
    <text x="16" y="27" class="font-sans" font-size="11" font-weight="600" letter-spacing="0.8" fill="#7C7773">WORD</text>

    <!-- 2. 词条标题: Charter-Bold 20px -->
    <text x="16" y="57" class="font-serif" font-size="20" font-weight="700" fill="#211811">slack off</text>

    <!-- 3. 音标与词性: /slæk ɔ:f/ (13px mono) + v. (11px sans) -->
    <text x="16" y="74">
      <tspan class="font-mono" font-size="13" font-weight="400" fill="#7C7773">/slæk ɔ:f/</tspan>
      <tspan dx="8" class="font-sans" font-size="11" font-weight="400" fill="#7C7773">v.</tspan>
    </text>

    <!-- 4. 释义: 冬青黑体 15px -->
    <text x="16" y="97" class="font-sans" font-size="15" font-weight="400" fill="#4B4640">摸鱼，偷懒</text>

    <!-- 5. 小标: EXAMPLES -->
    <text x="16" y="124" class="font-sans" font-size="11" font-weight="600" letter-spacing="0.6" fill="#A5A099">EXAMPLES</text>

    <!-- 6. 例句: 英文 Charter 17px + 中文冬青黑体 15px -->
    <text x="16" y="148" class="font-serif" font-size="17" font-weight="400" fill="#211811">Stop slacking off and get back to work.</text>
    <text x="16" y="166" class="font-sans" font-size="15" font-weight="400" fill="#7C7773">别摸鱼了，回去干活。</text>
  </g>

  <!-- 间距: 28px (47 + 188 = 235 -> y: 263) -->

  <!-- ======================================================== -->
  <!-- 第 2 组: 热水器坏了... -> SENTENCE (express)                -->
  <!-- ======================================================== -->

  <!-- 用户气泡 2 (y: 263, h: 35) -->
  <g transform="translate(0, 263)">
    <rect x="165" y="0" width="235" height="35" rx="14" fill="#F4F0EB" />
    <rect x="165.25" y="0.25" width="234.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
    <text x="282.5" y="22.5" text-anchor="middle" class="bubble-text">热水器坏了，能找人来修下么？</text>
  </g>

  <!-- 间距: 12px -->

  <!-- AI 卡片 2 (y: 310, h: 122) -->
  <g transform="translate(0, 310)">
    <rect x="0" y="0" width="400" height="122" rx="20" fill="#FFFFFF" class="card-filter" />
    <rect x="0.25" y="0.25" width="399.5" height="121.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />

    <!-- 1. CardTypeChip: 纯文本 uppercase -->
    <text x="16" y="27" class="font-sans" font-size="11" font-weight="600" letter-spacing="0.8" fill="#7C7773">SENTENCE</text>

    <!-- 2. 中文语境 (原句轻灰): 冬青黑体 15px -->
    <text x="16" y="57" class="font-sans" font-size="15" font-weight="400" fill="#7C7773">热水器坏了，能找人来修下么？</text>

    <!-- 3. 英文主角: Charter 17px -->
    <text x="16" y="77" class="font-serif" font-size="17" font-weight="400" fill="#211811">The water heater is broken. Could you send</text>
    <text x="16" y="100" class="font-serif" font-size="17" font-weight="400" fill="#211811">someone to fix it?</text>
  </g>

  <!-- 间距: 28px (310 + 122 = 432 -> y: 460) -->

  <!-- ======================================================== -->
  <!-- 第 3 组: Running 10 min late... -> SENTENCE (comprehend) -->
  <!-- ======================================================== -->

  <!-- 用户气泡 3 (y: 460, h: 35) -->
  <g transform="translate(0, 460)">
    <rect x="129" y="0" width="271" height="35" rx="14" fill="#F4F0EB" />
    <rect x="129.25" y="0.25" width="270.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
    <text x="264.5" y="22.5" text-anchor="middle" class="bubble-text">Running 10 min late, be there soon.</text>
  </g>

  <!-- 间距: 12px -->

  <!-- AI 卡片 3 (y: 507, h: 99) -->
  <g transform="translate(0, 507)">
    <rect x="0" y="0" width="400" height="99" rx="20" fill="#FFFFFF" class="card-filter" />
    <rect x="0.25" y="0.25" width="399.5" height="98.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />

    <!-- 1. CardTypeChip: 纯文本 uppercase -->
    <text x="16" y="27" class="font-sans" font-size="11" font-weight="600" letter-spacing="0.8" fill="#7C7773">SENTENCE</text>

    <!-- 2. 英文主角: Charter 17px -->
    <text x="16" y="59" class="font-serif" font-size="17" font-weight="400" fill="#211811">Running 10 min late, be there soon.</text>

    <!-- 3. 中文译文: 冬青黑体 15px -->
    <text x="16" y="77" class="font-sans" font-size="15" font-weight="400" fill="#7C7773">会迟到大概十分钟，马上就到。</text>
  </g>
</svg>"""

with open(os.path.join(SVG_DIR, "tab1_conversations.svg"), "w", encoding="utf-8") as f:
    f.write(full_svg)

# ==============================================================================
# 2. 独立第 1 组: group1_slack_off.svg (w: 400, h: 235)
# ==============================================================================
g1_svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 235" width="400" height="235" fill="none">
{SVG_DEFS}
  <!-- 气泡 (y: 0, h: 35) -->
  <rect x="342" y="0" width="58" height="35" rx="14" fill="#F4F0EB" />
  <rect x="342.25" y="0.25" width="57.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
  <text x="371" y="22.5" text-anchor="middle" class="bubble-text">摸鱼</text>

  <!-- 间距 12px -> 卡片 (y: 47, h: 188) -->
  <g transform="translate(0, 47)">
    <rect x="0" y="0" width="400" height="188" rx="20" fill="#FFFFFF" class="card-filter" />
    <rect x="0.25" y="0.25" width="399.5" height="187.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />

    <text x="16" y="27" class="font-sans" font-size="11" font-weight="600" letter-spacing="0.8" fill="#7C7773">WORD</text>
    <text x="16" y="57" class="font-serif" font-size="20" font-weight="700" fill="#211811">slack off</text>
    <text x="16" y="74">
      <tspan class="font-mono" font-size="13" font-weight="400" fill="#7C7773">/slæk ɔ:f/</tspan>
      <tspan dx="8" class="font-sans" font-size="11" font-weight="400" fill="#7C7773">v.</tspan>
    </text>
    <text x="16" y="97" class="font-sans" font-size="15" font-weight="400" fill="#4B4640">摸鱼，偷懒</text>
    <text x="16" y="124" class="font-sans" font-size="11" font-weight="600" letter-spacing="0.6" fill="#A5A099">EXAMPLES</text>
    <text x="16" y="148" class="font-serif" font-size="17" font-weight="400" fill="#211811">Stop slacking off and get back to work.</text>
    <text x="16" y="166" class="font-sans" font-size="15" font-weight="400" fill="#7C7773">别摸鱼了，回去干活。</text>
  </g>
</svg>"""

with open(os.path.join(SVG_DIR, "group1_slack_off.svg"), "w", encoding="utf-8") as f:
    f.write(g1_svg)

# ==============================================================================
# 3. 独立第 2 组: group2_water_heater.svg (w: 400, h: 169)
# ==============================================================================
g2_svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 169" width="400" height="169" fill="none">
{SVG_DEFS}
  <!-- 气泡 (y: 0, h: 35) -->
  <rect x="165" y="0" width="235" height="35" rx="14" fill="#F4F0EB" />
  <rect x="165.25" y="0.25" width="234.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
  <text x="282.5" y="22.5" text-anchor="middle" class="bubble-text">热水器坏了，能找人来修下么？</text>

  <!-- 间距 12px -> 卡片 (y: 47, h: 122) -->
  <g transform="translate(0, 47)">
    <rect x="0" y="0" width="400" height="122" rx="20" fill="#FFFFFF" class="card-filter" />
    <rect x="0.25" y="0.25" width="399.5" height="121.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />

    <text x="16" y="27" class="font-sans" font-size="11" font-weight="600" letter-spacing="0.8" fill="#7C7773">SENTENCE</text>
    <text x="16" y="57" class="font-sans" font-size="15" font-weight="400" fill="#7C7773">热水器坏了，能找人来修下么？</text>
    <text x="16" y="77" class="font-serif" font-size="17" font-weight="400" fill="#211811">The water heater is broken. Could you send</text>
    <text x="16" y="100" class="font-serif" font-size="17" font-weight="400" fill="#211811">someone to fix it?</text>
  </g>
</svg>"""

with open(os.path.join(SVG_DIR, "group2_water_heater.svg"), "w", encoding="utf-8") as f:
    f.write(g2_svg)

# ==============================================================================
# 4. 独立第 3 组: group3_running_late.svg (w: 400, h: 146)
# ==============================================================================
g3_svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 146" width="400" height="146" fill="none">
{SVG_DEFS}
  <!-- 气泡 (y: 0, h: 35) -->
  <rect x="129" y="0" width="271" height="35" rx="14" fill="#F4F0EB" />
  <rect x="129.25" y="0.25" width="270.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
  <text x="264.5" y="22.5" text-anchor="middle" class="bubble-text">Running 10 min late, be there soon.</text>

  <!-- 间距 12px -> 卡片 (y: 47, h: 99) -->
  <g transform="translate(0, 47)">
    <rect x="0" y="0" width="400" height="99" rx="20" fill="#FFFFFF" class="card-filter" />
    <rect x="0.25" y="0.25" width="399.5" height="98.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />

    <text x="16" y="27" class="font-sans" font-size="11" font-weight="600" letter-spacing="0.8" fill="#7C7773">SENTENCE</text>
    <text x="16" y="59" class="font-serif" font-size="17" font-weight="400" fill="#211811">Running 10 min late, be there soon.</text>
    <text x="16" y="77" class="font-sans" font-size="15" font-weight="400" fill="#7C7773">会迟到大概十分钟，马上就到。</text>
  </g>
</svg>"""

with open(os.path.join(SVG_DIR, "group3_running_late.svg"), "w", encoding="utf-8") as f:
    f.write(g3_svg)

print("🎯 v3 极致校准版矢量 SVG 已重新生成并写入！")
