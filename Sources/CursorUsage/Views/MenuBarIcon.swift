import AppKit

/// 菜单栏图标:270° 仪表盘弧(下方留缺口)+ 指针,进度弧和指针随用量变化。
/// 以模板图方式使用,颜色由系统按深色/浅色菜单栏自动处理。
enum MenuBarIcon {
    static let canvas: CGFloat = 18

    /// 弧线从左下(225°)顺时针经过顶部到右下(-45°),共 270°
    private static let startAngle: CGFloat = 225
    private static let sweep: CGFloat = 270

    static func image(percent: Double?) -> NSImage {
        let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { rect in
            draw(in: rect, percent: percent, color: .black)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// 进度比例 0...1。有进度时至少留一个圆点,避免 1% 时什么都看不到。
    static func fraction(for percent: Double?) -> CGFloat {
        guard let percent, percent > 0 else { return 0 }
        return CGFloat(max(0.02, min(1, percent / 100)))
    }

    static func draw(in rect: CGRect, percent: Double?, color: NSColor) {
        let lineWidth: CGFloat = 2.2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2 - 0.5
        let f = fraction(for: percent)
        let endAngle = startAngle - sweep * f

        func arc(from a: CGFloat, to b: CGFloat) -> NSBezierPath {
            let p = NSBezierPath()
            p.appendArc(withCenter: center, radius: radius, startAngle: a, endAngle: b, clockwise: true)
            p.lineWidth = lineWidth
            p.lineCapStyle = .round
            return p
        }

        // 轨道
        color.withAlphaComponent(0.32).setStroke()
        arc(from: startAngle, to: startAngle - sweep).stroke()

        // 进度
        if f > 0 {
            color.setStroke()
            arc(from: startAngle, to: endAngle).stroke()
        }

        // 指针:从圆心指向当前进度位置
        let radians = endAngle * .pi / 180
        let needleLength = radius * 0.62
        let needle = NSBezierPath()
        needle.move(to: center)
        needle.line(to: CGPoint(x: center.x + cos(radians) * needleLength,
                                y: center.y + sin(radians) * needleLength))
        needle.lineWidth = 1.6
        needle.lineCapStyle = .round
        color.setStroke()
        needle.stroke()

        // 圆心
        color.setFill()
        NSBezierPath(ovalIn: CGRect(x: center.x - 1.7, y: center.y - 1.7, width: 3.4, height: 3.4)).fill()
    }
}
