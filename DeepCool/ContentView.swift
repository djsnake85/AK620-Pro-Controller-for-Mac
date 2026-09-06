import SwiftUI
import AppKit

fileprivate let deepTeal = Color(red: 0.031, green: 0.659, blue: 0.54)

fileprivate func temperatureColor(_ temp: Double) -> Color {
    if temp > 90 { return .red }
    else if temp >= 75 { return .orange }
    else { return deepTeal }
}

// ---------- InfoCard ----------
struct InfoCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
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
                }
                .padding(.top, 5)
            }
        }
        .onAppear { viewModel.startUpdates() }
        .onDisappear { viewModel.stopUpdates() }
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
            HStack(spacing: 20) {
                CircularSemiGauge(value: cpuUsagePercent / 100.0, accent: deepTeal)
                    .frame(width: 115, height: 115)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CPU:").font(.custom("DS-Digital", size: 28)).foregroundColor(.blue)
                        Image("DC CPU").resizable().scaledToFit().frame(width: 128, height: 128)
                    }

                    Text(cpuModel).font(.subheadline).foregroundColor(.secondary)
                    Text("Nombre De Cœurs: \(cpuCoreCount)").font(.caption).foregroundColor(.secondary)
                    Spacer().frame(height: 1)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Fréquence CPU:").font(.headline).foregroundColor(.secondary)
                            Text(String(format: "%.2f GHz", cpuFrequencyMHz / 1000.0))
                                .font(.custom("DS-Digital", size: 30))
                                .foregroundColor(deepTeal)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Consommation (TDP):").font(.headline).foregroundColor(.secondary)
                            Text(String(format: "%.0f W", cpuTDP))
                                .font(.custom("DS-Digital", size: 30))
                                .foregroundColor(deepTeal)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Température:").font(.headline).foregroundColor(.secondary)
                            Image(systemName: "thermometer").font(.system(size: 20)).foregroundColor(tempColor)
                            Text(String(format:"%.0f°C", cpuTemp))
                                .font(.custom("DS-Digital", size: 32))
                                .foregroundColor(tempColor)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 50)
    }
}

// ---------- GPUCardSimple ----------
struct GPUCardSimple: View {
    let gpuModel: String
    let gpuVRAM: Double

    var body: some View {
        InfoCard {
            HStack(alignment: .center, spacing: 5) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("GPU:")
                        .font(.custom("DS-Digital", size: 26))
                        .foregroundColor(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(gpuModel)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text(String(format: "Mémoire Vidéo : %.1f GB", gpuVRAM))
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }

                Spacer()

                Image("GPU R")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            .padding(.vertical, 12)
        }
        .frame(minHeight: 50)
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

                // CORRECTION : GeometryReader pour une largeur dynamique
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                        RoundedRectangle(cornerRadius: 6)
                            .fill(deepTeal)
                            .frame(width: CGFloat(usagePercent) * geo.size.width, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .frame(height: 20)

                HStack {
                    Text(String(format: "%.2f / %.2f GB", ramUsed, ramTotal)).font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%d%%", Int(usagePercent * 100))).font(.caption2).foregroundColor(.secondary)
                }

                Text("Fréquence Mémoire").font(.headline).foregroundColor(.secondary)
                Text(String(format: "%.0f MHz", ramFreqMHz)).font(.title2).foregroundColor(deepTeal)
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
            VStack(alignment: .leading, spacing: 12) {
                Text("Disque").font(.headline)

                let safeTotal = diskTotal > 0 ? diskTotal : 1
                let usagePercent = min(max(diskUsed / safeTotal, 0), 1)

                // CORRECTION : GeometryReader pour une largeur dynamique
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                            )
                        RoundedRectangle(cornerRadius: 6)
                            .fill(deepTeal)
                            .frame(width: CGFloat(usagePercent) * geo.size.width, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .frame(height: 20)

                HStack {
                    Text(String(format: "%.2f / %.2f GB", diskUsed, diskTotal)).font(.caption2).foregroundColor(.secondary)
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

                HStack(spacing: 24) {
                    NeedleGauge(
                        value: networkUploadSpeed / 1_048_576,
                        maxValue: 125,
                        accent: deepTeal,
                        label: "Upload",
                        labelOffset: -25
                    )
                    .frame(width: 140, height: 120)

                    NeedleGauge(
                        value: networkDownloadSpeed / 1_048_576,
                        maxValue: 125,
                        accent: .orange,
                        label: "Download",
                        labelOffset: -25
                    )
                    .frame(width: 140, height: 120)
                }
            }
        }
        .frame(minHeight: 160)
    }
}

// ---------- NeedleGauge ----------
struct NeedleGauge: View {
    var value: Double
    var maxValue: Double
    var accent: Color
    var label: String
    var labelOffset: CGFloat = 0

