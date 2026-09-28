import SwiftUI
import AppKit

// ============================================================
// Palette dynamique : s'adapte au mode clair/sombre du système
// ============================================================
fileprivate let appBackgroundTop    = Color(NSColor.windowBackgroundColor)
fileprivate let appBackgroundBottom = Color(NSColor.underPageBackgroundColor)
fileprivate let cardBackground      = Color(NSColor.controlBackgroundColor)
fileprivate let cardBorder          = Color.primary.opacity(0.1)
fileprivate let trackColor          = Color.primary.opacity(0.08)
fileprivate let primaryText         = Color.primary
fileprivate let secondaryText       = Color.secondary

// Couleurs d'accent par métrique
fileprivate let cpuAccent     = Color(red: 0.25, green: 0.72, blue: 1.0)   // cyan
fileprivate let gpuAccent     = Color(red: 0.95, green: 0.20, blue: 0.20)   // rouge
fileprivate let ramAccent     = Color(red: 0.30, green: 0.86, blue: 0.62)  // vert menthe
fileprivate let diskAccent    = Color(red: 1.0,  green: 0.72, blue: 0.30)  // ambre
fileprivate let uploadAccent  = Color(red: 0.30, green: 0.86, blue: 0.62)  // vert menthe
fileprivate let downloadAccent = Color(red: 1.0, green: 0.55, blue: 0.30)  // orange
fileprivate let amdRed = Color(red: 0.93, green: 0.11, blue: 0.14)          // rouge AMD (ED1C24)

// Seuils température (CPU + GPU) : bleu < 63°C, orange 63-71°C, rouge >= 72°C
fileprivate func temperatureColor(_ temp: Double) -> Color {
    if temp >= 72 { return .red }
    else if temp >= 63 { return .orange }
    else { return .blue }
}

// Seuils charge (CPU + GPU) : vert <= 50%, orange 50-85%, rouge 85-100%
fileprivate func usageColor(_ usage: Double) -> Color {
    if usage >= 85 { return .red }
    else if usage > 50 { return .orange }
    else { return .green }
}

// ---------- Constantes de mise en page réduites ----------
fileprivate enum Layout {
    static let sectionSpacing: CGFloat = 10
    static let cardCornerRadius: CGFloat = 14
}

// ---------- InfoCard ----------
struct InfoCard<Content: View>: View {
    let content: Content
    var compact: Bool = false
    init(compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                        .stroke(cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)

            content
                .padding(compact ? 10 : 12)
        }
        .padding(.vertical, 2)
    }
}

// ---------- Police Digital-D (enregistrement automatique) ----------
enum DigitalFont {
    static let postScriptName: String? = {
        guard let url = Bundle.main.url(forResource: "Digital-D", withExtension: "ttf") else {
            return nil
        }
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        guard let provider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(provider),
              let name = cgFont.postScriptName as String? else { return nil }
        return name
    }()

    static func font(size: CGFloat) -> Font {
        if let name = postScriptName {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .bold, design: .rounded)
    }
}

// ---------- HorizontalGaugeBar ----------
struct HorizontalGaugeBar: View {
    var value: Double
    var maxValue: Double
    var unit: String
    var label: String
    var accent: Color
    var valueFormat: String = "%.1f"
    var barHeight: CGFloat = 8
    var compact: Bool = false
    var digitalValue: Bool = false

