import SwiftUI
import AppKit


fileprivate let appBackgroundTop    = Color(red: 0.055, green: 0.06,  blue: 0.085)
fileprivate let appBackgroundBottom = Color(red: 0.02,  green: 0.025, blue: 0.035)
fileprivate let cardBackground      = Color(red: 0.10,  green: 0.105, blue: 0.13)
fileprivate let cardBorder          = Color.white.opacity(0.07)
fileprivate let trackColor          = Color.white.opacity(0.08)
fileprivate let primaryText         = Color.white
fileprivate let secondaryText       = Color.white.opacity(0.55)


fileprivate let cpuAccent     = Color(red: 0.25, green: 0.72, blue: 1.0)   // cyan
fileprivate let gpuAccent     = Color(red: 0.68, green: 0.45, blue: 1.0)   // violet
fileprivate let ramAccent     = Color(red: 0.30, green: 0.86, blue: 0.62)  // vert menthe
fileprivate let diskAccent    = Color(red: 1.0,  green: 0.72, blue: 0.30)  // ambre
fileprivate let uploadAccent  = Color(red: 0.30, green: 0.86, blue: 0.62)  // vert menthe
fileprivate let downloadAccent = Color(red: 1.0, green: 0.55, blue: 0.30)  // orange
fileprivate let amdRed = Color(red: 0.93, green: 0.11, blue: 0.14)          // rouge AMD (ED1C24)

fileprivate func temperatureColor(_ temp: Double) -> Color {
    if temp > 90 { return .red }
    else if temp >= 75 { return .orange }
    else { return ramAccent }
}

// ---------- Constantes de mise en page ----------
fileprivate enum Layout {
    static let sectionSpacing: CGFloat = 16
    static let cardCornerRadius: CGFloat = 20
}

// ---------- InfoCard ----------
// Carte "verre" translucide sombre avec bordure fine et ombre portée douce.
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
                .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)

            content
                .padding(compact ? 14 : 20)
        }
        .padding(.vertical, 4)
    }
}


struct HorizontalGaugeBar: View {
    var value: Double
    var maxValue: Double
    var unit: String
    var label: String
    var accent: Color
    var valueFormat: String = "%.1f"
    var barHeight: CGFloat = 10
    var compact: Bool = false

    private var safeMax: Double { maxValue > 0 ? maxValue : 1 }
    private var percent: Double { min(max(value / safeMax, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                    .tracking(0.5)
                Spacer()
                Text("\(String(format: valueFormat, value)) \(unit)")
                    .font(.system(size: compact ? 12 : 14, weight: .bold, design: .rounded))
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


struct UsageBarView: View {
    let used: Double
    let total: Double
    var accent: Color = ramAccent
    var unit: String = "GB"

    private var safeTotal: Double { total > 0 ? total : 1 }
    private var percent: Double { min(max(used / safeTotal, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .frame(height: 14)

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


fileprivate struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    var accent: Color = secondaryText
    var valueColor: Color = primaryText

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
        }
    }
}

// ---------- CardHeader ----------
fileprivate struct CardHeader: View {
    let icon: String
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(accent.opacity(0.15)).frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accent)
            }
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(primaryText)
        }
    }
}


struct SystemHeaderCard: View {
    let smbiosModel: String
    let osVersion: String
    let ramTotal: Double

    var body: some View {
        InfoCard(compact: true) {
            HStack(spacing: 20) {
                
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(secondaryText.opacity(0.15)).frame(width: 26, height: 26)
                        Image("deepcool-logo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .foregroundColor(secondaryText)
                    }
                    Text("Système")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }

                Spacer()

                // Logo Apple accolé au modèle SMBIOS (identifiant du Mac).
                HStack(spacing: 6) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(secondaryText)
                    Text(smbiosModel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }

                // Quantité de RAM installée.
                HStack(spacing: 6) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(secondaryText)
                    Text(String(format: "%.0f GB RAM", ramTotal))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }

                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(secondaryText)
                    Text(osVersion)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }
            }
        }
        .frame(minHeight: 20)
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

            ScrollView {
                VStack(spacing: Layout.sectionSpacing) {
                    Spacer().frame(height: 8)

                    // --- Système (SMBIOS + macOS) ---
                    SystemHeaderCard(
                        smbiosModel: viewModel.smbiosModel,
                        osVersion: viewModel.osVersion,
                        ramTotal: viewModel.ramTotal
                    )
                    .padding(.horizontal, 18)

                    // --- CPU & GPU ---
                    HStack(alignment: .top, spacing: Layout.sectionSpacing) {
                        CPUCard(
                            cpuModel: viewModel.cpuModel,
                            cpuCoreCount: viewModel.cpuCoreCount,
                            cpuFrequencyMHz: viewModel.cpuFrequency,
                            cpuTemp: viewModel.cpuTemperature,
                            cpuUsagePercent: viewModel.cpuUsage,
                            cpuTDP: viewModel.cpuTDP
                        )
                        .frame(maxWidth: .infinity)

                        GPUCardSimple(
                            gpuModel: viewModel.gpuModel,
                            gpuVRAM: viewModel.gpuVRAM,
                            gpuVRAMUsed: viewModel.gpuVRAMUsed,
                            gpuUsage: viewModel.gpuUsage,
                            gpuTemperature: viewModel.gpuTemperature
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 18)

                    // --- RAM & Disk ---
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
                    .padding(.horizontal, 18)

                    // --- Network ---
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
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
                .padding(.top, 5)
            }
        }
      
        .preferredColorScheme(.dark)
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

    var body: some View {
        let tempColor = temperatureColor(cpuTemp)

        return InfoCard(compact: true) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(icon: "cpu", title: "CPU", accent: cpuAccent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(cpuModel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(primaryText)
                        .lineLimit(2)

                    Text("\(cpuCoreCount) cœurs")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(secondaryText)
                }

                HorizontalGaugeBar(
                    value: cpuUsagePercent,
                    maxValue: 100,
                    unit: "%",
                    label: "Charge",
                    accent: cpuAccent,
                    valueFormat: "%.0f"
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Charge CPU : \(Int(cpuUsagePercent)) pour cent")

                Divider().background(cardBorder)

                VStack(spacing: 8) {
                    StatRow(icon: "bolt.fill", label: "Fréquence",
                            value: String(format: "%.2f GHz", cpuFrequencyMHz / 1000.0),
                            accent: cpuAccent, valueColor: cpuAccent)
                    StatRow(icon: "flame.fill", label: "TDP",
                            value: String(format: "%.0f W", cpuTDP),
                            accent: cpuAccent, valueColor: cpuAccent)
                    StatRow(icon: "thermometer", label: "Température",
                            value: String(format: "%.0f°C", cpuTemp),
                            accent: tempColor, valueColor: tempColor)
                }
            }
        }
        .frame(minHeight: 40)
    }
}

