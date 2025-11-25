
//
// ContentView.swift
// DeepCoolStyleDashboard - version finale (adaptatif mode clair/sombre)
//

import SwiftUI
import AppKit

fileprivate let deepTeal = Color(red: 0.031, green: 0.659, blue: 0.54)

fileprivate func temperatureColor(_ temp: Double) -> Color {
    if temp > 75 { return .red }
    else if temp >= 65 { return .orange }
    else { return deepTeal }
}

// ---------- InfoCard sans transparence ----------
struct InfoCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            // Fond opaque
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor).opacity(0.25), lineWidth: 1)
                )

            content
                .padding(18)
        }
        .padding(.vertical, 4)
    }
}

// ---------- ContentView ----------
struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel

    init(viewModel: ContentViewModel = ContentViewModel()) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 72)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(Rectangle().frame(width: 1)
                            .foregroundColor(Color(NSColor.separatorColor).opacity(0.3)), alignment: .trailing)

            ZStack {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        Spacer().frame(height: 12)

                        // --- CPU & GPU ---
                        HStack(spacing: 18) {
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
                                gpuVRAM: viewModel.gpuVRAM
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 18)

                        // --- RAM & Disk ---
                        HStack(spacing: 18) {
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
                        HStack(spacing: 18) {
                            NetworkCard(
                                networkUploadSpeed: viewModel.networkUploadSpeed,
                                networkDownloadSpeed: viewModel.networkDownloadSpeed
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 28)

                        // --- Logo ---
                        HStack {
                            Spacer()
                            Image("Deepcool-logo-black")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 80)
                                .padding(.trailing, 4)
                        }
                        .padding(.horizontal, 18)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onAppear { viewModel.startUpdates() }
        .onDisappear { viewModel.stopUpdates() }
    }
}

// ---------- Sidebar ----------
struct SidebarView: View {
    var body: some View {
        VStack(spacing: 22) {
            Image("deepcool-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .padding(.top, 8)

            VStack(spacing: 22) {
                SidebarIcon(systemName: "gauge")
                SidebarIcon(systemName: "display")
                SidebarIcon(systemName: "externaldrive")
                SidebarIcon(systemName: "network")
            }
            .padding(.top, 12)
            .foregroundColor(deepTeal)

            Spacer()
            SidebarIcon(systemName: "gearshape")
                .padding(.bottom, 14)
        }
        .frame(maxHeight: .infinity)
    }
}

fileprivate struct SidebarIcon: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 40, height: 40)
            .background(Color.clear)
            .cornerRadius(8)
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

        return InfoCard {
            HStack(spacing: 18) {
                CircularSemiGauge(value: cpuUsagePercent / 100.0, accent: deepTeal)
                    .frame(width: 160, height: 120)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Processeur :").font(.headline)
                        Image("DC CPU").resizable().scaledToFit().frame(width: 55, height: 55)
                    }

                    Text(cpuModel).font(.subheadline).foregroundColor(.secondary)
                    Text("Nombre De Cœurs: \(cpuCoreCount)").font(.caption).foregroundColor(.secondary)
                    Spacer().frame(height: 6)

                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Fréquence CPU").font(.headline).foregroundColor(.secondary)
                            Text(String(format: "%.2f GHz", cpuFrequencyMHz / 1000.0))
                                .font(.custom("DS-Digital", size: 40))
                                .foregroundColor(deepTeal)
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Température").font(.headline).foregroundColor(.secondary)
                                Image(systemName: "thermometer").font(.system(size: 40)).foregroundColor(tempColor)
                                Text(String(format:"%.0f°C", cpuTemp))
                                    .font(.custom("DS-Digital", size: 40))
                                    .foregroundColor(tempColor)
                            }
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Consommation (TDP)").font(.headline).foregroundColor(.secondary)
                            Text(String(format: "%.0f W", cpuTDP))
                                .font(.custom("DS-Digital", size: 40))
                                .foregroundColor(deepTeal)
                        }
                        Spacer()
                    }
                }
            }
        }
        .frame(minHeight: 60)
    }
}

// ---------- GPUCardSimple ----------
struct GPUCardSimple: View {
    let gpuModel: String
    let gpuVRAM: Double

