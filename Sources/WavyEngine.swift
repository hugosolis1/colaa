// WavyEngine.swift
// Astro Wavy Pro iOS — Motor de Wavy Lines
// Basado en la metodología de Jenkins: precio(t) = P₀ + dir × FC × Δθ_acumulado(t)

import Foundation

// MARK: - Tipos de Wavy

enum WavyDirection: String, CaseIterable, Codable {
    case suma   = "Suma ↑"
    case resta  = "Resta ↓"
    var multiplier: Double { self == .suma ? 1 : -1 }
}

enum WavyMode: String, CaseIterable, Codable {
    case dinamico = "Dinámico Real"
    case hitos    = "Hitos (cada N°)"
}

struct WavyConfig: Identifiable, Codable {
    var id = UUID()
    var name: String
    var planet: Planet
    var fc: Double           // Factor de Conversión grados→precio
    var direction: WavyDirection
    var mode: WavyMode
    var hitoStep: Double     // grados entre hitos (ej. 90, 180, 360)
    var helio: Bool
    var startDate: Date
    var startPrice: Double
    var color: String        // hex color
    var visible: Bool = true
}

struct CompositeWavyConfig: Identifiable, Codable {
    var id = UUID()
    var name: String
    var planets: [CompositePlanetEntry]
    var direction: WavyDirection
    var startDate: Date
    var startPrice: Double
    var color: String
    var visible: Bool = true
    var useComplex: Bool = false  // superposición compleja vs simple
}

struct CompositePlanetEntry: Identifiable, Codable {
    var id = UUID()
    var planet: Planet
    var fc: Double
    var weight: Double
    var helio: Bool
}

// MARK: - Resultado de Wavy

struct WavyPoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double
    let cumDeg: Double
    let jd: Double
    let isHito: Bool
}

struct WavyResult: Identifiable {
    let id = UUID()
    let name: String
    let color: String
    let points: [WavyPoint]
    var isComposite: Bool = false
    var visible: Bool = true
}

// MARK: - Niveles Square of Nine

struct Sq9Level {
    let price: Double
    let axis: String
    let degree: Double
}

// MARK: - Square Out

struct SquareOutEvent {
    let date: Date
    let planet: String
    let degrees: Double
    let label: String
}

// MARK: - FC Calculator Result

struct FCResult {
    let fc: Double
    let deltaDeg: Double
    let deltaPriceAbs: Double
    let planet: Planet
    let date1: Date
    let date2: Date
    let price1: Double
    let price2: Double
    let lon1: Double
    let lon2: Double
    var harmonics: [Double] { [fc*0.25, fc*0.5, fc, fc*2, fc*4] }
}

// MARK: - Estaciones Retrógradas

struct RetroStation: Identifiable {
    let id = UUID()
    let date: Date
    let type: RetroStationType
    let longitude: Double
    let planet: Planet
}

enum RetroStationType: String {
    case retro        = "Estación R"
    case direct       = "Estación D"
    case returnRetro  = "Retorno R"
    var symbol: String {
        switch self {
        case .retro:       return "℞"
        case .direct:      return "D"
        case .returnRetro: return "↩"
        }
    }
    var color: String {
        switch self {
        case .retro:       return "#FF4444"
        case .direct:      return "#44FF44"
        case .returnRetro: return "#FFAA00"
        }
    }
}

// MARK: - Motor de Cálculo Wavy

class WavyEngine {