    private var safeMax: Double { maxValue > 0 ? maxValue : 1 }
    private var percent: Double { min(max(value / safeMax, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                    .tracking(0.5)
                Spacer()
                Text("\(String(format: valueFormat, value)) \(unit)")
                    .font(digitalValue ? DigitalFont.font(size: compact ? 15 : 16)
                                       : .system(size: compact ? 12 : 13, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(trackColor)
                    Capsule()
                        .fill(LinearGradient(colors: [accent.opacity(0.6), accent],
                                              startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(CGFloat(percent) * geo.size.width, 6))
                        .animation(.easeInOut(duration: 0.35), value: percent)
                }
            }
            .frame(height: barHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) : \(String(format: valueFormat, value)) \(unit)")
    }
}

// ---------- CircularGaugeView ----------
struct CircularGaugeView: View {
    var value: Double
    var maxValue: Double
    var label: String
    var accent: Color
    var unit: String = "%"
    var valueFormat: String = "%.0f"
    var size: CGFloat = 64
    var lineWidth: CGFloat = 6

    private var safeMax: Double { maxValue > 0 ? maxValue : 1 }
    private var percent: Double { min(max(value / safeMax, 0), 1) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: percent)
                    .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: percent)
                Text(String(format: valueFormat, value) + unit)
                    .font(DigitalFont.font(size: size * 0.26))
                    .foregroundColor(primaryText)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: size, height: size)

            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(accent)
                .tracking(0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) : \(String(format: valueFormat, value)) \(unit)")
    }
}

// ---------- SegmentedGaugeBar ----------
struct SegmentedGaugeBar: View {
    var value: Double
    var maxValue: Double
    var unit: String
    var label: String
    var accent: Color
    var valueFormat: String = "%.1f"
    var segmentCount: Int = 16
    var barHeight: CGFloat = 9
    var digitalValue: Bool = false

    private var safeMax: Double { maxValue > 0 ? maxValue : 1 }
    private var percent: Double { min(max(value / safeMax, 0), 1) }
    private var filledCount: Int { Int((percent * Double(segmentCount)).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                    .tracking(0.5)
                Spacer()
                Text("\(String(format: valueFormat, value)) \(unit)")
                    .font(digitalValue ? DigitalFont.font(size: 15)
                                       : .system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
            }
            HStack(spacing: 2) {
                ForEach(0..<segmentCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < filledCount ? accent : trackColor)
                        .frame(height: barHeight)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: filledCount)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) : \(String(format: valueFormat, value)) \(unit)")
    }
}

// ---------- MirrorGaugeBarView ----------
struct MirrorGaugeBarView: View {
    var uploadValue: Double
    var uploadMax: Double
    var downloadValue: Double
    var downloadMax: Double
    var unit: String = "Mb/s"
    var valueFormat: String = "%.1f"
    var barHeight: CGFloat = 9
    var labelWidth: CGFloat = 48

    private var uploadPercent: Double { min(max(uploadValue / max(uploadMax, 1), 0), 1) }
    private var downloadPercent: Double { min(max(downloadValue / max(downloadMax, 1), 0), 1) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(String(format: valueFormat, uploadValue))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(uploadAccent)
                    .frame(width: labelWidth, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                GeometryReader { geo in
                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: barHeight / 2)
                            .fill(trackColor)
                        RoundedRectangle(cornerRadius: barHeight / 2)
                            .fill(uploadAccent)
                            .frame(width: max(geo.size.width * uploadPercent, uploadPercent > 0 ? barHeight : 0))
                            .animation(.easeInOut(duration: 0.3), value: uploadPercent)
                    }
                }
                .frame(height: barHeight)

                Text("↑")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(uploadAccent)
            }

            HStack(alignment: .center, spacing: 8) {
                Text("↓")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(downloadAccent)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: barHeight / 2)
                            .fill(trackColor)
                        RoundedRectangle(cornerRadius: barHeight / 2)
                            .fill(downloadAccent)
                            .frame(width: max(geo.size.width * downloadPercent, downloadPercent > 0 ? barHeight : 0))
                            .animation(.easeInOut(duration: 0.3), value: downloadPercent)
                    }
                }
                .frame(height: barHeight)

                Text(String(format: valueFormat, downloadValue))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(downloadAccent)
                    .frame(width: labelWidth, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(unit)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: "Upload : %.1f, Download : %.1f \(unit)",
            uploadValue, downloadValue
        ))
    }
}

