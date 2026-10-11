#!/usr/bin/env swift
import Foundation
import CoreGraphics
import CoreText

// MARK: - CoreText to SVG Path Converter

struct TextItem {
    let text: String
    let fontName: String
    let fontSize: CGFloat
    let x: CGFloat
    let y: CGFloat
    let fill: String
    let alignCenter: Bool
    let containerWidth: CGFloat?
}

func renderTextToSVGPath(item: TextItem) -> String {
    let font = CTFontCreateWithName(item.fontName as CFString, item.fontSize, nil)
    let attrStr = NSAttributedString(string: item.text, attributes: [
        kCTFontAttributeName as NSAttributedString.Key: font
    ])
    let line = CTLineCreateWithAttributedString(attrStr)
    let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    
    var originX = item.x
    if item.alignCenter, let containerWidth = item.containerWidth {
        originX = item.x + (containerWidth - lineWidth) / 2.0
    }
    
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
                .concatenating(CGAffineTransform(translationX: originX + positions[i].x, y: item.y))
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

// MARK: - 构建完整的转曲 SVG

let svgDir = "store_screenshots/assets"

// 1. 全量长流: tab1_conversations.svg
var fullSvg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 606" width="400" height="606" fill="none">
  <!-- 阴影滤镜 -->
  <defs>
    <filter id="card-shadow" x="-8" y="-4" width="416" height="210" filterUnits="userSpaceOnUse">
      <feDropShadow dx="0" dy="1.5" stdDeviation="2" flood-color="#211811" flood-opacity="0.035" />
      <feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#2E2820" flood-opacity="0.025" />
    </filter>
  </defs>

  <!-- ================= 第 1 组: 摸鱼 -> slack off ================= -->
  <!-- 气泡 1 (y: 0, h: 35) -->
  <g id="bubble-1">
    <rect x="342" y="0" width="58" height="35" rx="14" fill="#F4F0EB" />
    <rect x="342.25" y="0.25" width="57.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
    \(renderTextToSVGPath(item: TextItem(text: "摸鱼", fontName: "PingFangSC-Regular", fontSize: 15, x: 342, y: 22.5, fill: "#4B4640", alignCenter: true, containerWidth: 58)))
  </g>

  <!-- 卡片 1 (y: 47, h: 188) -->
  <g id="card-1">
    <rect x="0" y="47" width="400" height="188" rx="20" fill="#FFFFFF" filter="url(#card-shadow)" />
    <rect x="0.25" y="47.25" width="399.5" height="187.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />

    <!-- WORD 类型标 -->
    \(renderTextToSVGPath(item: TextItem(text: "WORD", fontName: "PingFangSC-Semibold", fontSize: 11, x: 16, y: 47 + 27, fill: "#7C7773", alignCenter: false, containerWidth: nil)))

    <!-- slack off 词条 -->
    \(renderTextToSVGPath(item: TextItem(text: "slack off", fontName: "Charter-Bold", fontSize: 20, x: 16, y: 47 + 57, fill: "#211811", alignCenter: false, containerWidth: nil)))

    <!-- 音标与词性 -->
    \(renderTextToSVGPath(item: TextItem(text: "/slæk ɔ:f/", fontName: "Menlo-Regular", fontSize: 13, x: 16, y: 47 + 74, fill: "#7C7773", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "v.", fontName: "PingFangSC-Regular", fontSize: 11, x: 16 + 72, y: 47 + 74, fill: "#7C7773", alignCenter: false, containerWidth: nil)))

    <!-- 释义 -->
    \(renderTextToSVGPath(item: TextItem(text: "摸鱼，偷懒", fontName: "PingFangSC-Regular", fontSize: 15, x: 16, y: 47 + 97, fill: "#4B4640", alignCenter: false, containerWidth: nil)))

    <!-- EXAMPLES 小标 -->
    \(renderTextToSVGPath(item: TextItem(text: "EXAMPLES", fontName: "PingFangSC-Semibold", fontSize: 11, x: 16, y: 47 + 124, fill: "#A5A099", alignCenter: false, containerWidth: nil)))

    <!-- 例句英文与中文 -->
    \(renderTextToSVGPath(item: TextItem(text: "Stop slacking off and get back to work.", fontName: "Charter-Roman", fontSize: 17, x: 16, y: 47 + 148, fill: "#211811", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "别摸鱼了，回去干活。", fontName: "PingFangSC-Regular", fontSize: 15, x: 16, y: 47 + 166, fill: "#7C7773", alignCenter: false, containerWidth: nil)))
  </g>

  <!-- ================= 第 2 组: 热水器坏了 -> water heater ================= -->
  <!-- 气泡 2 (y: 263, h: 35) -->
  <g id="bubble-2">
    <rect x="165" y="263" width="235" height="35" rx="14" fill="#F4F0EB" />
    <rect x="165.25" y="263.25" width="234.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
    \(renderTextToSVGPath(item: TextItem(text: "热水器坏了，能找人来修下么？", fontName: "PingFangSC-Regular", fontSize: 15, x: 165, y: 263 + 22.5, fill: "#4B4640", alignCenter: true, containerWidth: 235)))
  </g>

  <!-- 卡片 2 (y: 310, h: 122) -->
  <g id="card-2">
    <rect x="0" y="310" width="400" height="122" rx="20" fill="#FFFFFF" filter="url(#card-shadow)" />
    <rect x="0.25" y="310.25" width="399.5" height="121.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />

    <!-- SENTENCE 类型标 -->
    \(renderTextToSVGPath(item: TextItem(text: "SENTENCE", fontName: "PingFangSC-Semibold", fontSize: 11, x: 16, y: 310 + 27, fill: "#7C7773", alignCenter: false, containerWidth: nil)))

    <!-- 中文语境 -->
    \(renderTextToSVGPath(item: TextItem(text: "热水器坏了，能找人来修下么？", fontName: "PingFangSC-Regular", fontSize: 15, x: 16, y: 310 + 57, fill: "#7C7773", alignCenter: false, containerWidth: nil)))

    <!-- 英文地道主角 (两行) -->
    \(renderTextToSVGPath(item: TextItem(text: "The water heater is broken. Could you send", fontName: "Charter-Roman", fontSize: 17, x: 16, y: 310 + 77, fill: "#211811", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "someone to fix it?", fontName: "Charter-Roman", fontSize: 17, x: 16, y: 310 + 100, fill: "#211811", alignCenter: false, containerWidth: nil)))
  </g>

  <!-- ================= 第 3 组: Running late -> 迟到 ================= -->
  <!-- 气泡 3 (y: 460, h: 35) -->
  <g id="bubble-3">
    <rect x="129" y="460" width="271" height="35" rx="14" fill="#F4F0EB" />
    <rect x="129.25" y="460.25" width="270.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
    \(renderTextToSVGPath(item: TextItem(text: "Running 10 min late, be there soon.", fontName: "PingFangSC-Regular", fontSize: 15, x: 129, y: 460 + 22.5, fill: "#4B4640", alignCenter: true, containerWidth: 271)))
  </g>

  <!-- 卡片 3 (y: 507, h: 99) -->
  <g id="card-3">
    <rect x="0" y="507" width="400" height="99" rx="20" fill="#FFFFFF" filter="url(#card-shadow)" />
    <rect x="0.25" y="507.25" width="399.5" height="98.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />

    <!-- SENTENCE 类型标 -->
    \(renderTextToSVGPath(item: TextItem(text: "SENTENCE", fontName: "PingFangSC-Semibold", fontSize: 11, x: 16, y: 507 + 27, fill: "#7C7773", alignCenter: false, containerWidth: nil)))

    <!-- 英文主角 -->
    \(renderTextToSVGPath(item: TextItem(text: "Running 10 min late, be there soon.", fontName: "Charter-Roman", fontSize: 17, x: 16, y: 507 + 59, fill: "#211811", alignCenter: false, containerWidth: nil)))

    <!-- 中文译文 -->
    \(renderTextToSVGPath(item: TextItem(text: "会迟到大概十分钟，马上就到。", fontName: "PingFangSC-Regular", fontSize: 15, x: 16, y: 507 + 77, fill: "#7C7773", alignCenter: false, containerWidth: nil)))
  </g>
</svg>
"""

try! fullSvg.write(toFile: "\(svgDir)/tab1_conversations.svg", atomically: true, encoding: .utf8)
try! fullSvg.write(toFile: "\(svgDir)/tab1_conversations_outlined.svg", atomically: true, encoding: .utf8)

// 2. 独立第 1 组: group1_slack_off.svg
var g1Svg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 235" width="400" height="235" fill="none">
  <defs>
    <filter id="card-shadow-1" x="-8" y="-4" width="416" height="210" filterUnits="userSpaceOnUse">
      <feDropShadow dx="0" dy="1.5" stdDeviation="2" flood-color="#211811" flood-opacity="0.035" />
      <feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#2E2820" flood-opacity="0.025" />
    </filter>
  </defs>
  <rect x="342" y="0" width="58" height="35" rx="14" fill="#F4F0EB" />
  <rect x="342.25" y="0.25" width="57.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
  \(renderTextToSVGPath(item: TextItem(text: "摸鱼", fontName: "PingFangSC-Regular", fontSize: 15, x: 342, y: 22.5, fill: "#4B4640", alignCenter: true, containerWidth: 58)))

  <g transform="translate(0, 47)">
    <rect x="0" y="0" width="400" height="188" rx="20" fill="#FFFFFF" filter="url(#card-shadow-1)" />
    <rect x="0.25" y="0.25" width="399.5" height="187.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />
    \(renderTextToSVGPath(item: TextItem(text: "WORD", fontName: "PingFangSC-Semibold", fontSize: 11, x: 16, y: 27, fill: "#7C7773", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "slack off", fontName: "Charter-Bold", fontSize: 20, x: 16, y: 57, fill: "#211811", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "/slæk ɔ:f/", fontName: "Menlo-Regular", fontSize: 13, x: 16, y: 74, fill: "#7C7773", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "v.", fontName: "PingFangSC-Regular", fontSize: 11, x: 16 + 72, y: 74, fill: "#7C7773", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "摸鱼，偷懒", fontName: "PingFangSC-Regular", fontSize: 15, x: 16, y: 97, fill: "#4B4640", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "EXAMPLES", fontName: "PingFangSC-Semibold", fontSize: 11, x: 16, y: 124, fill: "#A5A099", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "Stop slacking off and get back to work.", fontName: "Charter-Roman", fontSize: 17, x: 16, y: 148, fill: "#211811", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "别摸鱼了，回去干活。", fontName: "PingFangSC-Regular", fontSize: 15, x: 16, y: 166, fill: "#7C7773", alignCenter: false, containerWidth: nil)))
  </g>
</svg>
"""
try! g1Svg.write(toFile: "\(svgDir)/group1_slack_off.svg", atomically: true, encoding: .utf8)

// 3. 独立第 2 组: group2_water_heater.svg
var g2Svg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 169" width="400" height="169" fill="none">
  <defs>
    <filter id="card-shadow-2" x="-8" y="-4" width="416" height="144" filterUnits="userSpaceOnUse">
      <feDropShadow dx="0" dy="1.5" stdDeviation="2" flood-color="#211811" flood-opacity="0.035" />
      <feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#2E2820" flood-opacity="0.025" />
    </filter>
  </defs>
  <rect x="165" y="0" width="235" height="35" rx="14" fill="#F4F0EB" />
  <rect x="165.25" y="0.25" width="234.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
  \(renderTextToSVGPath(item: TextItem(text: "热水器坏了，能找人来修下么？", fontName: "PingFangSC-Regular", fontSize: 15, x: 165, y: 22.5, fill: "#4B4640", alignCenter: true, containerWidth: 235)))

  <g transform="translate(0, 47)">
    <rect x="0" y="0" width="400" height="122" rx="20" fill="#FFFFFF" filter="url(#card-shadow-2)" />
    <rect x="0.25" y="0.25" width="399.5" height="121.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />
    \(renderTextToSVGPath(item: TextItem(text: "SENTENCE", fontName: "PingFangSC-Semibold", fontSize: 11, x: 16, y: 27, fill: "#7C7773", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "热水器坏了，能找人来修下么？", fontName: "PingFangSC-Regular", fontSize: 15, x: 16, y: 57, fill: "#7C7773", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "The water heater is broken. Could you send", fontName: "Charter-Roman", fontSize: 17, x: 16, y: 77, fill: "#211811", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "someone to fix it?", fontName: "Charter-Roman", fontSize: 17, x: 16, y: 100, fill: "#211811", alignCenter: false, containerWidth: nil)))
  </g>
</svg>
"""
try! g2Svg.write(toFile: "\(svgDir)/group2_water_heater.svg", atomically: true, encoding: .utf8)

// 4. 独立第 3 组: group3_running_late.svg
var g3Svg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 146" width="400" height="146" fill="none">
  <defs>
    <filter id="card-shadow-3" x="-8" y="-4" width="416" height="120" filterUnits="userSpaceOnUse">
      <feDropShadow dx="0" dy="1.5" stdDeviation="2" flood-color="#211811" flood-opacity="0.035" />
      <feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#2E2820" flood-opacity="0.025" />
    </filter>
  </defs>
  <rect x="129" y="0" width="271" height="35" rx="14" fill="#F4F0EB" />
  <rect x="129.25" y="0.25" width="270.5" height="34.5" rx="13.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.55" />
  \(renderTextToSVGPath(item: TextItem(text: "Running 10 min late, be there soon.", fontName: "PingFangSC-Regular", fontSize: 15, x: 129, y: 22.5, fill: "#4B4640", alignCenter: true, containerWidth: 271)))

  <g transform="translate(0, 47)">
    <rect x="0" y="0" width="400" height="99" rx="20" fill="#FFFFFF" filter="url(#card-shadow-3)" />
    <rect x="0.25" y="0.25" width="399.5" height="98.5" rx="19.75" fill="none" stroke="#E6E1DA" stroke-width="0.5" stroke-opacity="0.45" />
    \(renderTextToSVGPath(item: TextItem(text: "SENTENCE", fontName: "PingFangSC-Semibold", fontSize: 11, x: 16, y: 27, fill: "#7C7773", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "Running 10 min late, be there soon.", fontName: "Charter-Roman", fontSize: 17, x: 16, y: 59, fill: "#211811", alignCenter: false, containerWidth: nil)))
    \(renderTextToSVGPath(item: TextItem(text: "会迟到大概十分钟，马上就到。", fontName: "PingFangSC-Regular", fontSize: 15, x: 16, y: 77, fill: "#7C7773", alignCenter: false, containerWidth: nil)))
  </g>
</svg>
"""
try! g3Svg.write(toFile: "\(svgDir)/group3_running_late.svg", atomically: true, encoding: .utf8)

print("🎉 CoreText 纯矢量转曲 (Outlined) SVG 生成完毕！零字体依赖，Figma 粘贴 100% 永不失真！")