    // MARK: Wavy Simple (dinámico real)
    static func computeSimpleWavy(config: WavyConfig,
                                   endDate: Date,
                                   stepHours: Double = 24) -> [WavyPoint] {
        let jdStart = jdFromDate(config.startDate)
        let jdEnd   = jdFromDate(endDate)
        guard jdEnd > jdStart else { return [] }

        // Paso adaptativo por planeta
        let minStepH = planetMinStepHours(config.planet)
        let effectiveStepH = max(stepHours, minStepH)
        let stepDays = effectiveStepH / 24.0

        var points: [WavyPoint] = []
        var jd = jdStart
        var prevLon: Double? = nil
        var cumDeg = 0.0
        var hito_cumDeg = 0.0

        while jd <= jdEnd + stepDays {
            let pos = calcPlanets(jd: jd).first { $0.planet == config.planet }
            guard let lon = pos?.eclipticLongitude else { jd += stepDays; continue }

            if let prev = prevLon {
                var diff = lon - prev
                if diff > 180  { diff -= 360 }
                if diff < -180 { diff += 360 }
                cumDeg    += diff
                hito_cumDeg += diff
            }

            let price = config.startPrice + config.direction.multiplier * config.fc * cumDeg
            let isHito: Bool
            if config.mode == .hitos {
                isHito = abs(hito_cumDeg) >= config.hitoStep
                if isHito { hito_cumDeg = 0 }
            } else {
                isHito = false
            }

            points.append(WavyPoint(date: dateFromJD(jd), price: price,
                                    cumDeg: cumDeg, jd: jd, isHito: isHito))
            prevLon = lon
            jd += stepDays
        }
        return points
    }

    // MARK: Wavy Compuesta (superposición simple)
    static func computeCompositeWavy(config: CompositeWavyConfig,
                                      endDate: Date,
                                      stepHours: Double = 24) -> [WavyPoint] {
        guard !config.planets.isEmpty else { return [] }

        let jdStart = jdFromDate(config.startDate)
        let jdEnd   = jdFromDate(endDate)
        guard jdEnd > jdStart else { return [] }

        let minStep = config.planets.map { planetMinStepHours($0.planet) }.min() ?? 24
        let effectiveStepH = max(stepHours, minStep)
        let stepDays = effectiveStepH / 24.0

        let totalWeight = config.planets.map(\.weight).reduce(0, +)
        guard totalWeight > 0 else { return [] }

        var points: [WavyPoint] = []
        var jd = jdStart
        var prevLons: [UUID: Double] = [:]
        var cumDegs: [UUID: Double] = [:]
        config.planets.forEach { cumDegs[$0.id] = 0.0 }

        while jd <= jdEnd + stepDays {
            let allPos = calcPlanets(jd: jd)
            var weightedCum = 0.0

            for entry in config.planets {
                let pos = allPos.first { $0.planet == entry.planet }
                let lon: Double
                if entry.helio {
                    lon = pos?.helioLongitude ?? 0
                } else {
                    lon = pos?.eclipticLongitude ?? 0
                }

                if let prev = prevLons[entry.id] {
                    var diff = lon - prev
                    if diff > 180  { diff -= 360 }
                    if diff < -180 { diff += 360 }
                    cumDegs[entry.id, default: 0] += diff
                }
                prevLons[entry.id] = lon
                let w = entry.weight / totalWeight
                weightedCum += w * entry.fc * (cumDegs[entry.id] ?? 0)
            }

            let price = config.startPrice + config.direction.multiplier * weightedCum
            let totalCum = config.planets.map { (cumDegs[$0.id] ?? 0) * ($0.weight/totalWeight) }.reduce(0, +)
            points.append(WavyPoint(date: dateFromJD(jd), price: price,
                                    cumDeg: totalCum, jd: jd, isHito: false))
            jd += stepDays
        }
        return points
    }

    // MARK: Square of Nine
    static func squareOfNine(price: Double, numLevels: Int = 8) -> [Sq9Level] {
        guard price > 0 else { return [] }
        let (priceNorm, escala) = normalizeSq9(price)
        let sqr = sqrt(priceNorm)
        var levels: [Sq9Level] = []

        let increments = stride(from: -Double(numLevels)*2*0.25,
                                through: Double(numLevels)*2*0.25, by: 0.25)
            .filter { $0 != 0 }

        for k in increments {
            let newSqr = sqr + k
            guard newSqr > 0 else { continue }
            let lvlNorm = newSqr * newSqr
            let lvlReal = round(lvlNorm * escala * 10000) / 10000
            let degMod = ((k / 2.0) * 360.0).truncatingRemainder(dividingBy: 360)
            let degPos = degMod < 0 ? degMod + 360 : degMod
            let axis = sq9Axis(degPos)
            levels.append(Sq9Level(price: lvlReal, axis: axis, degree: degPos))
        }
        return levels.sorted { $0.price < $1.price }
    }