// ---------- Interpolation de couleur ----------
extension Color {
    func interpolated(to other: Color, fraction: Double) -> Color {
        let f = min(max(fraction, 0), 1)
        let c1 = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        let c2 = NSColor(other).usingColorSpace(.deviceRGB) ?? NSColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: Double(r1 + (r2 - r1) * f),
                     green: Double(g1 + (g2 - g1) * f),
                     blue: Double(b1 + (b2 - b1) * f))
    }
}

// ---------- SpeedBadgeRow ----------
struct SpeedBadgeRow: View {
    var icon: String
    var label: String
    var value: Double
    var unit: String
    var accent: Color
    var valueFormat: String = "%.2f"

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(accent, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(secondaryText)
                    .tracking(0.5)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: valueFormat, value))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                    Text(unit)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(secondaryText)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) : \(String(format: valueFormat, value)) \(unit)")
    }
}

// ---------- SpeedGaugeDialView ----------
struct SpeedGaugeDialView: View {
    var value: Double
    var maxValue: Double
    var size: CGFloat = 150
    var gradientColors: [Color] = [
        Color(red: 0.30, green: 0.86, blue: 0.62),
        Color(red: 1.0,  green: 0.72, blue: 0.30),
        Color(red: 0.95, green: 0.20, blue: 0.20)
    ]

    private let startAngle: Double = 135
    private let endAngle: Double = 405
    private var sweep: Double { endAngle - startAngle }
    private let arcFillRatio: Double = 0.965

    private var safeMax: Double { maxValue > 0 ? maxValue : 1 }
    private var percent: Double { min(max(value / safeMax, 0), 1) }
    private var needleAngle: Double { startAngle + sweep * percent }
    private var needleColor: Color {
        guard gradientColors.count > 1 else { return gradientColors.first ?? primaryText }
        let segments = gradientColors.count - 1
        let scaled = percent * Double(segments)
        let index = min(max(Int(scaled), 0), segments - 1)
        let localFraction = scaled - Double(index)
        return gradientColors[index].interpolated(to: gradientColors[index + 1], fraction: localFraction)
    }

    private var tickValues: [Double] {
        let step = safeMax / 8
        return stride(from: 0.0, through: safeMax + 1, by: step).map { $0 }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.95, green: 0.20, blue: 0.20).opacity(0.22), .clear],
                                      center: .center, startRadius: 0, endRadius: size * 0.5))
                .blur(radius: 16)

            Circle()
                .trim(from: 0, to: sweep / 360)
                .stroke(trackColor, style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round))
                .rotationEffect(.degrees(startAngle))

            Circle()
                .trim(from: 0, to: (sweep / 360) * arcFillRatio)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: gradientColors), center: .center,
                                     startAngle: .degrees(0), endAngle: .degrees(sweep)),
                    style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round)
                )
                .rotationEffect(.degrees(startAngle))

            ForEach(Array(tickValues.enumerated()), id: \.offset) { _, tick in
                let t = min(max(tick / safeMax, 0), 1)
                let angle = (startAngle + sweep * t) * .pi / 180
                Text(tick >= 1000 ? String(format: "%.1fK", tick / 1000) : String(format: "%.0f", tick))
                    .font(.system(size: size * 0.062, weight: .regular, design: .rounded))
                    .foregroundColor(secondaryText.opacity(0.75))
                    .position(
                        x: size / 2 + cos(angle) * size * 0.37,
                        y: size / 2 + sin(angle) * size * 0.37
                    )
            }

            Circle()
                .fill(RadialGradient(colors: [needleColor.opacity(0.55), .clear],
                                      center: .center, startRadius: 0, endRadius: size * 0.18))
                .frame(width: size * 0.36, height: size * 0.36)
                .blur(radius: 8)

            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [needleColor.opacity(0.35), needleColor],
                                      startPoint: .top, endPoint: .bottom))
                .frame(width: 5, height: size * 0.30)
                .offset(y: -size * 0.15)
                .rotationEffect(.degrees(needleAngle + 90))
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: needleAngle)

            Circle()
                .fill(cardBackground)
                .frame(width: size * 0.22, height: size * 0.22)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// ---------- SparklineGaugeView ----------
