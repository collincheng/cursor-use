// 应用图标生成脚本:用矢量绘制各尺寸 PNG(不依赖设计软件)。
//
// 用法:
//   swift scripts/make-icon.swift <输出 iconset 目录>     生成全套尺寸
//   swift scripts/make-icon.swift --preview <输出.png>    只渲染一张 512px 预览
// 一般通过 scripts/make-icon.sh 调用,它会再用 iconutil 合成 Resources/AppIcon.icns。
import AppKit

/// 设计稿坐标系为 1024×1024,原点在左下。macOS 图标主体约占 824×824,四周留白放投影。
let canvas: CGFloat = 1024

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255,
            alpha: alpha)
}

func radians(_ degrees: CGFloat) -> CGFloat { degrees * .pi / 180 }

func drawIcon() {
    let cg = NSGraphicsContext.current!.cgContext

    // ---- 圆角方块:投影 + 深色渐变底 ----
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 184, yRadius: 184)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 30
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.38)
    shadow.set()
    NSColor.black.setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSGradient(starting: rgb(0x3B404C), ending: rgb(0x15171C))!.draw(in: tile, angle: -90)
    // 上半部一层很淡的高光,让底色有层次
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)])!
        .draw(in: CGRect(x: 100, y: 512, width: 824, height: 412), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    rgb(0xFFFFFF, 0.10).setStroke()
    tilePath.lineWidth = 3
    tilePath.stroke()

    // ---- 仪表盘:270° 弧,从左下顺时针经顶部到右下 ----
    let center = CGPoint(x: 512, y: 488)
    let radius: CGFloat = 255
    let lineWidth: CGFloat = 66
    let startAngle: CGFloat = 225
    let sweep: CGFloat = 270
    let fraction: CGFloat = 0.72                       // 图标上展示的"用量"
    let endAngle = startAngle - sweep * fraction

    // 轨道
    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: radius, startAngle: startAngle,
                    endAngle: startAngle - sweep, clockwise: true)
    track.lineWidth = lineWidth
    track.lineCapStyle = .round
    rgb(0xFFFFFF, 0.14).setStroke()
    track.stroke()

    // 进度弧:先把描边转成区域再裁剪,这样才能填充渐变(绿 → 黄)
    cg.saveGState()
    cg.addArc(center: center, radius: radius, startAngle: radians(startAngle),
              endAngle: radians(endAngle), clockwise: true)
    cg.setLineWidth(lineWidth)
    cg.setLineCap(.round)
    cg.replacePathWithStrokedPath()
    cg.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [rgb(0x32D74B).cgColor, rgb(0xFFD60A).cgColor] as CFArray,
                              locations: [0, 1])!
    cg.drawLinearGradient(gradient,
                          start: CGPoint(x: center.x - radius, y: center.y),
                          end: CGPoint(x: center.x + radius, y: center.y),
                          // 描边外缘超出渐变的起止点,必须向两端延伸,否则弧的外侧会被切平
                          options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    cg.restoreGState()

    // 指针和圆心
    let needleLength = radius * 0.62
    let needle = NSBezierPath()
    needle.move(to: center)
    needle.line(to: CGPoint(x: center.x + cos(radians(endAngle)) * needleLength,
                            y: center.y + sin(radians(endAngle)) * needleLength))
    needle.lineWidth = 40
    needle.lineCapStyle = .round
    NSColor.white.setStroke()
    needle.stroke()

    NSColor.white.setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - 46, y: center.y - 46, width: 92, height: 92)).fill()
}

/// 按像素尺寸直接用矢量重绘(比缩小大图更清晰)
func renderPNG(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

// ---- 入口 ----
let args = CommandLine.arguments
if args.count >= 3, args[1] == "--preview" {
    try renderPNG(pixels: 512).write(to: URL(fileURLWithPath: args[2]))
    print("预览已写入 \(args[2])")
} else if args.count >= 2 {
    let dir = URL(fileURLWithPath: args[1])
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    // iconutil 要求的文件名:基础尺寸 + @2x
    for base in [16, 32, 128, 256, 512] {
        try renderPNG(pixels: base).write(to: dir.appendingPathComponent("icon_\(base)x\(base).png"))
        try renderPNG(pixels: base * 2).write(to: dir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
    }
    print("已生成 iconset: \(dir.path)")
} else {
    FileHandle.standardError.write(Data("用法: make-icon.swift <iconset 目录> | --preview <输出.png>\n".utf8))
    exit(1)
}
