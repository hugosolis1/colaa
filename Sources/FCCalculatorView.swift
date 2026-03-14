// FCCalculatorView.swift + GannView.swift
// FC Calculator, Square of Nine, Square Out, Bot FC

import SwiftUI

// MARK: - FC Calculator

struct FCCalculatorView: View {
    @EnvironmentObject var appState: WavyAppState
    @Environment(\.dismiss) var dismiss

    @State private var planet: Planet = .moon
    @State private var date1 = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var date2 = Date()
    @State private var price1: Double = 100
    @State private var price2: Double = 110
    @State private var result: FCResult? = nil
    @State private var isCalculating = false

    // Bot FC
    @State private var showBot = false
    @State private var botProgress: Double = 0
    @State private var botResults: [(fc: Double, r2: Double)] = []
    @State private var bestFC: Double = 0
    @State private var isBotRunning = false

    var body: some View {
        NavigationView {
            ZStack {
                SpaceBackground()
                ScrollView {
                    VStack(spacing: 14) {

                        // — FC Manual —
                        FormCard(title: "FC CALCULATOR — 2 PUNTOS") {
                            VStack(spacing: 10) {
                                Picker("Planeta", selection: $planet) {
                                    ForEach(Planet.allCases) { pl in
                                        Text("\(pl.symbol) \(pl.rawValue)").tag(pl)
                                    }
                                }.pickerStyle(.menu).accentColor(.goldAccent)
                                    .background(Color.spaceMid.opacity(0.4)).cornerRadius(8)

                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("PUNTO 1").font(.system(size: 9, design: .monospaced)).foregroundColor(.goldAccent)
                                        DatePicker("", selection: $date1, displayedComponents: [.date, .hourAndMinute])
                                            .colorScheme(.dark).accentColor(.goldAccent).labelsHidden()
                                        HStack {
                                            Text("Precio:").font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
                                            TextField("100", value: $price1, format: .number)
                                                .keyboardType(.decimalPad).foregroundColor(.goldAccent)
                                                .frame(width: 80).padding(6)
                                                .background(Color.spaceDeep.opacity(0.6)).cornerRadius(6)
                                        }
                                    }
                                    Divider().background(Color.dimText.opacity(0.4))
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("PUNTO 2").font(.system(size: 9, design: .monospaced)).foregroundColor(.goldAccent)
                                        DatePicker("", selection: $date2, displayedComponents: [.date, .hourAndMinute])
                                            .colorScheme(.dark).accentColor(.goldAccent).labelsHidden()
                                        HStack {
                                            Text("Precio:").font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
                                            TextField("110", value: $price2, format: .number)
                                                .keyboardType(.decimalPad).foregroundColor(.goldAccent)
                                                .frame(width: 80).padding(6)
                                                .background(Color.spaceDeep.opacity(0.6)).cornerRadius(6)
                                        }
                                    }
                                }

                                Button(action: calculate) {
                                    HStack {
                                        if isCalculating { ProgressView().scaleEffect(0.7).tint(.spaceDark) }
                                        else { Image(systemName: "divide.circle") }
                                        Text(isCalculating ? "Calculando..." : "CALCULAR FC")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(Color.goldAccent).foregroundColor(.spaceDark).cornerRadius(10)
                                }
                                .disabled(isCalculating)
                            }
                        }

                        // — Resultado FC —
                        if let r = result {
                            FCResultView(result: r, onUseFC: { fc in
                                appState.fcResult = r
                                dismiss()
                            })
                        }

                        // — Bot FC —
                        FormCard(title: "BOT FC — BÚSQUEDA AUTOMÁTICA") {
                            VStack(spacing: 8) {
                                Text("Busca automáticamente el FC que mejor se correlaciona con los precios del CSV usando correlación de Pearson.")
                                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)

                                if appState.priceBars.isEmpty {
                                    Text("⚠️ Importa un CSV primero")
                                        .font(.system(size: 11, design: .monospaced)).foregroundColor(.red.opacity(0.8))
                                }

                                Button(action: runBot) {
                                    HStack {
                                        if isBotRunning {
                                            ProgressView(value: botProgress)
                                                .frame(width: 60)
                                                .tint(.spaceDark)
                                        } else {
                                            Image(systemName: "cpu")
                                        }
                                        Text(isBotRunning ? "Buscando \(Int(botProgress*100))%..." : "INICIAR BOT FC")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(appState.priceBars.isEmpty ? Color.dimText.opacity(0.3) : Color(hex:"4ECDC4"))
                                    .foregroundColor(.spaceDark).cornerRadius(10)
                                }
                                .disabled(appState.priceBars.isEmpty || isBotRunning)

                                if !botResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Top 10 FCs para \(planet.symbol) \(planet.rawValue):")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.goldAccent)
                                        ForEach(Array(botResults.prefix(10).enumerated()), id: \.offset) { i, r in
                                            HStack {
                                                Text("#\(i+1)").font(.system(size: 9, design: .monospaced)).foregroundColor(.dimText).frame(width: 24)
                                                Text(String(format: "FC = %.4f", r.fc))
                                                    .font(.system(size: 12, weight: i==0 ? .bold : .regular, design: .monospaced))
                                                    .foregroundColor(i==0 ? .goldAccent : .silverAccent)
                                                Spacer()
                                                Text(String(format: "r = %.4f", r.r2))
                                                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
                                                Button("↳ Usar") {
                                                    let fake = FCResult(fc: r.fc, deltaDeg: 0, deltaPriceAbs: 0,
                                                                        planet: planet, date1: date1, date2: date2,
                                                                        price1: price1, price2: price2, lon1: 0, lon2: 0)
                                                    appState.fcResult = fake
                                                }
                                                .font(.system(size: 9)).foregroundColor(.goldAccent)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.goldAccent.opacity(0.1)).cornerRadius(4)
                                            }
                                            .padding(.vertical, 2)
                                            if i == 0 { Divider().background(Color.goldAccent.opacity(0.3)) }
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.spaceDeep.opacity(0.6))
                                    .cornerRadius(8)
                                }
                            }
                        }

                        Spacer(minLength: 30)
                    }
                    .padding()
                }
            }
            .navigationTitle("FC Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") { dismiss() }.foregroundColor(.goldAccent)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    func calculate() {
        isCalculating = true
        let pl = planet; let d1 = date1; let d2 = date2; let p1 = price1; let p2 = price2
        DispatchQueue.global(qos: .userInitiated).async {
            let r = WavyEngine.calculateFC(planet: pl, date1: d1, price1: p1, date2: d2, price2: p2)
            DispatchQueue.main.async { result = r; isCalculating = false }
        }
    }

    func runBot() {
        guard !appState.priceBars.isEmpty else { return }
        isBotRunning = true; botResults = []
        let pts = appState.priceBars.map { (date: $0.date, price: $0.close) }
        let pl = planet
        DispatchQueue.global(qos: .userInitiated).async {
            let (best, r2, results) = WavyEngine.botFC(planet: pl, pricePoints: pts,
                progress: { p in DispatchQueue.main.async { self.botProgress = p } })
            DispatchQueue.main.async {
                self.bestFC = best
                self.botResults = results
                self.isBotRunning = false
            }
        }
    }
}