    var body: some View {
        InfoCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Carte Graphique :").font(.headline)
                    Image("graphics card vector").resizable().scaledToFit().frame(width: 200, height: 200)
                }
                Text(gpuModel).font(.subheadline).foregroundColor(.secondary)
                Text(String(format: "VRAM : %.1f GB", gpuVRAM)).font(.subheadline).foregroundColor(.secondary)
            }
        }
        .frame(minHeight: 60)
    }
}

// ---------- MemoryCard ----------
struct MemoryCard: View {
    let ramUsed: Double
    let ramTotal: Double
    let ramFreqMHz: Double

    var body: some View {
        InfoCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mémoire Utilisée").font(.headline)

                let safeTotal = ramTotal > 0 ? ramTotal : 1
                let usagePercent = min(max(ramUsed / safeTotal, 0), 1)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        .frame(height: 36)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.windowBackgroundColor)))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(deepTeal)
                        .frame(width: CGFloat(usagePercent) * 300, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                HStack {
                    Text(String(format: "%.0f / %.0f GB", ramUsed, ramTotal)).font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%d%%", Int(usagePercent * 100))).font(.caption2).foregroundColor(.secondary)
                }

                Text("Fréquence Mémoire").font(.headline).foregroundColor(.secondary)
                Text(String(format: "%.0f MHz", ramFreqMHz)).font(.title2).foregroundColor(deepTeal)
            }
        }
        .frame(minHeight: 160)
    }
}

// ---------- DiskCard ----------
struct DiskCard: View {
    let diskUsed: Double
    let diskTotal: Double

    var body: some View {
        InfoCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Disque").font(.headline)

                let safeTotal = diskTotal > 0 ? diskTotal : 1
                let usagePercent = min(max(diskUsed / safeTotal, 0), 1)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        .frame(height: 36)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.windowBackgroundColor)))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(deepTeal)
                        .frame(width: CGFloat(usagePercent) * 300, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                let usedGB = diskUsed / 1_073_741_824
                let totalGB = diskTotal / 1_073_741_824
                HStack {
                    Text(String(format: "%.2f / %.2f Go", usedGB, totalGB)).font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%d%%", Int(usagePercent * 100))).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .frame(minHeight: 160)
    }
}

// ---------- NetworkCard ----------
struct NetworkCard: View {
    let networkUploadSpeed: Double
    let networkDownloadSpeed: Double

    var body: some View {
        InfoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "network").font(.title2).foregroundColor(deepTeal)
                    Text("Traffic Réseau").font(.headline)
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Vitesse D'envoie").font(.caption).foregroundColor(.secondary)
                        ProgressView(value: min(networkUploadSpeed / 10_000_000, 1.0)).accentColor(deepTeal)
                        Text(String(format: "%.2f MB/s", networkUploadSpeed / 1_048_576)).font(.caption2).foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading) {
                        Text("Vitesse De Reception").font(.caption).foregroundColor(.secondary)
                        ProgressView(value: min(networkDownloadSpeed / 10_000_000, 1.0)).accentColor(deepTeal)
                        Text(String(format: "%.2f MB/s", networkDownloadSpeed / 1_048_576)).font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(minHeight: 160)
    }
}

// ---------- CircularSemiGauge ----------
struct CircularSemiGauge: View {
    var value: Double
    var accent: Color

    var body: some View {
        GeometryReader { g in
            ZStack {
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(180))

                Circle()
                    .trim(from: 0.125, to: 0.125 + (0.75 * CGFloat(min(max(value, 0.0), 1.0))))
                    .stroke(accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .animation(.easeInOut(duration: 0.45), value: value)

                VStack {
                    Text("Load").font(.caption).foregroundColor(.secondary)
                    Text("\(Int(min(max(value, 0.0), 1.0) * 100))%")
                        .font(.title)
                        .fontWeight(.semibold)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}

// ---------- Preview ----------
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(viewModel: ContentViewModel())
                .frame(minWidth: 1100, minHeight: 700)
                .preferredColorScheme(.light)

            ContentView(viewModel: ContentViewModel())
                .frame(minWidth: 1100, minHeight: 700)
                .preferredColorScheme(.dark)
        }
    }
}
