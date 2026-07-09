import SwiftUI

struct MemoryGauge: View {
    let usedPercent: Double
    let color: Color
    var isBusy: Bool = false

    private var clamped: Double {
        min(max(usedPercent, 0), 100)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                // Track
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 18)
                    .frame(width: size * 0.85, height: size * 0.85)

                // Progress
                Circle()
                    .trim(from: 0, to: clamped / 100)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.5), color],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: size * 0.85, height: size * 0.85)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: clamped)

                // Inner ring
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 2)
                    .frame(width: size * 0.68, height: size * 0.68)

                VStack(spacing: 4) {
                    if isBusy {
                        ProgressView()
                            .tint(color)
                            .scaleEffect(1.2)
                            .padding(.bottom, 4)
                        Text("Limpiando…")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text(String(format: "%.0f%%", clamped))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text("memoria en uso")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MemoryGauge(usedPercent: 72, color: .orange)
            .frame(height: 240)
            .padding()
    }
}