    private static func normalizeSq9(_ price: Double) -> (Double, Double) {
        var p = price, s = 1.0
        while p >= 1000 { p /= 10; s *= 10 }
        while p < 1 && p > 0 { p *= 10; s /= 10 }
        return (p, s)
    }

    private static func sq9Axis(_ deg: Double) -> String {
        if deg < 22.5 || deg > 337.5 { return "0°/360°" }
        if deg < 67.5  { return "45°" }
        if deg < 112.5 { return "90°" }
        if deg < 157.5 { return "135°" }
        if deg < 202.5 { return "180°" }
        if deg < 247.5 { return "225°" }
        if deg < 292.5 { return "270°" }
        return "315°"
    }

    // MARK: Square Out (precio → fechas)
    static func squareOut(price: Double,
                           planets: [Planet],
                           startDate: Date,
                           endDate: Date,
                           tolerance: Double = 1.5) -> [SquareOutEvent] {
        guard price > 0 else { return [] }
        let targetDeg = norm360(sqrt(price) * 180.0 / .pi)
        // Alternativa: usar el precio directamente mod 360
        let targetDeg2 = norm360(price)

        var events: [SquareOutEvent] = []
        let jdStart = jdFromDate(startDate)
        let jdEnd   = jdFromDate(endDate)
        let step = 1.0/24.0 // 1 hora

        for pl in planets {
            var jd = jdStart
            while jd <= jdEnd {
                let pos = calcPlanets(jd: jd).first { $0.planet == pl }
                let lon = pos?.eclipticLongitude ?? 0
                // Método 1: longitud = precio mod 360
                if abs(angleDiff(lon, targetDeg2)) < tolerance {
                    events.append(SquareOutEvent(
                        date: dateFromJD(jd), planet: pl.rawValue,
                        degrees: lon, label: "\(pl.symbol) en \(String(format:"%.1f°",lon))"))
                }
                jd += step
            }
        }
        return events.sorted { $0.date < $1.date }
    }

    // MARK: FC Calculator
    static func calculateFC(planet: Planet,
                              date1: Date, price1: Double,
                              date2: Date, price2: Double) -> FCResult {
        let jd1 = jdFromDate(date1)
        let jd2 = jdFromDate(date2)
        let pos1 = calcPlanets(jd: jd1).first { $0.planet == planet }
        let pos2 = calcPlanets(jd: jd2).first { $0.planet == planet }
        let lon1 = pos1?.eclipticLongitude ?? 0
        let lon2 = pos2?.eclipticLongitude ?? 0

        // Calcular delta acumulado (sin ambigüedad)
        var deltaDeg = 0.0
        let step = (jd2 - jd1) / 1000.0
        var prevLon = lon1
        var jd = jd1 + step
        while jd <= jd2 {
            let lon = calcPlanets(jd: jd).first { $0.planet == planet }?.eclipticLongitude ?? prevLon
            var diff = lon - prevLon
            if diff > 180  { diff -= 360 }
            if diff < -180 { diff += 360 }
            deltaDeg += diff
            prevLon = lon
            jd += step
        }

        let deltaPrice = abs(price2 - price1)
        let fc = abs(deltaDeg) > 0.001 ? deltaPrice / abs(deltaDeg) : 0

        return FCResult(fc: fc, deltaDeg: deltaDeg, deltaPriceAbs: deltaPrice,
                        planet: planet, date1: date1, date2: date2,
                        price1: price1, price2: price2, lon1: lon1, lon2: lon2)
    }