struct SparklineGaugeView: View {
    var history: [Double]
    var currentValue: Double
    var unit: String
    var label: String
    var accent: Color
    var valueFormat: String = "%.1f"
    var height: CGFloat = 28

    private var points: [Double] { history.isEmpty ? [currentValue] : history }
    private var maxPoint: Double { max(points.max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                    .tracking(0.5)
                Spacer()
                Text("\(String(format: valueFormat, currentValue)) \(unit)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
            }

            GeometryReader { geo in
                let stepX = points.count > 1 ? geo.size.width / CGFloat(points.count - 1) : 0
                ZStack(alignment: .bottomLeading) {
                    Path { path in
                        for (index, value) in points.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = geo.size.height * (1 - CGFloat(value / maxPoint))
                            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    Path { path in
                        for (index, value) in points.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = geo.size.height * (1 - CGFloat(value / maxPoint))
                            if index == 0 { path.move(to: CGPoint(x: x, y: geo.size.height)) }
                            path.addLine(to: CGPoint(x: x, y: y))
                            if index == points.count - 1 { path.addLine(to: CGPoint(x: x, y: geo.size.height)) }
                        }
                        path.closeSubpath()
                    }
                    .fill(accent.opacity(0.12))
                }
                .animation(.easeInOut(duration: 0.3), value: points)
            }
            .frame(height: height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) : \(String(format: valueFormat, currentValue)) \(unit)")
    }
}

// ---------- UsageBarView ----------
struct UsageBarView: View {
    let used: Double
    let total: Double
    var accent: Color = ramAccent
    var unit: String = "GB"

    private var safeTotal: Double { total > 0 ? total : 1 }
    private var percent: Double { min(max(used / safeTotal, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(trackColor)
                    Capsule()
                        .fill(LinearGradient(colors: [accent.opacity(0.6), accent],
                                              startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(CGFloat(percent) * geo.size.width, 6))
                        .animation(.easeInOut(duration: 0.4), value: percent)
                }
            }
            .frame(height: 10)

            HStack {
                Text(String(format: "%.2f / %.2f \(unit)", used, total))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryText)
                Spacer()
                Text(String(format: "%d%%", Int(percent * 100)))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: "Utilisation : %d pour cent, %.2f sur %.2f %@",
                   Int(percent * 100), used, total, unit)
        )
    }
}

// ---------- StatRow ----------
fileprivate struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    var accent: Color = secondaryText
    var valueColor: Color = primaryText
    var digitalValue: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 12)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(secondaryText)
            Spacer()
            Text(value)
                .font(digitalValue ? DigitalFont.font(size: 15)
                                   : .system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
        }
    }
}

// ---------- CardHeader ----------
fileprivate struct CardHeader: View {
    let icon: String
    let title: String
    let accent: Color
    var iconSize: CGFloat = 12
    var circleSize: CGFloat = 22

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(accent.opacity(0.15)).frame(width: circleSize, height: circleSize)
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(accent)
            }
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(primaryText)
        }
    }
}

// ---------- SystemHeaderCard ----------
struct SystemHeaderCard: View {
    let smbiosModel: String
    let osVersion: String
    let ramTotal: Double

    var body: some View {
        InfoCard(compact: true) {
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(secondaryText.opacity(0.15)).frame(width: 22, height: 22)
                        Image(systemName: "apple.logo")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(secondaryText)
                    }
                    Text("Système")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "macpro.gen3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(secondaryText)
                    Text(smbiosModel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }

                HStack(spacing: 5) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(secondaryText)
                    Text(String(format: "%.0f GB RAM", ramTotal))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }

                HStack(spacing: 5) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(secondaryText)
                    Text(osVersion)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }
            }
        }
    }
}

