import SwiftUI
import AppKit

// ============================================================
// Palette — inspirée du style "dashboard sombre en verre" de
// l'app Sensei (Cindori) : fond quasi noir, cartes translucides
// à bords fins, jauges circulaires en dégradé, chiffres en gras
// arrondi (SF Rounded) plutôt qu'une police façon écran LCD.
// ============================================================
fileprivate let appBackgroundTop    = Color(red: 0.055, green: 0.06,  blue: 0.085)
fileprivate let appBackgroundBottom = Color(red: 0.02,  green: 0.025, blue: 0.035)
fileprivate let cardBackground      = Color(red: 0.10,  green: 0.105, blue: 0.13)
fileprivate let cardBorder          = Color.white.opacity(0.07)
fileprivate let trackColor          = Color.white.opacity(0.08)
fileprivate let primaryText         = Color.white
fileprivate let secondaryText       = Color.white.opacity(0.55)

// Couleurs d'accent par métrique — chaque carte a sa propre identité,
// comme dans Sensei où CPU/GPU/RAM/Disque/Réseau sont visuellement distincts.
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

// ---------- RingGauge ----------
// Jauge circulaire pleine en dégradé, brique de base réutilisée par
// CircularSemiGauge (CPU) et NeedleGauge (réseau) — remplace les anciens
// styles semi-circulaire à aiguille par un rendu "ring" façon Sensei.
struct RingGauge: View {
    var value: Double // normalisé 0...1
    var colors: [Color]
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: CGFloat(min(max(value, 0), 1)))
                .stroke(
                    AngularGradient(gradient: Gradient(colors: colors),
                                     center: .center,
                                     startAngle: .degrees(-90),
                                     endAngle: .degrees(270)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: value)
        }
    }
}

// ---------- CircularSemiGauge ----------
// Nom conservé pour compatibilité (utilisé par CPUCard), mais rendu en
// ring complet avec chiffre central en gras arrondi.
struct CircularSemiGauge: View {
    var value: Double
    var accent: Color

    var body: some View {
        ZStack {
            RingGauge(value: value, colors: [accent.opacity(0.55), accent], lineWidth: 10)

            VStack(spacing: 2) {
                Text("\(Int(min(max(value, 0), 1) * 100))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
                Text("CHARGE")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(secondaryText)
                    .tracking(0.5)
            }
        }
    }
}

// ---------- NeedleGauge ----------
// Nom conservé pour compatibilité (utilisé par NetworkCard pour Upload/
// Download), mais l'aiguille façon cadran auto a été remplacée par un
// ring gauge avec chiffre + unité, cohérent avec le reste du dashboard.
struct NeedleGauge: View {
    var value: Double
    var maxValue: Double
    var accent: Color
    var label: String
    var labelOffset: CGFloat = 0

    private var safeMax: Double { maxValue > 0 ? maxValue : 1 }
    private var percent: Double { min(max(value / safeMax, 0), 1) }

    var body: some View {
        ZStack {
            RingGauge(value: percent, colors: [accent.opacity(0.55), accent], lineWidth: 9)

            VStack(spacing: 2) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
                Text("MB/s")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryText)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                    .tracking(0.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "%@ : %.2f mégaoctets par seconde", label, value))
    }
}

// ---------- UsageBarView ----------
// Barre de progression en capsule dégradée sur piste sombre translucide.
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

// ---------- StatRow ----------
// Ligne "icône + label + valeur" réutilisée dans plusieurs cartes,
// pour un alignement cohérent façon Sensei (icône teintée, label gris,
// valeur en blanc/accent à droite).
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

// ---------- SystemHeaderCard ----------
// Bandeau tout en haut du dashboard : identité de la machine (modèle SMBIOS)
// et version macOS installée — informations statiques, remontées au-dessus
// de CPU/GPU pour identifier le système d'un coup d'œil.
struct SystemHeaderCard: View {
    let smbiosModel: String
    let osVersion: String

    var body: some View {
        InfoCard(compact: true) {
            HStack(spacing: 20) {
                CardHeader(icon: "desktopcomputer", title: "Système", accent: secondaryText)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "cube.box.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(secondaryText)
                    Text(smbiosModel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }

                HStack(spacing: 6) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 11, weight: .semibold))
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
                        osVersion: viewModel.osVersion
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
                            diskTotal: viewModel.diskTotal
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 18)

                    // --- Network ---
                    HStack(spacing: Layout.sectionSpacing) {
                        NetworkCard(
                            networkUploadSpeed: viewModel.networkUploadSpeed,
                            networkDownloadSpeed: viewModel.networkDownloadSpeed,
                            smbiosModel: viewModel.smbiosModel
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
                .padding(.top, 5)
            }
        }
        .onAppear { viewModel.startUpdates() }
        .onDisappear { viewModel.stopUpdates() }
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

                HStack(spacing: 14) {
                    CircularSemiGauge(value: cpuUsagePercent / 100.0, accent: cpuAccent)
                        .frame(width: 78, height: 78)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Charge CPU : \(Int(cpuUsagePercent)) pour cent")

                    VStack(alignment: .leading, spacing: 6) {
                        Text(cpuModel)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(primaryText)
                            .lineLimit(2)

                        Text("\(cpuCoreCount) cœurs")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(secondaryText)
                    }
                }

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
    let gpuTemperature: Double

    var body: some View {
        let tempColor = temperatureColor(gpuTemperature)

        return InfoCard(compact: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    CardHeader(icon: "square.stack.3d.up.fill", title: "GPU", accent: gpuAccent)
                    Spacer()
                    Image("GPU R")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .opacity(0.9)
                }

                Text(gpuModel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryText)
                    .lineLimit(2)

                Divider().background(cardBorder)

                VStack(spacing: 8) {
                    StatRow(icon: "memorychip", label: "Mémoire vidéo",
                            value: String(format: "%.1f GB", gpuVRAM),
                            accent: amdRed, valueColor: amdRed)
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

    var body: some View {
        InfoCard {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(icon: "internaldrive.fill", title: "Disque", accent: diskAccent)
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

    var body: some View {
        InfoCard {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(icon: "network", title: "Trafic Réseau", accent: uploadAccent)

                HStack(spacing: 24) {
                    Spacer()
                    NeedleGauge(
                        value: networkUploadSpeed / 1_048_576,
                        maxValue: 125,
                        accent: uploadAccent,
                        label: "Upload"
                    )
                    .frame(width: 110, height: 110)

                    NeedleGauge(
                        value: networkDownloadSpeed / 1_048_576,
                        maxValue: 125,
                        accent: downloadAccent,
                        label: "Download"
                    )
                    .frame(width: 110, height: 110)
                    Spacer()
                }
            }
        }
        .frame(minHeight: 160)
    }
}