    // MARK: Estaciones Retrógradas
    static func findRetroStations(planet: Planet,
                                   startDate: Date,
                                   endDate: Date) -> [RetroStation] {
        guard planet != .sun && planet != .moon else { return [] }
        var stations: [RetroStation] = []
        let jdStart = jdFromDate(startDate)
        let jdEnd   = jdFromDate(endDate)
        let step = 0.5 // 12 horas

        var jd = jdStart
        var prevLon: Double? = nil
        var prevDiff: Double? = nil

        while jd <= jdEnd {
            let lon = calcPlanets(jd: jd).first { $0.planet == planet }?.eclipticLongitude ?? 0
            if let prev = prevLon {
                var diff = lon - prev
                if diff > 180  { diff -= 360 }
                if diff < -180 { diff += 360 }
                if let pd = prevDiff {
                    if pd >= 0 && diff < 0 {
                        stations.append(RetroStation(date: dateFromJD(jd - step/2),
                                                     type: .retro, longitude: lon, planet: planet))
                    } else if pd < 0 && diff >= 0 {
                        stations.append(RetroStation(date: dateFromJD(jd - step/2),
                                                     type: .direct, longitude: lon, planet: planet))
                    }
                }
                prevDiff = diff
            }
            prevLon = lon
            jd += step
        }

        // Retorno al punto retrógrado
        var i = 0
        while i < stations.count - 1 {
            if stations[i].type == .retro && stations[i+1].type == .direct {
                let retroLon = stations[i].longitude
                let jdDirectEnd = jdFromDate(stations[i+1].date)
                var jd2 = jdDirectEnd + step
                var pLon = stations[i+1].longitude
                while jd2 <= jdDirectEnd + 180 {
                    let cLon = calcPlanets(jd: jd2).first { $0.planet == planet }?.eclipticLongitude ?? pLon
                    var d = cLon - pLon
                    if d > 180 { d -= 360 }; if d < -180 { d += 360 }
                    if d > 0 {
                        var cross = cLon - retroLon; if cross > 180 { cross -= 360 }
                        var crossP = pLon - retroLon; if crossP > 180 { crossP -= 360 }
                        if crossP <= 0 && cross >= 0 {
                            stations.append(RetroStation(date: dateFromJD(jd2),
                                                         type: .returnRetro, longitude: retroLon, planet: planet))
                            break
                        }
                    }
                    pLon = cLon; jd2 += step
                }
            }
            i += 1
        }

        return stations.sorted { $0.date < $1.date }
    }

    // MARK: Bot FC (buscar mejor FC automáticamente)
    static func botFC(planet: Planet,
                       pricePoints: [(date: Date, price: Double)],
                       tolerance: Double = 0.05,
                       progress: @escaping (Double) -> Void) -> (bestFC: Double, bestR2: Double, results: [(fc: Double, r2: Double)]) {
        guard pricePoints.count >= 2 else { return (0, 0, []) }

        var fcCandidates: [(fc: Double, r2: Double)] = []
        let fcRange = stride(from: 0.01, through: 100.0, by: 0.25)
        let total = Double(Array(fcRange).count)
        var count = 0.0

        let jdStart = jdFromDate(pricePoints.first!.date)
        let firstPrice = pricePoints.first!.price

        for fc in fcRange {
            count += 1
            progress(count / total)

            // Generar wavy con este FC
            let config = WavyConfig(name: "test", planet: planet, fc: fc,
                                     direction: .suma, mode: .dinamico, hitoStep: 90,
                                     helio: false, startDate: pricePoints.first!.date,
                                     startPrice: firstPrice, color: "#fff")
            let wavyPts = computeSimpleWavy(config: config,
                                             endDate: pricePoints.last!.date,
                                             stepHours: 6)
            guard wavyPts.count >= 2 else { continue }

            // Correlación Pearson con los puntos reales
            var r2 = pearsonCorrelation(actual: pricePoints, wavy: wavyPts)
            fcCandidates.append((fc: fc, r2: r2))
        }

        let sorted = fcCandidates.sorted { $0.r2 > $1.r2 }
        let best = sorted.first ?? (fc: 1.0, r2: 0.0)
        return (best.fc, best.r2, Array(sorted.prefix(10)))
    }