// MARK: - FC Result View

struct FCResultView: View {
    let result: FCResult
    let onUseFC: (Double) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("RESULTADO").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundColor(.goldAccent)
                Spacer()
                Text(result.planet.symbol + " " + result.planet.rawValue)
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
            }
            .padding(12)

            Divider().background(Color.goldAccent.opacity(0.2))

            VStack(spacing: 8) {
                // FC principal
                HStack {
                    Text("FC =")
                        .font(.system(size: 16, design: .monospaced)).foregroundColor(.dimText)
                    Text(String(format: "%.6f", result.fc))
                        .font(.system(size: 24, weight: .bold, design: .monospaced)).foregroundColor(.goldAccent)
                    Text("precio/°").font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                }
                .padding(.vertical, 8)

                InfoRow(label: "Δ Grados acumulados",
                        value: String(format: "%+.4f°", result.deltaDeg))
                InfoRow(label: "Δ Precio",
                        value: String(format: "%.4f", result.deltaPriceAbs))
                InfoRow(label: "Long. inicio \(result.planet.symbol)",
                        value: String(format: "%.4f°", result.lon1))
                InfoRow(label: "Long. fin \(result.planet.symbol)",
                        value: String(format: "%.4f°", result.lon2))

                Divider().background(Color.dimText.opacity(0.3))

                // Armónicos
                Text("Armónicos (×0.25 / ×0.5 / ×1 / ×2 / ×4):")
                    .font(.system(size: 9, design: .monospaced)).foregroundColor(.dimText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(result.harmonics, id: \.self) { h in
                            Button(action: { onUseFC(h) }) {
                                VStack(spacing: 2) {
                                    Text(String(format: "%.4f", h))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.goldAccent)
                                    Text("↳ Usar")
                                        .font(.system(size: 8, design: .monospaced)).foregroundColor(.dimText)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(h == result.fc ? Color.goldAccent.opacity(0.2) : Color.spaceMid.opacity(0.4))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(h == result.fc ? Color.goldAccent : Color.clear, lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color.spaceMid.opacity(0.4))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldAccent.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Gann View (Square of Nine + Square Out + Retro Stations)

struct GannView: View {
    @EnvironmentObject var appState: WavyAppState
    @State private var tab = 0

    var body: some View {
        NavigationView {
            ZStack {
                SpaceBackground()
                VStack(spacing: 0) {
                    Picker("", selection: $tab) {
                        Text("Square of 9").tag(0)
                        Text("Square Out").tag(1)
                        Text("Estaciones ℞").tag(2)
                    }.pickerStyle(.segmented).padding(.horizontal).padding(.top, 8)

                    Group {
                        switch tab {
                        case 0: SquareOfNineTab().environmentObject(appState)
                        case 1: SquareOutTab().environmentObject(appState)
                        default: RetroStationsTab().environmentObject(appState)
                        }
                    }
                }
            }
            .navigationTitle("Herramientas Gann")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Square of Nine Tab

struct SquareOfNineTab: View {
    @EnvironmentObject var appState: WavyAppState
    @State private var inputPrice: Double = 100
    @State private var numLevels: Int = 8

    var levels: [Sq9Level] { WavyEngine.squareOfNine(price: inputPrice, numLevels: numLevels) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                FormCard(title: "SQUARE OF NINE — GANN") {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Precio base:")
                                .font(.system(size: 12, design: .monospaced)).foregroundColor(.dimText)
                            TextField("100", value: $inputPrice, format: .number)
                                .keyboardType(.decimalPad).foregroundColor(.goldAccent)
                                .padding(8).background(Color.spaceDeep.opacity(0.6)).cornerRadius(8)
                        }

                        if !appState.priceBars.isEmpty {
                            Button("Usar precio actual (\(String(format:"%.4f", appState.priceBars.last?.close ?? 0)))") {
                                inputPrice = appState.priceBars.last?.close ?? inputPrice
                            }
                            .font(.system(size: 11, design: .monospaced)).foregroundColor(.goldAccent)
                        }

                        HStack {
                            Text("Niveles:").font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                            Stepper("\(numLevels)", value: $numLevels, in: 2...20)
                                .foregroundColor(.silverAccent)
                        }

                        Text("Fórmula: nivel_k = (√precio ± k×0.25)²")
                            .font(.system(size: 9, design: .monospaced)).foregroundColor(.dimText)
                    }
                }

                // Tabla de niveles
                if !levels.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text("NIVEL").frame(maxWidth: .infinity, alignment: .leading)
                            Text("EJE").frame(width: 80, alignment: .center)
                            Text("GRADO").frame(width: 60, alignment: .trailing)
                        }
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.goldAccent)
                        .padding(10)
                        .background(Color.spaceDeep.opacity(0.8))

                        Divider().background(Color.goldAccent.opacity(0.3))

                        ForEach(levels, id: \.price) { lvl in
                            let isBase = abs(lvl.price - inputPrice) < 0.001
                            HStack {
                                Text(String(format: "%.4f", lvl.price))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(isBase ? .goldAccent : .silverAccent)
                                    .fontWeight(isBase ? .bold : .regular)
                                Text(lvl.axis)
                                    .frame(width: 80, alignment: .center)
                                    .foregroundColor(axisColor(lvl.axis))
                                Text(String(format: "%.1f°", lvl.degree))
                                    .frame(width: 60, alignment: .trailing)
                                    .foregroundColor(.dimText)
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(isBase ? Color.goldAccent.opacity(0.1) : Color.clear)

                            Divider().background(Color.dimText.opacity(0.08))
                        }
                    }
                    .background(Color.spaceMid.opacity(0.4))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldAccent.opacity(0.15), lineWidth: 1))
                }

                Spacer(minLength: 30)
            }.padding()
        }
    }

    func axisColor(_ axis: String) -> Color {
        switch axis {
        case "0°/360°", "180°": return .red
        case "90°", "270°":     return .green
        case "45°", "135°", "225°", "315°": return .yellow
        default: return .silverAccent
        }
    }
}

