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
            // Fond dynamique clair / sombre avec animation
            LinearGradient(
                gradient: Gradient(
                    colors: colorScheme == .dark
                        ? [.black, .gray.opacity(0.9)]
                        : [.white, .gray.opacity(0.1)]
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.0), value: colorScheme)

            VisualEffectBlur(blurStyle: colorScheme == .dark ? .dark : .light)
                .ignoresSafeArea()
                .opacity(80.0)
                .animation(.pulseAnimation, value: colorScheme)

            VStack(spacing: 0) {
                HStack { Spacer() }

                HeaderView(
                    cpuModel: viewModel.cpuModel,
                    cpuCoreCount: viewModel.cpuCoreCount,
                    gpuModel: viewModel.gpuModel,
                    animateTitle: $viewModel.animateTitle
                )
                .padding(.top, 4)

                DigitalDisplayView(
                    temperature: viewModel.cpuTemperature,
                    usage: viewModel.cpuUsage,
                    power: viewModel.cpuTDP,
                    frequency: viewModel.cpuFrequency,
                    animatePulse: $viewModel.animatePulse
                )
                .padding(.top, 12)

                InfoMetricsWithProgress(
                    cpuFrequency: viewModel.cpuFrequency,
                    cpuUsage: viewModel.cpuUsage,
                    cpuTemperature: viewModel.cpuTemperature,
                    cpuTDP: viewModel.cpuTDP,
                    animatePulse: $viewModel.animatePulse
                )
                .padding(.top, 20)

                DashboardView(viewModel: viewModel)

                RefreshFooterView(animatePulse: $viewModel.animatePulse)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
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
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                InfoRow(imageName: "DC CPU", label: "CPU", value: cpuModel, fontSize: 10)
                InfoRow(imageName: "DC CPU", label: "Cœurs", value: "\(cpuCoreCount)", fontSize: 12)
                InfoRow(imageName: "GPU", label: "GPU", value: gpuModel, fontSize: 10)
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

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                     Image(systemName: "thermometer")
                          .foregroundColor(Color(red: 0.031, green: 0.659, blue: 0.54))
                        .font(.system(size: 48))
                        .scaleEffect(animatePulse ? 1.1 : 1.0)
                        .animation(.bouncy, value: animatePulse)

                    Text("\(String(format: "%.0f", temperature))°C")
                        .font(.custom("DS-Digital", size: 66))
                        .foregroundColor(temperatureColor(temperature))
                        .multilineTextAlignment(.center)
                        .shadow(color: temperatureColor(temperature).opacity(0.6), radius: 6)
                }

                HStack(spacing: 20) {
                    DigitalSubMetric(label: "FREQ", value: String(format: "%.2f GHz", frequency), fontSize: 44)
                    DigitalSubMetric(label: "USAGE", value: String(format: "%.0f %%", usage), fontSize: 44)
                    DigitalSubMetric(label: "POWER", value: String(format: "%.1f W", power), fontSize: 44)
                }
            }
            .padding(.horizontal, 5)
        }
        .padding(.horizontal)
        .frame(height: 140)
        .onAppear { animatePulse = true }
    }
}

// MARK: - DigitalSubMetric
struct DigitalSubMetric: View {
    var label: String
    var value: String
    var fontSize: CGFloat = 22

    var body: some View {
        VStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.custom("DS-Digital", size: fontSize))
                .foregroundColor(.primary)
        }
        .frame(minWidth: 60)
    }
}

// MARK: - InfoRow
struct InfoRow: View {
    var imageName: String
    var label: String
    var value: String
    var fontSize: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            Text("\(label) : \(value)")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(Color(.windowBackgroundColor).opacity(0.7))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 2)
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
        VStack(spacing: 20) {
            MetricWithProgress(
                title: "Fréquence CPU",
                iconName: "cpu",
                value: String(format: "%.2f GHz", cpuFrequency),
                progress: min(cpuFrequency / 5.0, 1.0),
                progressColor: .green
            )

            MetricWithProgress(
                title: "Utilisation CPU",
                iconName: "speedometer",
                value: String(format: "%.1f %%", cpuUsage),
                progress: cpuUsage / 100,
                progressColor: usageColor(cpuUsage)
            )

            MetricWithProgress(
                title: "Température CPU",
                iconName: "thermometer",
                value: String(format: "%.1f °C", cpuTemperature),
                progress: min(cpuTemperature / 100.0, 1.0),
                progressColor: temperatureColor(cpuTemperature),
                animatePulse: animatePulse
            )

            MetricWithProgress(
                title: "TDP",
                iconName: "bolt.fill",
                value: String(format: "%.1f W", cpuTDP),
                progress: min(cpuTDP / 150.0, 1.0),
                progressColor: .orange
            )
        }
        .padding(.top, 20)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(progressColor.opacity(animatePulse ? 1 : 0.6))
                    .scaleEffect(animatePulse ? 1.2 : 1.0)
                    .animation(.bouncy, value: animatePulse)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(value)
                    .font(.custom("DS-Digital", size: 20))
                    .foregroundColor(progressColor)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(height: 8)
                .cornerRadius(4)
        }
        .padding(10)
        .background(Color(.windowBackgroundColor).opacity(0.85))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.3), radius: 4)
    }
}

// MARK: - DashboardView
struct DashboardView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                MetricView(
                    title: "RAM utilisée",
                    iconName: "memorychip.fill",
                    value: String(format: "%.2f / %.2f Go", viewModel.ramUsed, viewModel.ramTotal),
                    valueColor: .blue
                )

                CircularProgressBar(
                    value: viewModel.ramUsed / viewModel.ramTotal,
                    color: Color.green
                )
                .frame(width: 75, height: 75)

                Text(String(format: "%.0f%%", viewModel.ramUsed / viewModel.ramTotal * 100))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.green)
                    .multilineTextAlignment(.center)

                Spacer()

                MetricView(
                    title: "Fréquence RAM",
                    iconName: "speedometer",
                    value: String(format: "%.0f MHz", viewModel.ramFrequency),
                    valueColor: .blue
                )
            }
            .padding(.top, 12)
        }
        .padding(.top, 8)
    }
}

// MARK: - MetricView
struct MetricView: View {
    var title: String
    var iconName: String
    var value: String
    var valueColor: Color

    var body: some View {
         VStack(alignment: .center, spacing: 4) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.primary)
                Text(title)
                    .foregroundColor(.secondary)
            }
            Text(value)
                   .font(.headline)
                   .foregroundColor(Color(red: 0.031, green: 0.659, blue: 0.54))
                   .multilineTextAlignment(.center)
                
        }
        .padding(10)
        .background(Color(.windowBackgroundColor).opacity(0.85))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.3), radius: 4)
    }
}

// MARK: - CircularProgressBar
struct CircularProgressBar: View {
    var value: Double
    var color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 8)
                .opacity(0.2)
                .foregroundColor(color)

            Circle()
                .trim(from: 0, to: CGFloat(min(value, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: -90))
                .animation(.bouncy, value: value)
        }
    }
}

// MARK: - RefreshFooterView
struct RefreshFooterView: View {
    @Binding var animatePulse: Bool

    var body: some View {
        HStack {
            Spacer()
             Image(systemName: "arrow.clockwise")
                  .foregroundColor(Color(red: 0.031, green: 0.659, blue: 0.54))
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ContentViewModel())
            .preferredColorScheme(.dark)
    }
}
