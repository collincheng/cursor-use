import AppKit

/// `--icon-preview <路径.png>`:把菜单栏图标在不同用量下、浅色/深色背景上渲染成一张图,用来检查设计。
enum IconPreview {
    static func run(outputPath: String) -> Int32 {
        let samples: [Double?] = [nil, 0, 1, 10, 25, 50, 75, 90, 100]
        let scale: CGFloat = 6
        let cell = MenuBarIcon.canvas + 8          // 图标周围留白
        let width = cell * CGFloat(samples.count)
        let height = cell * 2                      // 上排浅色,下排深色

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
            FileHandle.standardError.write(Data("无法创建位图\n".utf8))
            return 1
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: scale, y: scale)

        let rows: [(background: NSColor, foreground: NSColor, y: CGFloat)] = [
            (NSColor(white: 0.94, alpha: 1), .black, cell),   // 浅色菜单栏(坐标原点在左下,所以浅色在上)
            (NSColor(white: 0.16, alpha: 1), .white, 0),      // 深色菜单栏
        ]
        for row in rows {
            row.background.setFill()
            CGRect(x: 0, y: row.y, width: width, height: cell).fill()
            for (i, percent) in samples.enumerated() {
                let rect = CGRect(x: CGFloat(i) * cell + 4, y: row.y + 4, width: MenuBarIcon.canvas, height: MenuBarIcon.canvas)
                MenuBarIcon.draw(in: rect, percent: percent, color: row.foreground)
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        guard let png = rep.representation(using: .png, properties: [:]) else { return 1 }
        do {
            try png.write(to: URL(fileURLWithPath: outputPath))
            print("已写入 \(outputPath)(从左到右: 无数据, 0%, 1%, 10%, 25%, 50%, 75%, 90%, 100%)")
            return 0
        } catch {
            FileHandle.standardError.write(Data("写入失败: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }
}
