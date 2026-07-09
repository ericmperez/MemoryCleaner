import SwiftUI

struct ContentView: View {
    @StateObject private var service = MemoryCleanerService()
    @State private var showTips = false
    @State private var pulseClean = false

    var body: some View {
        ZStack {
            background

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 16) {
                        header
                        gaugeCard
                        statsGrid
                        cleanButtons

                        // Always-visible status so the user never sees "nothing"
                        statusPanel
                            .id("status")

                        if let result = service.lastResult {
                            resultCard(result)
                                .id("result")
                        }

                        if let error = service.lastError {
                            errorBanner(error)
                        }

                        if !service.liveLog.isEmpty {
                            logPanel
                                .id("log")
                        }

                        tipsButton
                        disclaimer
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
                .onChange(of: service.lastResult?.duration) { _, _ in
                    withAnimation {
                        proxy.scrollTo("result", anchor: .center)
                    }
                }
                .onChange(of: service.isCleaning) { _, cleaning in
                    if cleaning {
                        withAnimation { proxy.scrollTo("status", anchor: .center) }
                    }
                }
            }
        }
        .frame(minWidth: 440, idealWidth: 460, minHeight: 720, idealHeight: 780)
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.05, blue: 0.10),
                Color(red: 0.07, green: 0.09, blue: 0.16),
                Color(red: 0.05, green: 0.12, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            Circle()
                .fill(pressureColor.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(y: -40)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Memory Cleaner")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Borra cachés y libera RAM en tu Mac")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Image(systemName: "memorychip.fill")
                .font(.system(size: 28))
                .foregroundStyle(pressureColor)
                .symbolEffect(.pulse, options: .repeating, isActive: service.snapshot.pressure == .critical)
        }
    }

    // MARK: - Gauge

    private var gaugeCard: some View {
        VStack(spacing: 12) {
            MemoryGauge(
                usedPercent: service.snapshot.usedPercent,
                color: pressureColor,
                isBusy: service.isCleaning
            )
            .frame(height: 180)

            VStack(spacing: 4) {
                Text(service.snapshot.pressure.titleES)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(pressureColor)
                Text(service.snapshot.pressure.subtitleES)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
    }

    // MARK: - Stats

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatCard(title: "En uso", value: ByteFormatter.string(from: service.snapshot.usedBytes), icon: "chart.bar.fill", tint: .orange)
            StatCard(title: "Disponible", value: ByteFormatter.string(from: service.snapshot.freeBytes), icon: "checkmark.circle.fill", tint: .green)
            StatCard(title: "Inactiva", value: ByteFormatter.string(from: service.snapshot.inactiveBytes), icon: "pause.circle.fill", tint: .yellow)
            StatCard(title: "Comprimida", value: ByteFormatter.string(from: service.snapshot.compressedBytes), icon: "archivebox.fill", tint: .cyan)
        }
    }

    // MARK: - Buttons

    private var cleanButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    pulseClean = true
                    _ = await service.clean(mode: .quick)
                    pulseClean = false
                }
            } label: {
                HStack(spacing: 12) {
                    if service.isCleaning {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "trash.fill").font(.title3)
                    }
                    Text(service.isCleaning ? service.statusMessage : "Liberar ahora (cachés + RAM)")
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: service.isCleaning
                            ? [Color.gray.opacity(0.5), Color.gray.opacity(0.4)]
                            : [Color(red: 0.15, green: 0.75, blue: 0.65), Color(red: 0.10, green: 0.55, blue: 0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.teal.opacity(service.isCleaning ? 0 : 0.35), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(service.isCleaning)
            .scaleEffect(pulseClean ? 0.98 : 1)
            .accessibilityLabel("Liberar ahora")

            Button {
                Task {
                    pulseClean = true
                    _ = await service.clean(mode: .deep)
                    pulseClean = false
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Purga profunda + cachés")
                            .font(.subheadline.weight(.semibold))
                        Text("Pide contraseña de administrador")
                            .font(.caption2)
                            .opacity(0.85)
                    }
                    Spacer()
                }
                .padding(14)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.teal.opacity(0.45), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(service.isCleaning)

            if service.isCleaning {
                ProgressView(value: service.progress)
                    .tint(.teal)
            }
        }
    }

    // MARK: - Status (always visible)

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: service.isCleaning ? "arrow.triangle.2.circlepath" : "info.circle.fill")
                    .foregroundStyle(service.isCleaning ? .teal : .white.opacity(0.7))
                Text("Estado")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            Text(service.statusMessage)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.teal.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.teal.opacity(0.35), lineWidth: 1)
                )
        )
    }

    // MARK: - Result

    private func resultCard(_ result: CleanupResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.didImprove ? "checkmark.circle.fill" : "equal.circle.fill")
                    .foregroundStyle(result.didImprove ? .green : .yellow)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.didImprove ? "Limpieza terminada" : "Limpieza terminada")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(result.summary)
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(String(format: "%.1fs", result.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }

            Divider().overlay(Color.white.opacity(0.15))

            HStack {
                metric(title: "Archivos", value: "\(result.filesDeleted)")
                metric(title: "Disco", value: ByteFormatter.string(from: result.cacheFreedBytes))
                metric(title: "RAM", value: ByteFormatter.string(from: result.memoryFreedBytes))
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RAM antes").font(.caption2).foregroundStyle(.white.opacity(0.5))
                    Text(ByteFormatter.string(from: result.before.freeBytes) + " libres")
                        .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "arrow.right").foregroundStyle(.white.opacity(0.4))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("RAM después").font(.caption2).foregroundStyle(.white.opacity(0.5))
                    Text(ByteFormatter.string(from: result.after.freeBytes) + " libres")
                        .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.9))
                }
            }

            if !result.steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pasos")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    ForEach(result.steps) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: step.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(step.ok ? .green : .orange)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(step.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(step.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.55))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Live log

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Registro")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(service.liveLog.suffix(12).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                        .textSelection(.enabled)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.yellow.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var tipsButton: some View {
        Button { showTips = true } label: {
            HStack {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                Text("Consejos").foregroundStyle(.white.opacity(0.9))
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.4))
            }
            .padding(14)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showTips) {
            TipsView().frame(width: 420, height: 480)
        }
    }

    private var disclaimer: some View {
        Text("Borra **cachés de usuario** (~/Library/Caches, logs, temp viejos) y libera **RAM inactiva**. No borra tus documentos ni fotos.")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.4))
            .multilineTextAlignment(.center)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
    }

    private var pressureColor: Color {
        switch service.snapshot.pressure {
        case .normal: return .green
        case .elevated: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

#Preview {
    ContentView()
}
