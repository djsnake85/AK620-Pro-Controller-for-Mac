// Djsnake85

import SwiftUI
import AppKit
import Foundation

// MARK: - Couleurs dynamiques
func temperatureColor(_ temp: Double) -> Color {
    if temp > 75 { return .red }
    else if temp >= 65 { return .orange }
    else { return .green }
}

func usageColor(_ usage: Double) -> Color {
    if usage > 75 { return .red }
    else if usage >= 50 { return .orange }
    else { return .green }
}

// MARK: - Blur effect
struct VisualEffectBlur: NSViewRepresentable {
    var blurStyle: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = blurStyle
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = blurStyle
    }
}

// MARK: - ContentView principal
struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var animateBackground: Bool = false

    init(viewModel: ContentViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.15, green: 0.15, blue: 0.15), Color(red: 0.25, green: 0.25, blue: 0.25)]
                        : [.white, .gray.opacity(0.1)]
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.0), value: colorScheme)

            VisualEffectBlur(blurStyle: colorScheme == .dark ? .dark : .light)
                .ignoresSafeArea()
                .opacity(0.25)
                .animation(.easeInOut(duration: 1.0), value: colorScheme)

            VStack(spacing: 16) {
                HStack { Spacer() }

                HeaderView(
                    cpuModel: viewModel.cpuModel,
                    cpuCoreCount: viewModel.cpuCoreCount,
                    gpuModel: viewModel.gpuModel,
                    animateTitle: $viewModel.animateTitle
                )
                .padding(.top, 6)

                DigitalDisplayView(
                    temperature: viewModel.cpuTemperature,
                    usage: viewModel.cpuUsage,
                    power: viewModel.cpuTDP,
                    frequency: viewModel.cpuFrequency,
                    animatePulse: $viewModel.animatePulse
                )
                .padding(.top, 14)

                InfoMetricsWithProgress(
                    cpuFrequency: viewModel.cpuFrequency,
                    cpuUsage: viewModel.cpuUsage,
                    cpuTemperature: viewModel.cpuTemperature,
                    cpuTDP: viewModel.cpuTDP,
                    animatePulse: $viewModel.animatePulse
                )
                .padding(.bottom, 8.0)

                DashboardView(viewModel: viewModel)

                Divider()

                HStack {
                    Spacer()
                    Image("Deepcool-logo-black")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 150)
                }
                .padding(.top, 2)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .onAppear {
                viewModel.startUpdates()
                withAnimation(.easeInOut(duration: 1.0)) {
                    animateBackground = true
                }
            }
            .onDisappear { viewModel.stopUpdates() }
        }
    }
}

// MARK: - HeaderView
struct HeaderView: View {
    var cpuModel: String
    var cpuCoreCount: Int
    var gpuModel: String
    @Binding var animateTitle: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                InfoRow(imageName: "DC CPU", label: "Processeur", value: cpuModel, fontSize: 14)
                InfoRow(imageName: "DC CPU", label: "Cœurs", value: "\(cpuCoreCount)", fontSize: 14)
                InfoRow(imageName: "GPU", label: "GPU", value: gpuModel, fontSize: 14)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - DigitalDisplayView
struct DigitalDisplayView: View {
    var temperature: Double
    var usage: Double
    var power: Double
    var frequency: Double
    @Binding var animatePulse: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.windowBackgroundColor).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 8)

            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "thermometer")
                        .foregroundColor(Color(red: 0.031, green: 0.659, blue: 0.54))
                        .font(.system(size: 60))
                        .scaleEffect(animatePulse ? 1.1 : 1.0)
                        .animation(.bouncy, value: animatePulse)

                    Text("\(String(format: "%.0f", temperature))°C")
                        .font(.custom("DS-Digital", size: 90))
                        .foregroundColor(temperatureColor(temperature))
                        .multilineTextAlignment(.center)
                        .shadow(color: temperatureColor(temperature).opacity(0.6), radius: 6)
                }

                HStack(spacing: 24) {
                    DigitalSubMetric(label: "USAGE", value: String(format: "%.0f %%", usage), fontSize: 50)
                    DigitalSubMetric(label: "POWER", value: String(format: "%.1f W", power), fontSize: 50)
                    DigitalSubMetric(label: "FREQ", value: String(format: "%.2f GHz", frequency), fontSize: 50)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal)
        .frame(height: 160)
        .onAppear { animatePulse = true }
    }
}

// MARK: - DigitalSubMetric
struct DigitalSubMetric: View {
    var label: String
    var value: String
    var fontSize: CGFloat = 28

