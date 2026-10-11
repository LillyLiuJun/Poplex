#!/usr/bin/env swift
import Foundation
import CoreGraphics
import CoreText

// MARK: - 注册字体
let fontURL = URL(fileURLWithPath: "AIEnglishApp/Resources/Fonts/GothicA1-SemiBold.ttf")
var fontRegError: Unmanaged<CFError>?
if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &fontRegError) {
    print("✅ GothicA1-SemiBold 字体注册成功")
} else {
    print("⚠️ 字体注册提示: \(String(describing: fontRegError?.takeRetainedValue()))")
}

// MARK: - 文本转曲路径提取器
struct OutlinedTextItem {
    let text: String
    let fontName: String
    let fontSize: CGFloat
    let tracking: CGFloat
    let x: CGFloat
    let y: CGFloat
    let fill: String
}

func renderTextToSVGPath(item: OutlinedTextItem) -> String {
    let font = CTFontCreateWithName(item.fontName as CFString, item.fontSize, nil)
    var attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font
    ]
    if item.tracking > 0 {
        attrs[NSAttributedString.Key(kCTKernAttributeName as String)] = item.tracking
    }
    
    let attrStr = NSAttributedString(string: item.text, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)
    let runs = CTLineGetGlyphRuns(line) as! [CTRun]
    var d = ""
    
    for run in runs {
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] as! CTFont
        let glyphCount = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
        var positions = [CGPoint](repeating: .zero, count: glyphCount)
        CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &glyphs)
        CTRunGetPositions(run, CFRangeMake(0, glyphCount), &positions)
        
        for i in 0..<glyphCount {
            var transform = CGAffineTransform(scaleX: 1, y: -1)
                .concatenating(CGAffineTransform(translationX: item.x + positions[i].x, y: item.y))
            if let path = CTFontCreatePathForGlyph(runFont, glyphs[i], &transform) {
                path.applyWithBlock { element in
                    let points = element.pointee.points
                    switch element.pointee.type {
                    case .moveToPoint:
                        d += String(format: "M%.2f,%.2f ", points[0].x, points[0].y)
                    case .addLineToPoint:
                        d += String(format: "L%.2f,%.2f ", points[0].x, points[0].y)
                    case .addQuadCurveToPoint:
                        d += String(format: "Q%.2f,%.2f %.2f,%.2f ", points[0].x, points[0].y, points[1].x, points[1].y)
                    case .addCurveToPoint:
                        d += String(format: "C%.2f,%.2f %.2f,%.2f %.2f,%.2f ", points[0].x, points[0].y, points[1].x, points[1].y, points[2].x, points[2].y)
                    case .closeSubpath:
                        d += "Z "
                    @unknown default:
                        break
                    }
                }
            }
        }
    }
    return "<path d=\"\(d)\" fill=\"\(item.fill)\" />"
}

let svgDir = "store_screenshots/assets"

// =========================================================================
// 方案 A: 优雅宽幅版 (442×152pt) —— 完美容纳 2 行英文，绝不穿模，海报悬浮黄金比例
// =========================================================================
// 卡片宽 442pt (内容宽 410.24pt + 左右各 16pt = 442.24pt)，高度 152pt
let widthA: CGFloat = 442
let heightA: CGFloat = 152

let chipPathA = renderTextToSVGPath(item: OutlinedTextItem(
    text: "SENTENCE",
    fontName: "GothicA1-SemiBold",
    fontSize: 11,
    tracking: 0.8,
    x: 16,
    y: 27,
    fill: "#7C7773"
))

let zhLine1PathA = renderTextToSVGPath(item: OutlinedTextItem(
    text: "一只穿着红色格子背带的波士顿梗犬嘴里叼着蓝色",
    fontName: "HiraginoSansGB-W3",
    fontSize: 15,
    tracking: 0,
    x: 16,
    y: 58,
    fill: "#7C7773"
))

let zhLine2PathA = renderTextToSVGPath(item: OutlinedTextItem(
    text: "玩具，正在草地上奔跑。",
    fontName: "HiraginoSansGB-W3",
    fontSize: 15,
    tracking: 0,
    x: 16,
    y: 80,
    fill: "#7C7773"
))

let enLine1PathA = renderTextToSVGPath(item: OutlinedTextItem(
    text: "A Boston Terrier wearing a red plaid harness is running",
    fontName: "Charter-Roman",
    fontSize: 17,
    tracking: 0,
    x: 16,
    y: 106,
    fill: "#211811"
))

let enLine2PathA = renderTextToSVGPath(item: OutlinedTextItem(
    text: "on a grassy field with a blue toy in its mouth.",
    fontName: "Charter-Roman",
    fontSize: 17,
    tracking: 0,
    x: 16,
    y: 130,
    fill: "#211811"
))

