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

// Seuils température (CPU + GPU) : bleu < 50°C, orange 50-62°C, rouge >= 62°C
fileprivate func temperatureColor(_ temp: Double) -> Color {
    if temp >= 62 { return .red }
    else if temp >= 50 { return .orange }
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

    private var safeMax: Double { maxValue > 0 ? maxValue : 1 }
    private var percent: Double { min(max(value / safeMax, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                    .tracking(0.5)
                Spacer()
                Text("\(String(format: valueFormat, value)) \(unit)")
                    .font(.system(size: compact ? 11 : 12, weight: .bold, design: .rounded))
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
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryText)
                Spacer()
                Text(String(format: "%d%%", Int(percent * 100)))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
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

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 12)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
        }
    }
}

// ---------- CardHeader ----------
fileprivate struct CardHeader: View {
    let icon: String
    let title: String
    let accent: Color
    var iconSize: CGFloat = 11
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
                .font(.system(size: 12, weight: .bold, design: .rounded))
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
                        Image("DEEPCOOL-LOGO")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundColor(secondaryText)
                    }
                    Text("Système")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryText)
                    Text(smbiosModel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }

                HStack(spacing: 5) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryText)
                    Text(String(format: "%.0f GB RAM", ramTotal))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }

                HStack(spacing: 5) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryText)
                    Text(osVersion)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
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
                                gpuTemperature: viewModel.gpuTemperature,
                                gpuFanRPM: viewModel.gpuFanRPM,
                                gpuFanPercent: viewModel.gpuFanPercent
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
                                diskModel: viewModel.diskModel
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 12)

                        HStack(spacing: Layout.sectionSpacing) {
                            NetworkCard(
                                networkUploadSpeed: viewModel.networkUploadSpeed,
                                networkDownloadSpeed: viewModel.networkDownloadSpeed,
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

// ---------- CPUCard ----------
struct CPUCard: View {
    let cpuModel: String
    let cpuCoreCount: Int
    let cpuFrequencyMHz: Double
    let cpuTemp: Double
    let cpuUsagePercent: Double
    let cpuTDP: Double
    let cpuFanRPM: Double
    let chassisFanRPM: Double

    var body: some View {
        let tempColor = temperatureColor(cpuTemp)
        let chargeColor = usageColor(cpuUsagePercent)

        return InfoCard(compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(icon: "cpu", title: "CPU", accent: cpuAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cpuModel)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(primaryText)
                        .lineLimit(1)

                    Text("\(cpuCoreCount) cœurs")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(secondaryText)
                }

                HorizontalGaugeBar(
                    value: cpuUsagePercent,
                    maxValue: 100,
                    unit: "%",
                    label: "Charge",
                    accent: chargeColor,
                    valueFormat: "%.0f",
                    compact: true
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Charge CPU : \(Int(cpuUsagePercent)) pour cent")

                Divider().background(cardBorder)

                VStack(spacing: 5) {
                    StatRow(icon: "bolt.fill", label: "Fréquence",
                            value: String(format: "%.2f GHz", cpuFrequencyMHz / 1000.0),
                            accent: cpuAccent, valueColor: cpuAccent)
                    StatRow(icon: "flame.fill", label: "TDP",
                            value: String(format: "%.0f W", cpuTDP),
                            accent: cpuAccent, valueColor: cpuAccent)
                    StatRow(icon: "thermometer", label: "Température",
                            value: String(format: "%.0f°C", cpuTemp),
                            accent: tempColor, valueColor: tempColor)
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

// ---------- GPUCardSimple ----------
struct GPUCardSimple: View {
    let gpuModel: String
    let gpuVRAM: Double
    let gpuVRAMUsed: Double
    let gpuUsage: Double
    let gpuTemperature: Double
    let gpuFanRPM: Double
    let gpuFanPercent: Double

    var body: some View {
        let tempColor = temperatureColor(gpuTemperature)
        let chargeColor = usageColor(gpuUsage)

        return InfoCard(compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(icon: "square.stack.3d.up.fill", title: "GPU", accent: gpuAccent)

                Text(gpuModel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryText)
                    .lineLimit(1)

                HorizontalGaugeBar(
                    value: gpuUsage,
                    maxValue: 100,
                    unit: "%",
                    label: "Charge",
                    accent: chargeColor,
                    valueFormat: "%.0f",
                    compact: true
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Charge GPU : \(Int(gpuUsage)) pour cent")

                HorizontalGaugeBar(
                    value: gpuVRAMUsed,
                    maxValue: gpuVRAM,
                    unit: String(format: "/ %.1f GB", gpuVRAM),
                    label: "VRAM utilisée",
                    accent: amdRed,
                    valueFormat: "%.1f",
                    compact: true
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: "VRAM utilisée : %.1f sur %.1f gigaoctets", gpuVRAMUsed, gpuVRAM))

                Divider().background(cardBorder)

                VStack(spacing: 5) {
                    StatRow(icon: "thermometer", label: "Température",
                            value: String(format: "%.0f°C", gpuTemperature),
                            accent: tempColor, valueColor: tempColor)
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

                StatRow(icon: "square.stack.3d.up", label: "RAM installée",
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

    var body: some View {
        InfoCard(compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(icon: "internaldrive.fill", title: "Disque", accent: diskAccent)

                Text(diskModel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(secondaryText)
                    .lineLimit(1)

                UsageBarView(used: diskUsed, total: diskTotal, accent: diskAccent)
            }
        }
    }
}

// ---------- NetworkCard ----------
struct NetworkCard: View {
    let networkUploadSpeed: Double
    let networkDownloadSpeed: Double
    let smbiosModel: String
    let ipAddress: String
    let routerAddress: String
    let wifiPhyMode: String
    let wifiChannel: String
    let wifiLinkSpeed: Double
    let wifiSignalDBm: Int

    private var uploadMbps: Double { networkUploadSpeed * 8 / 1_000_000 }
    private var downloadMbps: Double { networkDownloadSpeed * 8 / 1_000_000 }

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

                VStack(spacing: 6) {
                    HorizontalGaugeBar(
                        value: uploadMbps,
                        maxValue: 1000,
                        unit: "Mb/s",
                        label: "Upload",
                        accent: uploadAccent,
                        barHeight: 9,
                        compact: true
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(format: "Upload : %.1f mégabits par seconde", uploadMbps))

                    HorizontalGaugeBar(
                        value: downloadMbps,
                        maxValue: 1000,
                        unit: "Mb/s",
                        label: "Download",
                        accent: downloadAccent,
                        barHeight: 9,
                        compact: true
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(format: "Download : %.1f mégabits par seconde", downloadMbps))
                }

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