    private static func pearsonCorrelation(actual: [(date: Date, price: Double)],
                                            wavy: [WavyPoint]) -> Double {
        guard actual.count >= 2 else { return 0 }
        var pairs: [(Double, Double)] = []
        for pt in actual {
            let jd = jdFromDate(pt.date)
            if let nearest = wavy.min(by: { abs($0.jd - jd) < abs($1.jd - jd) }) {
                pairs.append((pt.price, nearest.price))
            }
        }
        guard pairs.count >= 2 else { return 0 }
        let n = Double(pairs.count)
        let meanX = pairs.map(\.0).reduce(0,+)/n
        let meanY = pairs.map(\.1).reduce(0,+)/n
        let num = pairs.map { ($0.0-meanX)*($0.1-meanY) }.reduce(0,+)
        let denX = sqrt(pairs.map { pow($0.0-meanX,2) }.reduce(0,+))
        let denY = sqrt(pairs.map { pow($0.1-meanY,2) }.reduce(0,+))
        guard denX * denY > 0 else { return 0 }
        return num / (denX * denY)
    }

    // MARK: Paso mínimo por planeta
    static func planetMinStepHours(_ planet: Planet) -> Double {
        switch planet {
        case .moon:    return 1
        case .mercury, .venus, .sun: return 2
        case .mars:    return 6
        case .jupiter, .saturn: return 24
        case .uranus, .neptune: return 72
        }
    }
}

// MARK: - Gann Angles

struct GannAngle: Identifiable {
    let id = UUID()
    let ratio: Double      // grados por unidad (ej 1x1 = 45°)
    let label: String
    let startDate: Date
    let startPrice: Double
    let direction: Int     // +1 alcista, -1 bajista
    let color: String

    func priceAt(date: Date) -> Double {
        let days = date.timeIntervalSince(startDate) / 86400.0
        return startPrice + Double(direction) * ratio * days
    }
}

// MARK: - Price Bar (para gráfico)

struct PriceBar: Identifiable {
    let id = UUID()
    let date: Date
    let open, high, low, close: Double
    let volume: Double
}

// MARK: - CSV Parser

func parsePriceCSV(_ content: String) -> [PriceBar] {
    var bars: [PriceBar] = []
    let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
    guard lines.count > 1 else { return [] }

    let header = lines[0].lowercased().components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    let dateIdx  = header.firstIndex(where: { $0.contains("date") || $0.contains("time") }) ?? 0
    let openIdx  = header.firstIndex(where: { $0.contains("open") }) ?? 1
    let highIdx  = header.firstIndex(where: { $0.contains("high") }) ?? 2
    let lowIdx   = header.firstIndex(where: { $0.contains("low") }) ?? 3
    let closeIdx = header.firstIndex(where: { $0.contains("close") }) ?? 4
    let volIdx   = header.firstIndex(where: { $0.contains("vol") })

    let fmt = DateFormatter()
    for pattern in ["yyyy-MM-dd HH:mm:ss","yyyy-MM-dd HH:mm","yyyy-MM-dd","dd/MM/yyyy HH:mm","dd/MM/yyyy"] {
        fmt.dateFormat = pattern
    }

    let fmts = ["yyyy-MM-dd HH:mm:ss","yyyy-MM-dd HH:mm","yyyy-MM-dd",
                "dd/MM/yyyy HH:mm","dd/MM/yyyy","MM/dd/yyyy"]

    for line in lines.dropFirst() {
        let cols = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard cols.count > max(dateIdx, closeIdx) else { continue }

        var date: Date? = nil
        for pattern in fmts {
            fmt.dateFormat = pattern
            if let d = fmt.date(from: cols[dateIdx]) { date = d; break }
        }
        // Try timestamp
        if date == nil, let ts = Double(cols[dateIdx]) {
            date = Date(timeIntervalSince1970: ts)
        }
        guard let d = date else { continue }

        let o = Double(cols[safe: openIdx] ?? "") ?? 0
        let h = Double(cols[safe: highIdx] ?? "") ?? 0
        let l = Double(cols[safe: lowIdx] ?? "") ?? 0
        let c = Double(cols[safe: closeIdx] ?? "") ?? 0
        let v = Double(cols[safe: volIdx ?? -1] ?? "") ?? 0

        bars.append(PriceBar(date: d, open: o, high: h, low: l, close: c, volume: v))
    }
    return bars.sorted { $0.date < $1.date }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