// ---------- ContentView ----------
struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel

    init(viewModel: ContentViewModel = ContentViewModel()) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [appBackgroundTop, appBackgroundBottom],
                            startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Layout.sectionSpacing) {
                        Spacer().frame(height: 4)

                        SystemHeaderCard(
                            smbiosModel: viewModel.smbiosModel,
                            osVersion: viewModel.osVersion,
                            ramTotal: viewModel.ramTotal
                        )
                        .padding(.horizontal, 12)

                        HStack(alignment: .top, spacing: Layout.sectionSpacing) {
                            CPUCard(
                                cpuModel: viewModel.cpuModel,
                                cpuCoreCount: viewModel.cpuCoreCount,
                                cpuFrequencyMHz: viewModel.cpuFrequency,
                                cpuTemp: viewModel.cpuTemperature,
                                cpuUsagePercent: viewModel.cpuUsage,
                                cpuUsageHistory: viewModel.cpuUsageHistory,
                                cpuTDP: viewModel.cpuTDP,
                                cpuFanRPM: viewModel.cpuFanRPM,
                                chassisFanRPM: viewModel.chassisFanRPM
                            )
                            .frame(maxWidth: .infinity)

                            GPUCardSimple(
                                gpuModel: viewModel.gpuModel,
                                gpuVRAM: viewModel.gpuVRAM,
                                gpuVRAMUsed: viewModel.gpuVRAMUsed,
                                gpuUsage: viewModel.gpuUsage,
                                gpuUsageHistory: viewModel.gpuUsageHistory,
                                gpuTemperature: viewModel.gpuTemperature,
                                gpuFanRPM: viewModel.gpuFanRPM,
                                gpuFanPercent: viewModel.gpuFanPercent,
                                gpuFrequency: viewModel.gpuFrequency,
                                gpuTDP: viewModel.gpuTDP
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 12)

                        HStack(alignment: .top, spacing: Layout.sectionSpacing) {
                            MemoryCard(
                                ramUsed: viewModel.ramUsed,
                                ramTotal: viewModel.ramTotal,
                                ramFreqMHz: viewModel.ramFrequency
                            )
                            .frame(maxWidth: .infinity)

                            DiskCard(
                                diskUsed: viewModel.diskUsed,
                                diskTotal: viewModel.diskTotal,
                                diskModel: viewModel.diskModel,
                                diskTemperature: viewModel.diskTemperature
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 12)

                        HStack(spacing: Layout.sectionSpacing) {
                            NetworkCard(
                                networkUploadSpeed: viewModel.networkUploadSpeed,
                                networkDownloadSpeed: viewModel.networkDownloadSpeed,
                                networkUploadHistory: viewModel.networkUploadHistory,
                                networkDownloadHistory: viewModel.networkDownloadHistory,
                                smbiosModel: viewModel.smbiosModel,
                                ipAddress: viewModel.ipAddress,
                                routerAddress: viewModel.routerAddress,
                                wifiPhyMode: viewModel.wifiPhyMode,
                                wifiChannel: viewModel.wifiChannel,
                                wifiLinkSpeed: viewModel.wifiLinkSpeed,
                                wifiSignalDBm: viewModel.wifiSignalDBm
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                    }
                    .padding(.top, 2)
                }

                // Section fixe tout en bas
                HStack {
                    Spacer()
                    Image("DC3-Cropped")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 22)
                        .opacity(0.85)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(cardBackground.opacity(0.1))
            }
        }
    }
}

// ---------- DotMatrixHistoryView ----------
struct DotMatrixHistoryView: View {
    var history: [Double]
    var accent: Color
    var maxColumns: Int = 26
    var rows: Int = 8
    var dotSize: CGFloat = 3.5
    var spacing: CGFloat = 2.5

    private var paddedHistory: [Double] {
        let clipped = Array(history.suffix(maxColumns))
        let padCount = max(maxColumns - clipped.count, 0)
        return Array(repeating: -1, count: padCount) + clipped
    }

