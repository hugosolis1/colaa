// WavyViewModel.swift
// Estado compartido de la app Astro Wavy Pro

import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Shared App State

class WavyAppState: ObservableObject {
    static let shared = WavyAppState()

    // Datos de precio
    @Published var priceBars: [PriceBar] = []
    @Published var priceFileName: String = ""

    // Wavy Lines simples
    @Published var simpleWavys: [WavyConfig] = []
    @Published var simpleWavyResults: [WavyResult] = []

    // Wavy Compuestas
    @Published var compositeWavys: [CompositeWavyConfig] = []
    @Published var compositeWavyResults: [WavyResult] = []

    // Gann Angles
    @Published var gannAngles: [GannAngle] = []

    // Square of Nine
    @Published var sq9Levels: [Sq9Level] = []
    @Published var sq9Price: Double = 0

    // Square Out
    @Published var squareOutEvents: [SquareOutEvent] = []

    // Estaciones retrógradas
    @Published var retroStations: [RetroStation] = []

    // FC Calculator
    @Published var fcResult: FCResult? = nil

    // Puntos de precios ingresados manualmente
    @Published var manualPricePoints: [(date: Date, price: Double)] = []

    // Rango de fechas del gráfico
    var chartStartDate: Date {
        priceBars.first?.date ?? Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    }
    var chartEndDate: Date {
        priceBars.last?.date ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    }
    var priceMin: Double { priceBars.map(\.low).min() ?? 0 }
    var priceMax: Double { priceBars.map(\.high).max() ?? 1 }

    // Calcular todas las wavys
    func recalculateAllWavys() {
        let endDate = Calendar.current.date(byAdding: .year, value: 1, to: chartEndDate) ?? chartEndDate
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [WavyResult] = []
            for cfg in self.simpleWavys where cfg.visible {
                let pts = WavyEngine.computeSimpleWavy(config: cfg, endDate: endDate,
                                                        stepHours: self.autoStepHours(cfg.planet))
                results.append(WavyResult(name: cfg.name, color: cfg.color, points: pts))
            }
            DispatchQueue.main.async { self.simpleWavyResults = results }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var results: [WavyResult] = []
            for cfg in self.compositeWavys where cfg.visible {
                let pts = WavyEngine.computeCompositeWavy(config: cfg, endDate: endDate)
                results.append(WavyResult(name: cfg.name, color: cfg.color, points: pts, isComposite: true))
            }
            DispatchQueue.main.async { self.compositeWavyResults = results }
        }
    }

    func autoStepHours(_ planet: Planet) -> Double {
        switch planet {
        case .moon: return 1
        case .mercury, .venus: return 4
        case .sun: return 6
        case .mars: return 12
        default: return 24
        }
    }

    func addSimpleWavy(_ cfg: WavyConfig) {
        simpleWavys.append(cfg)
        recalculateAllWavys()
    }

    func removeSimpleWavy(_ id: UUID) {
        simpleWavys.removeAll { $0.id == id }
        recalculateAllWavys()
    }

    func addCompositeWavy(_ cfg: CompositeWavyConfig) {
        compositeWavys.append(cfg)
        recalculateAllWavys()
    }

    func removeCompositeWavy(_ id: UUID) {
        compositeWavys.removeAll { $0.id == id }
        recalculateAllWavys()
    }

    func loadRetroStations(for planets: [Planet], months: Int = 12) {
        let start = Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
        let end   = Calendar.current.date(byAdding: .month, value: months,  to: Date()) ?? Date()
        DispatchQueue.global(qos: .background).async {
            var all: [RetroStation] = []
            for pl in planets {
                let st = WavyEngine.findRetroStations(planet: pl, startDate: start, endDate: end)
                all.append(contentsOf: st)
            }
            DispatchQueue.main.async { self.retroStations = all.sorted { $0.date < $1.date } }
        }
    }
}

// MARK: - Wave Colors

let wavyColors: [String] = [
    "#FFD700","#FF6B6B","#4ECDC4","#45B7D1","#96CEB4",
    "#FFEAA7","#DDA0DD","#98FB98","#F0E68C","#87CEEB",
    "#FF7F50","#00CED1","#FF69B4","#7B68EE","#20B2AA"
]

var wavyColorIndex = 0
func nextWavyColor() -> String {
    let c = wavyColors[wavyColorIndex % wavyColors.count]
    wavyColorIndex += 1
    return c
}

// MARK: - Date Formatter helpers

let shortDateFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd/MM/yy"; return f
}()
let medDateFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm"; return f
}()
