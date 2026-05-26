//
//  DashboardCommandIcon.swift
//  simdock
//

import SwiftUI

struct DashboardCommandIcon: View {
    var command: SimulatorCommand
    var size: CGFloat = 20

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 20
            context.scaleBy(x: scale, y: scale)

            let style = StrokeStyle(lineWidth: strokeWidth(for: command), lineCap: .round, lineJoin: .round)

            switch command {
            case .home:
                context.stroke(roundedRect(x: 4, y: 4, width: 12, height: 12, radius: 3.5), with: .foreground, style: style)
            case .lock:
                var path = Path()
                path.addEllipse(in: CGRect(x: 5, y: 6, width: 10, height: 10))
                path.move(to: CGPoint(x: 10, y: 2))
                path.addLine(to: CGPoint(x: 10, y: 6))
                context.stroke(path, with: .foreground, style: style)
            case .side:
                context.stroke(roundedRect(x: 8, y: 3, width: 4, height: 14, radius: 2), with: .foreground, style: style)
            case .tap:
                context.stroke(tapPath, with: .foreground, style: style)
            case .scroll:
                context.stroke(scrollPath, with: .foreground, style: style)
            case .type:
                context.stroke(typePath, with: .foreground, style: style)
            case .push:
                context.stroke(pushPath, with: .foreground, style: style)
            case .link:
                context.stroke(linkPath, with: .foreground, style: style)
            case .record:
                context.fill(Path(ellipseIn: CGRect(x: 5, y: 5, width: 10, height: 10)), with: .foreground)
            case .screenshot:
                context.stroke(screenshotPath, with: .foreground, style: style)
            }
        }
        .frame(width: size, height: size)
    }

    private func strokeWidth(for command: SimulatorCommand) -> CGFloat {
        switch command {
        case .scroll, .type, .link, .push:
            1.45
        default:
            1.6
        }
    }

    private func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: radius)
    }

    private var tapPath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 6, y: 9))
        path.addLine(to: CGPoint(x: 6, y: 4.5))
        path.addCurve(to: CGPoint(x: 8, y: 4.5), control1: CGPoint(x: 6, y: 3.4), control2: CGPoint(x: 8, y: 3.4))
        path.addLine(to: CGPoint(x: 8, y: 9))
        path.move(to: CGPoint(x: 8, y: 6.4))
        path.addCurve(to: CGPoint(x: 10, y: 6.4), control1: CGPoint(x: 8, y: 5.4), control2: CGPoint(x: 10, y: 5.4))
        path.addLine(to: CGPoint(x: 10, y: 9.2))
        path.move(to: CGPoint(x: 10, y: 7.3))
        path.addCurve(to: CGPoint(x: 12, y: 7.3), control1: CGPoint(x: 10, y: 6.3), control2: CGPoint(x: 12, y: 6.3))
        path.addLine(to: CGPoint(x: 12, y: 10.4))
        path.addCurve(to: CGPoint(x: 7, y: 17), control1: CGPoint(x: 12, y: 14.1), control2: CGPoint(x: 10.4, y: 17))
        path.addLine(to: CGPoint(x: 5.5, y: 17))
        path.addCurve(to: CGPoint(x: 2.5, y: 14), control1: CGPoint(x: 3.8, y: 17), control2: CGPoint(x: 2.5, y: 15.6))
        path.addLine(to: CGPoint(x: 2.5, y: 9.8))
        path.addCurve(to: CGPoint(x: 4.5, y: 9.8), control1: CGPoint(x: 2.5, y: 8.8), control2: CGPoint(x: 4.5, y: 8.8))
        path.addLine(to: CGPoint(x: 4.5, y: 12.2))
        return path
    }

    private var scrollPath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 10, y: 2))
        path.addLine(to: CGPoint(x: 10, y: 18))
        path.move(to: CGPoint(x: 6, y: 6))
        path.addLine(to: CGPoint(x: 10, y: 2))
        path.addLine(to: CGPoint(x: 14, y: 6))
        path.move(to: CGPoint(x: 6, y: 14))
        path.addLine(to: CGPoint(x: 10, y: 18))
        path.addLine(to: CGPoint(x: 14, y: 14))
        return path
    }

    private var typePath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 4, y: 5))
        path.addLine(to: CGPoint(x: 16, y: 5))
        path.move(to: CGPoint(x: 10, y: 5))
        path.addLine(to: CGPoint(x: 10, y: 16))
        path.move(to: CGPoint(x: 7, y: 16))
        path.addLine(to: CGPoint(x: 13, y: 16))
        return path
    }

    private var pushPath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 10, y: 2))
        path.addCurve(to: CGPoint(x: 15, y: 7), control1: CGPoint(x: 13, y: 2), control2: CGPoint(x: 15, y: 4.3))
        path.addLine(to: CGPoint(x: 15, y: 12))
        path.addLine(to: CGPoint(x: 17, y: 15))
        path.addLine(to: CGPoint(x: 3, y: 15))
        path.addLine(to: CGPoint(x: 5, y: 12))
        path.addLine(to: CGPoint(x: 5, y: 7))
        path.addCurve(to: CGPoint(x: 10, y: 2), control1: CGPoint(x: 5, y: 4.3), control2: CGPoint(x: 7, y: 2))
        path.move(to: CGPoint(x: 10, y: 17))
        path.addLine(to: CGPoint(x: 10, y: 19))
        return path
    }

    private var linkPath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 9, y: 12))
        path.addCurve(to: CGPoint(x: 14.8, y: 12), control1: CGPoint(x: 10.6, y: 13.6), control2: CGPoint(x: 13.2, y: 13.6))
        path.addLine(to: CGPoint(x: 17, y: 9.8))
        path.addCurve(to: CGPoint(x: 12.2, y: 5), control1: CGPoint(x: 19.7, y: 7.1), control2: CGPoint(x: 14.9, y: 2.3))
        path.addLine(to: CGPoint(x: 10.5, y: 6.7))
        path.move(to: CGPoint(x: 11, y: 8))
        path.addCurve(to: CGPoint(x: 5.2, y: 8), control1: CGPoint(x: 9.4, y: 6.4), control2: CGPoint(x: 6.8, y: 6.4))
        path.addLine(to: CGPoint(x: 3, y: 10.2))
        path.addCurve(to: CGPoint(x: 7.8, y: 15), control1: CGPoint(x: 0.3, y: 12.9), control2: CGPoint(x: 5.1, y: 17.7))
        path.addLine(to: CGPoint(x: 9.5, y: 13.3))
        return path
    }

    private var screenshotPath: Path {
        var path = Path()
        path.addRoundedRect(in: CGRect(x: 2, y: 5, width: 16, height: 12), cornerSize: CGSize(width: 2.4, height: 2.4))
        path.addEllipse(in: CGRect(x: 7, y: 9, width: 6, height: 6))
        path.move(to: CGPoint(x: 7, y: 5))
        path.addLine(to: CGPoint(x: 8, y: 3))
        path.addLine(to: CGPoint(x: 12, y: 3))
        path.addLine(to: CGPoint(x: 13, y: 5))
        return path
    }
}