    private func filledRows(for value: Double) -> Int {
        guard value >= 0 else { return 0 }
        return Int((value / 100.0 * Double(rows)).rounded(.up))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Array(paddedHistory.enumerated()), id: \.offset) { _, value in
                VStack(spacing: spacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        let filled = (rows - 1 - row) < filledRows(for: value)
                        Circle()
                            .fill(filled ? accent : trackColor)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// ---------- ThermometerIcon ----------
struct ThermometerIcon: View {
    var color: Color
    var size: CGFloat = 14

    var body: some View {
        Image(systemName: "thermometer.medium")
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
    }
}

// ---------- LCDTemperatureDisplay (Position remontée) ----------
struct LCDTemperatureDisplay: View {
    var temperature: Double
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            ThermometerIcon(color: color, size: 20)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text(String(format: "%.0f°", temperature))
                .font(DigitalFont.font(size: 30))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.8), radius: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minWidth: 85)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.09, green: 0.095, blue: 0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorder, lineWidth: 1)
        )
        .offset(y: -8) // Monte la position du LCD légèrement
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "Température : %.0f degrés", temperature))
    }
}

// ---------- CPUCard (Positions et alignements ajustés) ----------
struct CPUCard: View {
    let cpuModel: String
    let cpuCoreCount: Int
    let cpuFrequencyMHz: Double
    let cpuTemp: Double
    let cpuUsagePercent: Double
    let cpuUsageHistory: [Double]
    let cpuTDP: Double
    let cpuFanRPM: Double
    let chassisFanRPM: Double

    var body: some View {
        let tempColor = temperatureColor(cpuTemp)
        let chargeColor = usageColor(cpuUsagePercent)

        return InfoCard(compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(cpuAccent.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(cpuAccent)
                    }
                    Text(cpuModel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(cpuAccent)
                    Text("Cœurs : \(cpuCoreCount)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(secondaryText)
                }

                HStack(alignment: .center, spacing: 8) {
                    CircularGaugeView(
                        value: cpuUsagePercent,
                        maxValue: 100,
                        label: "Charge",
                        accent: chargeColor,
                        size: 66,
                        lineWidth: 6
                    )

                    Spacer(minLength: 0)

                    LCDTemperatureDisplay(temperature: cpuTemp, color: tempColor)

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        DotMatrixHistoryView(history: cpuUsageHistory, accent: chargeColor)
                        Text("\(Int(cpuUsagePercent.rounded()))%")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(primaryText)
                    }
                }

                Divider().background(cardBorder)

                VStack(spacing: 5) {
                    StatRow(icon: "waveform.path.ecg", label: "Fréquence",
                            value: String(format: "%.2f GHz", cpuFrequencyMHz / 1000.0),
                            accent: cpuAccent, valueColor: cpuAccent, digitalValue: true)
                    StatRow(icon: "bolt.fill", label: "TDP",
                            value: String(format: "%.0f W", cpuTDP),
                            accent: cpuAccent, valueColor: cpuAccent, digitalValue: true)
                    StatRow(icon: "thermometer", label: "Température",
                            value: String(format: "%.0f°C", cpuTemp),
                            accent: tempColor, valueColor: tempColor, digitalValue: true)
                    StatRow(icon: "wind", label: "Ventilateur CPU",
                            value: cpuFanRPM > 0 ? String(format: "%.0f RPM", cpuFanRPM) : "N/A",
                            accent: cpuAccent, valueColor: cpuAccent)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(format: "Ventilateur CPU : %.0f tours par minute", cpuFanRPM))
                    StatRow(icon: "wind", label: "Ventilateur boîtier",
                            value: chassisFanRPM > 0 ? String(format: "%.0f RPM", chassisFanRPM) : "N/A",
                            accent: cpuAccent, valueColor: cpuAccent)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(format: "Ventilateur boîtier : %.0f tours par minute", chassisFanRPM))
                }
            }
        }
    }
}

// ---------- GPUCardSimple (Alignement strict avec CPUCard) ----------
struct GPUCardSimple: View {
    let gpuModel: String
    let gpuVRAM: Double
    let gpuVRAMUsed: Double
    let gpuUsage: Double
    let gpuUsageHistory: [Double]
    let gpuTemperature: Double
    let gpuFanRPM: Double
    let gpuFanPercent: Double
    let gpuFrequency: Double
    let gpuTDP: Double

