# Memory Cleaner (macOS)

App nativa de **Mac** en SwiftUI que muestra el uso de RAM y libera **memoria no utilizada / inactiva**.

## Qué hace

| Modo | Acción | Contraseña |
|------|--------|------------|
| **Limpieza rápida** | Presión de memoria + `malloc_zone_pressure_relief` + limpia cachés de la app | No |
| **Purga profunda** | Todo lo anterior + `/usr/sbin/purge` (páginas de archivo inactivas en todo el sistema) | Sí (admin) |

Métricas en vivo: en uso, disponible, inactiva, comprimida, purgable y total RAM.

## Requisitos

- macOS 14+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Abrir y compilar

```bash
cd ~/MemoryCleaner
xcodegen generate
open MemoryCleaner.xcodeproj
```

En Xcode: **My Mac** → Run (`⌘R`).

Desde terminal:

```bash
xcodegen generate
xcodebuild -scheme MemoryCleaner -destination 'platform=macOS' build
xcodebuild -scheme MemoryCleaner -destination 'platform=macOS' test
```

## Notas técnicas

- **Sandbox desactivado** para poder invocar `purge` y leer stats del sistema con fidelidad.
- `purge` no borra archivos: solo vacía memoria respaldada por disco que el kernel puede volver a cargar.
- macOS gestiona la RAM de forma agresiva; a veces el “después” no cambia mucho porque la memoria inactiva ya era útil como caché.

## Estructura

```
MemoryCleaner/
├── project.yml
├── Sources/MemoryCleaner/
│   ├── MemoryCleanerApp.swift
│   ├── Models/MemorySnapshot.swift
│   ├── Services/
│   │   ├── MemoryMonitor.swift
│   │   └── MemoryCleanerService.swift
│   ├── Support/
│   │   ├── ByteFormatter.swift
│   │   └── Shell.swift
│   └── Views/
└── Tests/MemoryCleanerTests/
```

## Idioma

Interfaz en **español**.