// 生成 sentence_card_dog_compact.svg (纯矢量、无外边距、442×152)
let dogCompactSvg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(widthA)) \(Int(heightA))" width="\(Int(widthA))" height="\(Int(heightA))" fill="none">
  <!-- Poplex Sentence Card · 纯矢量转曲版 (CoreText Outlined, 零字体依赖, Figma 100% 锐利不失真) -->
  <!-- 卡片背景与 0.5pt 细描边 -->
  <rect x="0.25" y="0.25" width="\(widthA - 0.5)" height="\(heightA - 0.5)" rx="20" ry="20" fill="#FFFDFB" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.35" />

  <!-- 1. CardTypeChip: SENTENCE (Gothic A1 SemiBold 11pt, tracking 0.8) -->
  \(chipPathA)

  <!-- 2. 母语场景提示 (Hiragino Sans GB W3 15pt) -->
  \(zhLine1PathA)
  \(zhLine2PathA)

  <!-- 3. 目标语言地道表达 (Charter-Roman 17pt) -->
  \(enLine1PathA)
  \(enLine2PathA)
</svg>
"""

try! dogCompactSvg.write(toFile: "\(svgDir)/sentence_card_dog_compact.svg", atomically: true, encoding: .utf8)
print("✅ 生成 \(svgDir)/sentence_card_dog_compact.svg (442×152)")

// 生成带双层物理投影的 sentence_card_dog.svg (474×188)
// 左右各 16pt 阴影空间，上下留出 18pt 投影空间
let dogWithShadowSvg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 474 188" width="474" height="188" fill="none">
  <!-- Poplex 双层卡片紧阴影 (AppTheme.Shadow.cardShadow) -->
  <defs>
    <filter id="poplex-card-shadow" x="-8%" y="-8%" width="116%" height="124%" filterUnits="objectBoundingBox">
      <feDropShadow dx="0" dy="1.5" stdDeviation="2" flood-color="#211811" flood-opacity="0.035" />
      <feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#2E2820" flood-opacity="0.025" />
    </filter>
  </defs>

  <g transform="translate(16, 10)">
    <!-- 卡片背景与 0.5pt 细描边 -->
    <rect x="0" y="0" width="\(widthA)" height="\(heightA)" rx="20" ry="20" fill="#FFFDFB" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.35" filter="url(#poplex-card-shadow)" />

    <!-- 1. CardTypeChip: SENTENCE (Gothic A1 SemiBold 11pt, tracking 0.8) -->
    \(chipPathA)

    <!-- 2. 母语场景提示 (Hiragino Sans GB W3 15pt) -->
    \(zhLine1PathA)
    \(zhLine2PathA)

    <!-- 3. 目标语言地道表达 (Charter-Roman 17pt) -->
    \(enLine1PathA)
    \(enLine2PathA)
  </g>
</svg>
"""

try! dogWithShadowSvg.write(toFile: "\(svgDir)/sentence_card_dog.svg", atomically: true, encoding: .utf8)
print("✅ 生成 \(svgDir)/sentence_card_dog.svg (带物理投影 474×188)")


// =========================================================================
// 方案 B: 标准 400pt 卡片宽度版 (400×176pt) —— 严格 400pt 容器，英文 3 行真实物理换行
// =========================================================================
let widthB: CGFloat = 400
let heightB: CGFloat = 176

let enLine1PathB = renderTextToSVGPath(item: OutlinedTextItem(
    text: "A Boston Terrier wearing a red plaid harness is",
    fontName: "Charter-Roman",
    fontSize: 17,
    tracking: 0,
    x: 16,
    y: 106,
    fill: "#211811"
))

let enLine2PathB = renderTextToSVGPath(item: OutlinedTextItem(
    text: "running on a grassy field with a blue toy in its",
    fontName: "Charter-Roman",
    fontSize: 17,
    tracking: 0,
    x: 16,
    y: 130,
    fill: "#211811"
))

let enLine3PathB = renderTextToSVGPath(item: OutlinedTextItem(
    text: "mouth.",
    fontName: "Charter-Roman",
    fontSize: 17,
    tracking: 0,
    x: 16,
    y: 154,
    fill: "#211811"
))

let dog400wCompactSvg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(widthB)) \(Int(heightB))" width="\(Int(widthB))" height="\(Int(heightB))" fill="none">
  <!-- Poplex Sentence Card · 400pt 容器 3 行自然折行版 (纯矢量转曲) -->
  <rect x="0.25" y="0.25" width="\(widthB - 0.5)" height="\(heightB - 0.5)" rx="20" ry="20" fill="#FFFDFB" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.35" />

  <!-- 1. CardTypeChip: SENTENCE -->
  \(chipPathA)

  <!-- 2. 母语场景提示 -->
  \(zhLine1PathA)
  \(zhLine2PathA)

  <!-- 3. 目标语言地道表达 (3行自然换行) -->
  \(enLine1PathB)
  \(enLine2PathB)
  \(enLine3PathB)
</svg>
"""

try! dog400wCompactSvg.write(toFile: "\(svgDir)/sentence_card_dog_400w.svg", atomically: true, encoding: .utf8)
print("✅ 生成 \(svgDir)/sentence_card_dog_400w.svg (400×176)")