// MARK: - Square Out Tab

struct SquareOutTab: View {
    @EnvironmentObject var appState: WavyAppState
    @State private var inputPrice: Double = 100
    @State private var selectedPlanets: Set<Planet> = [.sun, .moon, .mercury, .venus, .mars]
    @State private var searchStart = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var searchEnd   = Calendar.current.date(byAdding: .month, value:  6, to: Date()) ?? Date()
    @State private var events: [SquareOutEvent] = []
    @State private var isSearching = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                FormCard(title: "SQUARE OUT — PRECIO → FECHA") {
                    VStack(spacing: 10) {
                        Text("Busca cuándo la longitud planetaria coincide con el precio (en grados). Técnica de Gann.")
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)

                        HStack {
                            Text("Precio:")
                                .font(.system(size: 12, design: .monospaced)).foregroundColor(.dimText)
                            TextField("100", value: $inputPrice, format: .number)
                                .keyboardType(.decimalPad).foregroundColor(.goldAccent)
                                .padding(8).background(Color.spaceDeep.opacity(0.6)).cornerRadius(8)
                        }

                        DateTimePicker(title: "Desde", date: $searchStart)
                        DateTimePicker(title: "Hasta", date: $searchEnd)

                        // Selector de planetas
                        PlanetMultiPicker(selected: $selectedPlanets)

                        Button(action: search) {
                            HStack {
                                if isSearching { ProgressView().scaleEffect(0.7).tint(.spaceDark) }
                                else { Image(systemName: "magnifyingglass") }
                                Text(isSearching ? "Buscando..." : "BUSCAR SQUARE OUT")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(Color(hex: "4ECDC4")).foregroundColor(.spaceDark).cornerRadius(10)
                        }.disabled(isSearching || selectedPlanets.isEmpty)
                    }
                }