// ---------- GPUCardSimple ----------
struct GPUCardSimple: View {
    let gpuModel: String
    let gpuVRAM: Double
    let gpuVRAMUsed: Double
    let gpuUsage: Double
    let gpuTemperature: Double

    var body: some View {
        let tempColor = temperatureColor(gpuTemperature)
        let usageColor: Color = gpuUsage > 90 ? .red : gpuUsage >= 70 ? .orange : amdRed

        return InfoCard(compact: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    CardHeader(icon: "square.stack.3d.up.fill", title: "GPU", accent: gpuAccent)
                    Spacer()
                    Image("GPU R")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 85, height: 85)
                        .opacity(0.9)
                }

                Text(gpuModel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryText)
                    .lineLimit(2)

                HorizontalGaugeBar(
                    value: gpuUsage,
                    maxValue: 100,
                    unit: "%",
                    label: "Charge",
                    accent: usageColor,
                    valueFormat: "%.0f"
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Charge GPU : \(Int(gpuUsage)) pour cent")

                HorizontalGaugeBar(
                    value: gpuVRAMUsed,
                    maxValue: gpuVRAM,
                    unit: String(format: "/ %.1f GB", gpuVRAM),
                    label: "VRAM utilisée",
                    accent: amdRed,
                    valueFormat: "%.1f"
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: "VRAM utilisée : %.1f sur %.1f gigaoctets", gpuVRAMUsed, gpuVRAM))

                Divider().background(cardBorder)

                VStack(spacing: 8) {
                    StatRow(icon: "thermometer", label: "Température",
                            value: String(format: "%.0f°C", gpuTemperature),
                            accent: tempColor, valueColor: tempColor)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(format: "Température GPU : %.0f degrés", gpuTemperature))
                }
            }
        }
        .frame(minHeight: 40)
    }
}

// ---------- MemoryCard ----------
struct MemoryCard: View {
    let ramUsed: Double
    let ramTotal: Double
    let ramFreqMHz: Double

    var body: some View {
        InfoCard {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(icon: "memorychip.fill", title: "Mémoire", accent: ramAccent)

                UsageBarView(used: ramUsed, total: ramTotal, accent: ramAccent)

                StatRow(icon: "square.stack.3d.up", label: "RAM installée",
                        value: String(format: "%.0f GB / %.0f MHz", ramTotal, ramFreqMHz),
                        accent: ramAccent, valueColor: ramAccent)
            }
        }
        .frame(minHeight: 100)
    }
}

// ---------- DiskCard ----------
struct DiskCard: View {
    let diskUsed: Double
    let diskTotal: Double
    let diskModel: String

    var body: some View {
        InfoCard {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(icon: "internaldrive.fill", title: "Disque", accent: diskAccent)

                Text(diskModel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(secondaryText)
                    .lineLimit(2)

                UsageBarView(used: diskUsed, total: diskTotal, accent: diskAccent)
            }
        }
        .frame(minHeight: 160)
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

 
    var body: some View {
        InfoCard {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(icon: "network", title: "Trafic Réseau", accent: uploadAccent)

                
                VStack(spacing: 10) {
                    HorizontalGaugeBar(
                        value: uploadMbps,
                        maxValue: 1000,
                        unit: "Mb/s",
                        label: "Upload",
                        accent: uploadAccent,
                        barHeight: 10,
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
                        barHeight: 10,
                        compact: true
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(format: "Download : %.1f mégabits par seconde", downloadMbps))
                }

                Divider().background(cardBorder)

                VStack(spacing: 8) {
                    StatRow(icon: "network", label: "Adresse IP",
                            value: ipAddress, accent: secondaryText)
                    StatRow(icon: "point.3.connected.trianglepath.dotted", label: "Routeur",
                            value: routerAddress, accent: secondaryText)

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
        .frame(minHeight: 160)
    }
}
