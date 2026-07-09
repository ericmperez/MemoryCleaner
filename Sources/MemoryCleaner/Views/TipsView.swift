import SwiftUI

struct TipsView: View {
    @Environment(\.dismiss) private var dismiss

    private let tips: [(icon: String, title: String, body: String, color: Color)] = [
        (
            "app.dashed",
            "Cierra apps pesadas",
            "Chrome, Docker, Xcode, editores de video y muchas pestañas son los mayores consumidores de RAM. Ciérralos cuando no los uses.",
            .blue
        ),
        (
            "internaldrive",
            "Deja espacio libre en disco",
            "macOS usa el SSD como memoria virtual. Si el disco está casi lleno, el sistema se pone lento aunque tengas RAM libre.",
            .purple
        ),
        (
            "arrow.triangle.2.circlepath",
            "Actualiza macOS y las apps",
            "Las actualizaciones suelen corregir fugas de memoria que dejan RAM “atascada” en procesos.",
            .green
        ),
        (
            "arrow.clockwise",
            "Reinicia de vez en cuando",
            "Un reinicio limpia por completo la RAM y los procesos zombies. Es la limpieza más profunda posible.",
            .orange
        ),
        (
            "gauge.with.dots.needle.67percent",
            "Mira Monitor de Actividad",
            "Abre Monitor de Actividad → Memoria para ver qué proceso usa más. Si algo se dispara, ciérralo o reinícialo.",
            .teal
        ),
        (
            "terminal",
            "Sobre la purga profunda",
            "El comando purge vacía páginas de archivo inactivas. No borra tus datos: solo memoria que el sistema puede volver a cargar desde disco.",
            .mint
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: tip.icon)
                                .font(.title3)
                                .foregroundStyle(tip.color)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tip.title)
                                    .font(.headline)
                                Text(tip.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Buenas prácticas en Mac")
                } footer: {
                    Text("macOS gestiona la memoria automáticamente. Esta app acelera la recuperación de memoria inactiva y purgable; un reinicio sigue siendo la opción más radical.")
                }
            }
            .navigationTitle("Consejos")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    TipsView()
}
