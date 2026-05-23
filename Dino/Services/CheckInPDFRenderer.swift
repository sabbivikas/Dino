//
//  CheckInPDFRenderer.swift
//  Dino
//

import UIKit

enum CheckInPDFRenderer {
    /// Render the weekly check-in result to a PDF in Documents/.
    /// Returns the file URL.
    @discardableResult
    static func render(result: WeeklyCheckInResult, userName: String) throws -> URL {
        let pageW: CGFloat = 595
        let pageH: CGFloat = 842
        let pageRect = CGRect(x: 0, y: 0, width: pageW, height: pageH)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent("weekly-report-w\(result.weekNumber)-\(result.year).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        try renderer.writePDF(to: fileURL) { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext

            // Background cream
            cg.setFillColor(UIColor(red: 0xFA/255, green: 0xF6/255, blue: 0xEC/255, alpha: 1).cgColor)
            cg.fill(pageRect)

            var y: CGFloat = 48
            let leftMargin: CGFloat = 48
            let contentWidth = pageW - leftMargin * 2

            // Header
            drawText("dino initiative",
                     at: CGPoint(x: leftMargin, y: y),
                     font: .systemFont(ofSize: 12, weight: .medium),
                     color: muted())
            y += 22
            drawText("weekly wellness report",
                     at: CGPoint(x: leftMargin, y: y),
                     font: .systemFont(ofSize: 26, weight: .bold),
                     color: ink())
            y += 36
            let nameLine = userName.isEmpty ? "for you" : "for \(userName)"
            drawText(nameLine,
                     at: CGPoint(x: leftMargin, y: y),
                     font: .systemFont(ofSize: 13, weight: .regular),
                     color: ink())
            y += 18
            drawText("week \(result.weekNumber) · \(result.dateRange)",
                     at: CGPoint(x: leftMargin, y: y),
                     font: .systemFont(ofSize: 12, weight: .regular),
                     color: muted())
            y += 30

            // Divider
            cg.setStrokeColor(divider().cgColor)
            cg.setLineWidth(0.5)
            cg.move(to: CGPoint(x: leftMargin, y: y))
            cg.addLine(to: CGPoint(x: pageW - leftMargin, y: y))
            cg.strokePath()
            y += 24

            // Scores row
            let scoreColumns: [(String, Int)] = [
                ("overall", result.report.overallScore),
                ("mood & energy", result.report.moodEnergyScore),
                ("anxiety & stress", result.report.anxietyStressScore),
                ("well-being", result.report.wellbeingScore)
            ]
            let colWidth = contentWidth / CGFloat(scoreColumns.count)
            for (i, (label, score)) in scoreColumns.enumerated() {
                let cx = leftMargin + CGFloat(i) * colWidth + colWidth / 2
                drawCircleScore(cg: cg, center: CGPoint(x: cx, y: y + 38), score: score)
                drawCenteredText(label,
                                 at: CGPoint(x: cx, y: y + 84),
                                 font: .systemFont(ofSize: 11, weight: .medium),
                                 color: ink())
            }
            y += 116

            // Overall label
            let labelLine = "\(result.report.overallEmoji) \(result.report.overallLabel)"
            drawText(labelLine,
                     at: CGPoint(x: leftMargin, y: y),
                     font: .systemFont(ofSize: 16, weight: .semibold),
                     color: ink())
            y += 28

            // Reflection
            drawText("this week's reflection",
                     at: CGPoint(x: leftMargin, y: y),
                     font: .systemFont(ofSize: 13, weight: .semibold),
                     color: ink())
            y += 18
            y = drawWrappedText(result.report.weeklyReflection,
                                in: CGRect(x: leftMargin, y: y, width: contentWidth, height: 200),
                                font: .systemFont(ofSize: 12),
                                color: ink())
            y += 18

            // Trend
            drawText("trend: \(result.report.trend) — \(result.report.trendNote)",
                     at: CGPoint(x: leftMargin, y: y),
                     font: .systemFont(ofSize: 12, weight: .regular),
                     color: muted())
            y += 28

            // Insights
            let insights: [(String, String)] = [
                ("mood & energy", result.report.moodEnergyInsight),
                ("anxiety & stress", result.report.anxietyStressInsight),
                ("well-being", result.report.wellbeingInsight)
            ]
            for (title, body) in insights {
                if y > pageH - 120 { ctx.beginPage(); y = 48 }
                drawText(title,
                         at: CGPoint(x: leftMargin, y: y),
                         font: .systemFont(ofSize: 12, weight: .semibold),
                         color: ink())
                y += 16
                y = drawWrappedText(body,
                                    in: CGRect(x: leftMargin, y: y, width: contentWidth, height: 160),
                                    font: .systemFont(ofSize: 11),
                                    color: ink())
                y += 14
            }

            // Q&A
            if y > pageH - 160 { ctx.beginPage(); y = 48 }
            y += 12
            drawText("your answers",
                     at: CGPoint(x: leftMargin, y: y),
                     font: .systemFont(ofSize: 13, weight: .semibold),
                     color: ink())
            y += 18
            for (i, q) in result.questions.enumerated() {
                if y > pageH - 80 { ctx.beginPage(); y = 48 }
                let raw = result.answers.indices.contains(i) ? result.answers[i] : 0
                let opt = AnswerOption(rawValue: raw) ?? .notAtAll
                let line = "\(i + 1). \(q) — \(opt.label)"
                y = drawWrappedText(line,
                                    in: CGRect(x: leftMargin, y: y, width: contentWidth, height: 60),
                                    font: .systemFont(ofSize: 10),
                                    color: ink())
                y += 4
            }

            // Footer
            if y > pageH - 80 { ctx.beginPage(); y = pageH - 80 }
            let footer = "this is a personal reflection tool and not a medical diagnosis. please consult a professional for clinical concerns."
            _ = drawWrappedText(footer,
                                in: CGRect(x: leftMargin, y: pageH - 60, width: contentWidth, height: 50),
                                font: .italicSystemFont(ofSize: 9),
                                color: muted())
        }

        // Backup + protection (best-effort, ignore failures).
        var url = fileURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path
        )
        return fileURL
    }

    // MARK: - Drawing helpers

    private static func ink() -> UIColor {
        UIColor(red: 0x2E/255, green: 0x2A/255, blue: 0x24/255, alpha: 1)
    }
    private static func muted() -> UIColor {
        UIColor(red: 0x7A/255, green: 0x72/255, blue: 0x66/255, alpha: 1)
    }
    private static func divider() -> UIColor {
        UIColor(red: 0xE5/255, green: 0xDE/255, blue: 0xCC/255, alpha: 1)
    }

    private static func scoreColor(_ score: Int) -> UIColor {
        switch score {
        case 70...:  return UIColor(red: 0xA8/255, green: 0xC5/255, blue: 0xA0/255, alpha: 1) // sage
        case 40...:  return UIColor(red: 0xF5/255, green: 0xC8/255, blue: 0x42/255, alpha: 1) // amber
        default:     return UIColor(red: 0xE8/255, green: 0x64/255, blue: 0x5A/255, alpha: 1) // soft red
        }
    }

    private static func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    private static func drawCenteredText(_ text: String, at center: CGPoint, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attrs)
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        (text as NSString).draw(at: origin, withAttributes: attrs)
    }

    @discardableResult
    private static func drawWrappedText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let bounding = attributed.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                               options: [.usesLineFragmentOrigin, .usesFontLeading],
                                               context: nil)
        attributed.draw(with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: bounding.height),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil)
        return rect.minY + bounding.height
    }

    private static func drawCircleScore(cg: CGContext, center: CGPoint, score: Int) {
        let radius: CGFloat = 28
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        // background ring
        cg.setStrokeColor(divider().cgColor)
        cg.setLineWidth(4)
        cg.strokeEllipse(in: rect)

        // arc
        let progress = max(0, min(1, CGFloat(score) / 100))
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        cg.rotate(by: -.pi / 2)
        cg.setStrokeColor(scoreColor(score).cgColor)
        cg.setLineWidth(4)
        cg.setLineCap(.round)
        cg.addArc(center: .zero, radius: radius, startAngle: 0, endAngle: .pi * 2 * progress, clockwise: false)
        cg.strokePath()
        cg.restoreGState()

        // number
        drawCenteredText("\(score)",
                         at: center,
                         font: .systemFont(ofSize: 14, weight: .semibold),
                         color: ink())
    }
}