    var body: some View {
        let tempColor = temperatureColor(gpuTemperature)
        let chargeColor = usageColor(gpuUsage)

        return InfoCard(compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(gpuAccent.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(gpuAccent)
                    }
                    Text(gpuModel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                HorizontalGaugeBar(
                    value: gpuVRAMUsed,
                    maxValue: gpuVRAM,
                    unit: String(format: "/ %.1f GB", gpuVRAM),
                    label: "VRAM",
                    accent: gpuAccent,
                    valueFormat: "%.1f",
                    compact: true
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: "VRAM utilisée : %.1f sur %.1f gigaoctets", gpuVRAMUsed, gpuVRAM))

                HStack(alignment: .center, spacing: 8) {
                    CircularGaugeView(
                        value: gpuUsage,
                        maxValue: 100,
                        label: "Charge",
                        accent: chargeColor,
                        size: 66,
                        lineWidth: 6
                    )

                    Spacer(minLength: 0)

                    LCDTemperatureDisplay(temperature: gpuTemperature, color: tempColor)

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        DotMatrixHistoryView(history: gpuUsageHistory, accent: chargeColor)
                        Text("\(Int(gpuUsage.rounded()))%")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(primaryText)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Charge GPU : \(Int(gpuUsage)) pour cent")

                Divider().background(cardBorder)

                VStack(spacing: 5) {
                    StatRow(icon: "waveform.path.ecg", label: "Fréquence GPU",
                            value: gpuFrequency > 0 ? String(format: "%.0f MHz", gpuFrequency) : "N/A",
                            accent: gpuAccent, valueColor: gpuAccent, digitalValue: true)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(format: "Fréquence GPU : %.0f mégahertz", gpuFrequency))
                    StatRow(icon: "bolt.fill", label: "TDP GPU",
                            value: gpuTDP > 0 ? String(format: "%.0f W", gpuTDP) : "N/A",
                            accent: gpuAccent, valueColor: gpuAccent, digitalValue: true)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(format: "TDP GPU : %.0f watts", gpuTDP))
                    StatRow(icon: "thermometer", label: "Température",
                            value: String(format: "%.0f°C", gpuTemperature),
                            accent: tempColor, valueColor: tempColor, digitalValue: true)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(format: "Température GPU : %.0f degrés", gpuTemperature))
                    StatRow(icon: "wind", label: "Ventilateur GPU",
                            value: gpuFanRPM > 0 ? String(format: "%.0f RPM", gpuFanRPM) : "N/A",
                            accent: gpuAccent, valueColor: gpuAccent)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(format: "Ventilateur GPU : %.0f tours par minute", gpuFanRPM))
                    StatRow(icon: "gauge.medium", label: "Vitesse ventilateur",
                            value: gpuFanPercent > 0 ? String(format: "%.0f %%", gpuFanPercent) : "N/A",
                            accent: gpuAccent, valueColor: gpuAccent)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(format: "Vitesse du ventilateur GPU : %.0f pour cent", gpuFanPercent))
                }
            }
        }
    }
}

// ---------- MemoryCard ----------
struct MemoryCard: View {
    let ramUsed: Double
    let ramTotal: Double
    let ramFreqMHz: Double

    var body: some View {
        InfoCard(compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(icon: "memorychip.fill", title: "Mémoire", accent: ramAccent)

                UsageBarView(used: ramUsed, total: ramTotal, accent: ramAccent)

                StatRow(icon: "memorychip", label: "RAM installée",
                        value: String(format: "%.0f GB / %.0f MHz", ramTotal, ramFreqMHz),
                        accent: ramAccent, valueColor: ramAccent)
            }
        }
    }
}

// ---------- DiskCard ----------
struct DiskCard: View {
    let diskUsed: Double
    let diskTotal: Double
    let diskModel: String
    let diskTemperature: Double