    @State private var animatedValue: Double = 0

    private let totalAngle: Double = 270
    private let startAngle: Double = -135

    var body: some View {
        GeometryReader { g in
            let width = g.size.width
            let height = g.size.height
            let center = CGPoint(x: width/2, y: height/2)
            let radius = min(width, height)/2.5
            // CORRECTION : protection contre la division par zéro
            let safeMax = maxValue > 0 ? maxValue : 1

            ZStack {
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(180))

                ForEach(0...10, id: \.self) { i in
                    let angle = startAngle + (Double(i)/10 * totalAngle)
                    let rad = angle * Double.pi / 180
                    let inner = CGPoint(
                        x: center.x + CGFloat(cos(rad)) * (radius - 6),
                        y: center.y + CGFloat(sin(rad)) * (radius - 6)
                    )
                    let outer = CGPoint(
                        x: center.x + CGFloat(cos(rad)) * radius,
                        y: center.y + CGFloat(sin(rad)) * radius
                    )
                    Path { path in
                        path.move(to: inner)
                        path.addLine(to: outer)
                    }
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 2)

                    // CORRECTION : utilisation de safeMax
                    let labelValue = Int(Double(i)/10 * safeMax)
                    let textPos = CGPoint(
                        x: center.x + CGFloat(cos(rad)) * (radius + 10),
                        y: center.y + CGFloat(sin(rad)) * (radius + 10)
                    )
                    Text("\(labelValue)").font(.caption2).foregroundColor(.secondary)
                        .position(textPos)
                }

                // CORRECTION : utilisation de safeMax
                let needleAngle = startAngle + (animatedValue / safeMax * totalAngle)
                let rad = needleAngle * Double.pi / 180
                let tip = CGPoint(x: center.x + CGFloat(cos(rad)) * radius,
                                  y: center.y + CGFloat(sin(rad)) * radius)

                Path { path in
                    let baseWidth: CGFloat = 8
                    let anglePerp = atan2(tip.y - center.y, tip.x - center.x) + .pi/2
                    let base1 = CGPoint(
                        x: center.x + cos(anglePerp) * baseWidth,
                        y: center.y + sin(anglePerp) * baseWidth
                    )
                    let base2 = CGPoint(
                        x: center.x - cos(anglePerp) * baseWidth,
                        y: center.y - sin(anglePerp) * baseWidth
                    )
                    path.move(to: base1)
                    path.addLine(to: tip)
                    path.addLine(to: base2)
                    path.closeSubpath()
                }
                .fill(accent)

                Circle()
                    .fill(accent)
                    .frame(width: 12, height: 12)

                VStack {
                    Spacer()
                    Text(label).font(.caption).foregroundColor(.secondary)
                        .offset(y: labelOffset)
                    Text(String(format: "%.2f MB/s", animatedValue))
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .offset(y: labelOffset)
                }
            }
            .onAppear { animatedValue = value }
            // CORRECTION : compatibilité macOS 13 et antérieur
            .onChange(of: value) { newValue in
                withAnimation(.interpolatingSpring(stiffness: 140, damping: 18)) {
                    animatedValue = newValue
                }
            }
        }
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
                    .stroke(Color(NSColor.separatorColor).opacity(0.3),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(180))

                Circle()
                    .trim(from: 0.125,
                          to: 0.125 + (0.75 * CGFloat(min(max(value, 0), 1))))
                    .stroke(accent,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.3), value: value)

                VStack {
                    Text("Charge CPU").font(.caption).foregroundColor(.secondary)
                    Text("\(Int(min(max(value, 0), 1) * 100))%")
                        .font(.custom("DS-Digital", size: 34))
                        .foregroundColor(deepTeal)
                }
            }
        }
    }
}