                if !events.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "\(events.count) eventos Square Out para \(String(format:"%.2f",inputPrice))")
                            .padding(.horizontal, 4)

                        ForEach(events, id: \.date) { evt in
                            HStack(spacing: 10) {
                                Text(Planet.allCases.first { $0.rawValue == evt.planet }?.symbol ?? "●")
                                    .font(.system(size: 18))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(medDateFmt.string(from: evt.date))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.goldAccent)
                                    Text(evt.label)
                                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
                                }
                                Spacer()
                                Text(String(format: "%.2f°", evt.degrees))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.silverAccent)
                            }
                            .padding(10)
                            .background(Color.spaceMid.opacity(0.4))
                            .cornerRadius(8)
                        }
                    }
                }

                Spacer(minLength: 30)
            }.padding()
        }
    }

    func search() {
        isSearching = true
        let price = inputPrice
        let planets = Array(selectedPlanets)
        let start = searchStart, end = searchEnd
        DispatchQueue.global(qos: .userInitiated).async {
            let evts = WavyEngine.squareOut(price: price, planets: planets,
                                             startDate: start, endDate: end)
            DispatchQueue.main.async { events = evts; isSearching = false }
        }
    }
}

// MARK: - Retro Stations Tab

struct RetroStationsTab: View {
    @EnvironmentObject var appState: WavyAppState
    @State private var selectedPlanets: Set<Planet> = [.mercury, .venus, .mars, .jupiter, .saturn]
    @State private var months: Int = 12
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                FormCard(title: "ESTACIONES RETRÓGRADAS") {
                    VStack(spacing: 10) {
                        Text("Detecta estaciones R (D→R), D (R→D) y retorno al punto retrógrado.\nEstas son las fechas clave de reversión según Jenkins.")
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)

                        PlanetMultiPicker(selected: $selectedPlanets)

                        HStack {
                            Text("Rango: ±").font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                            Stepper("\(months) meses", value: $months, in: 3...36)
                                .foregroundColor(.silverAccent)
                        }

                        Button(action: load) {
                            HStack {
                                if isLoading { ProgressView().scaleEffect(0.7).tint(.spaceDark) }
                                else { Image(systemName: "arrow.counterclockwise") }
                                Text(isLoading ? "Calculando..." : "CALCULAR ESTACIONES")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(Color(hex: "FF6B6B")).foregroundColor(.white).cornerRadius(10)
                        }
                        .disabled(isLoading || selectedPlanets.isEmpty)
                    }
                }

                if !appState.retroStations.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "\(appState.retroStations.count) estaciones detectadas")
                            .padding(.horizontal, 4)

                        ForEach(appState.retroStations) { st in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: st.type.color))
                                    .frame(width: 8, height: 8)
                                Text(st.type.symbol)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: st.type.color))
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(medDateFmt.string(from: st.date))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.silverAccent)
                                    Text("\(st.planet.symbol) \(st.planet.rawValue) · \(st.type.rawValue)")
                                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.dimText)
                                }
                                Spacer()
                                Text(String(format: "%.2f°", st.longitude))
                                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.goldAccent)
                            }
                            .padding(10)
                            .background(Color.spaceMid.opacity(0.3))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: st.type.color).opacity(0.3), lineWidth: 1))
                        }
                    }
                }

                Spacer(minLength: 30)
            }.padding()
        }
        .onChange(of: appState.retroStations.count) { _ in isLoading = false }
    }

    func load() {
        isLoading = true
        appState.loadRetroStations(for: Array(selectedPlanets), months: months)
    }
}