    var body: some View {
        InfoCard(compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(icon: "internaldrive.fill", title: "Disque", accent: diskAccent)

                Text(diskModel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(secondaryText)
                    .lineLimit(1)

                UsageBarView(used: diskUsed, total: diskTotal, accent: diskAccent)

                let diskTempColor = diskTemperature > 0 ? temperatureColor(diskTemperature) : secondaryText
                StatRow(icon: "thermometer", label: "Température",
                        value: diskTemperature > 0 ? String(format: "%.0f°C", diskTemperature) : "N/A",
                        accent: diskTempColor, valueColor: diskTempColor, digitalValue: true)
                    .accessibilityLabel(diskTemperature > 0
                        ? String(format: "Température disque : %.0f degrés", diskTemperature)
                        : "Température disque indisponible")
            }
        }
    }
}

// ---------- NetworkCard ----------
struct NetworkCard: View {
    let networkUploadSpeed: Double
    let networkDownloadSpeed: Double
    let networkUploadHistory: [Double]
    let networkDownloadHistory: [Double]
    let smbiosModel: String
    let ipAddress: String
    let routerAddress: String
    let wifiPhyMode: String
    let wifiChannel: String
    let wifiLinkSpeed: Double
    let wifiSignalDBm: Int

    private var uploadMbps: Double { networkUploadSpeed * 8 / 1_000_000 }
    private var downloadMbps: Double { networkDownloadSpeed * 8 / 1_000_000 }
    private var uploadHistoryMbps: [Double] { networkUploadHistory.map { $0 * 8 / 1_000_000 } }
    private var downloadHistoryMbps: [Double] { networkDownloadHistory.map { $0 * 8 / 1_000_000 } }

    private var signalQuality: String {
        switch wifiSignalDBm {
        case let v where v >= -50: return "Excellent"
        case let v where v >= -60: return "Bon"
        case let v where v >= -70: return "Correct"
        case let v where v >= -80: return "Faible"
        default:                   return "Très faible"
        }
    }

    private var signalColor: Color {
        switch wifiSignalDBm {
        case let v where v >= -60: return .green
        case let v where v >= -75: return .orange
        default:                   return .red
        }
    }

    var body: some View {
        InfoCard(compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(icon: "network", title: "Trafic Réseau", accent: uploadAccent)

                HStack(alignment: .top, spacing: 24) {
                    Spacer(minLength: 0)
                    VStack(spacing: 10) {
                        SpeedGaugeDialView(value: downloadMbps, maxValue: 1000, size: 120)
                        SpeedBadgeRow(icon: "arrow.down", label: "Download",
                                      value: downloadMbps, unit: "Mb/s", accent: downloadAccent)
                    }
                    VStack(spacing: 10) {
                        SpeedGaugeDialView(value: uploadMbps, maxValue: 1000, size: 120)
                        SpeedBadgeRow(icon: "arrow.up", label: "Upload",
                                      value: uploadMbps, unit: "Mb/s", accent: uploadAccent)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)

                Divider().background(cardBorder)

                VStack(spacing: 5) {
                    StatRow(icon: "network", label: "Adresse IP",
                            value: ipAddress, accent: secondaryText)
                    StatRow(icon: "point.3.connected.trianglepath.dotted", label: "Routeur",
                            value: routerAddress, accent: secondaryText)
                    if wifiSignalDBm != 0 {
                        StatRow(icon: "wifi", label: "Signal Wi-Fi",
                                value: "\(wifiSignalDBm) dBm (\(signalQuality))",
                                accent: signalColor, valueColor: signalColor)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Signal Wi-Fi : \(wifiSignalDBm) dBm, \(signalQuality)")
                    }
                    StatRow(icon: "antenna.radiowaves.left.and.right", label: "Mode PHY",
                            value: wifiPhyMode, accent: secondaryText)
                    StatRow(icon: "number", label: "Canal",
                            value: wifiChannel, accent: secondaryText)
                    StatRow(icon: "speedometer", label: "Vitesse liaison",
                            value: wifiLinkSpeed > 0 ? String(format: "%.0f Mb/s", wifiLinkSpeed) : "N/A",
                            accent: secondaryText)
                }
            }
        }
    }
}