    var body: some View {
        VStack {
            Text(label)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.custom("DS-Digital", size: fontSize))
                .foregroundColor(.primary)
        }
        .frame(minWidth: 70)
    }
}

// MARK: - InfoRow
struct InfoRow: View {
    var imageName: String
    var label: String
    var value: String
    var fontSize: CGFloat

    var body: some View {
        HStack(spacing: 14) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 45, height: 45)
            Text("\(label): \(value)")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(14)
        .background(Color(.windowBackgroundColor).opacity(0.75))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 3)
    }
}

// MARK: - InfoMetricsWithProgress
struct InfoMetricsWithProgress: View {
    var cpuFrequency: Double
    var cpuUsage: Double
    var cpuTemperature: Double
    var cpuTDP: Double
    @Binding var animatePulse: Bool

    var body: some View {
        VStack(spacing: 24) {
            MetricWithProgress(
                title: "Fréquence CPU",
                iconName: "cpu",
                value: String(format: "%.2f GHz", cpuFrequency),
                progress: min(cpuFrequency / 5.0, 1.0),
                progressColor: .green,
                animatePulse: animatePulse
            )

            MetricWithProgress(
                title: "Utilisation CPU",
                iconName: "speedometer",
                value: String(format: "%.1f %%", cpuUsage),
                progress: cpuUsage / 100,
                progressColor: usageColor(cpuUsage),
                animatePulse: animatePulse
            )

            MetricWithProgress(
                title: "Température CPU",
                iconName: "thermometer",
                value: String(format: "%.1f°C", cpuTemperature),
                progress: min(cpuTemperature / 100, 1.0),
                progressColor: temperatureColor(cpuTemperature),
                animatePulse: animatePulse
            )

            MetricWithProgress(
                title: "TDP",
                iconName: "bolt.fill",
                value: String(format: "%.1f W", cpuTDP),
                progress: min(cpuTDP / 150.0, 1.0),
                progressColor: .green,
                animatePulse: animatePulse
            )
        }
        .padding(.top, 24)
    }
}

// MARK: - MetricWithProgress
struct MetricWithProgress: View {
    var title: String
    var iconName: String
    var value: String
    var progress: Double
    var progressColor: Color
    var animatePulse: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(progressColor.opacity(animatePulse ? 1 : 0.6))
                    .scaleEffect(animatePulse ? 1.2 : 1.0)
                    .animation(.bouncy, value: animatePulse)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(value)
                    .font(.custom("DS-Digital", size: 24))
                    .foregroundColor(progressColor)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(height: 10)
                .cornerRadius(5)
        }
        .padding(12)
        .background(Color(.windowBackgroundColor).opacity(0.85))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 5)
    }
}

// MARK: - DashboardView
struct DashboardView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 24) {
                MetricView(
                    title: "RAM utilisée",
                    iconName: "memorychip.fill",
                    value: String(format: "%.2f / %.2f Go", viewModel.ramUsed, viewModel.ramTotal),
                    valueColor: .blue
                )

                CircularProgressBar(
                    value: viewModel.ramUsed / viewModel.ramTotal,
                    color: Color.blue
                )
                .frame(width: 90, height: 90)

                Text(String(format: "%.0f%%", viewModel.ramUsed / viewModel.ramTotal * 100))
                    .font(.title2)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)

                Spacer()

                MetricView(
                    title: "Fréquence RAM",
                    iconName: "speedometer",
                    value: String(format: "%.0f MHz", viewModel.ramFrequency),
                    valueColor: .blue
                )
            }
            .padding(.top, 14)
        }
        .padding(.top, 10)
    }
}

// MARK: - MetricView
struct MetricView: View {
    var title: String
    var iconName: String
    var value: String
    var valueColor: Color

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.primary)
                Text(title)
                    .foregroundColor(.secondary)
                    .font(.headline)
            }
            Text(value)
                .font(.title3)
                .foregroundColor(valueColor)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(Color(.windowBackgroundColor).opacity(0.85))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.3), radius: 5)
    }
}

// MARK: - CircularProgressBar
struct CircularProgressBar: View {
    var value: Double
    var color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 10)
                .opacity(0.2)
                .foregroundColor(color)

            Circle()
                .trim(from: 0, to: CGFloat(min(value, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: -90))
                .animation(.bouncy, value: value)
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ContentViewModel())
            .preferredColorScheme(.light)
            .padding(.bottom)
            .environment(\.sizeCategory, .large)
    }
}
