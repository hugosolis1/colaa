// SearchView.swift — Tab 4: Búsqueda de posiciones específicas
import SwiftUI

enum SearchMode: String, CaseIterable, Identifiable {
    case planetAtDegree   = "Planeta en grado"
    case planetPairAngle  = "Par de planetas en ángulo"
    case multiPlanetDegree = "Varios planetas en grados"
    var id: String { rawValue }
}

class SearchViewModel: ObservableObject {
    @Published var mode: SearchMode = .planetAtDegree
    // Rango de búsqueda
    @Published var searchStart = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @Published var searchEnd   = Calendar.current.date(byAdding: .year, value:  1, to: Date()) ?? Date()
    // Modo 1: planeta en grado
    @Published var targetPlanet: Planet = .sun
    @Published var targetDegree: Double = 0    // 0-360
    @Published var tolerance: Double = 0.25
    // Modo 2: par en ángulo
    @Published var planet1: Planet = .sun
    @Published var planet2: Planet = .moon
    @Published var targetAngle: Double = 0
    @Published var angleTolerance: Double = 1.0
    // Modo 3: múltiples planetas en sus grados
    @Published var multiTargets: [PlanetTarget] = [PlanetTarget(planet: .sun, degree: 0)]
    @Published var multiTolerance: Double = 1.0

    @Published var results: [SearchResult] = []
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var errorMsg: String? = nil

    func calculate() {
        errorMsg = nil
        let jd1 = jdFromDate(searchStart)
        let jd2 = jdFromDate(searchEnd)
        guard jd2 > jd1 else { errorMsg = "La fecha fin debe ser posterior a la de inicio."; return }
        let span = jd2 - jd1
        guard span <= 365*50 else { errorMsg = "Rango máximo: 50 años por búsqueda."; return }

        isLoading = true; results = []; progress = 0

        switch mode {
        case .planetAtDegree:
            let pl = targetPlanet; let deg = targetDegree; let tol = tolerance
            DispatchQueue.global(qos: .userInitiated).async {
                let res = searchPlanetAtDegree(planet: pl, targetLon: deg,
                                               jdStart: jd1, jdEnd: jd2, tolerance: tol)
                DispatchQueue.main.async { self.results = res; self.isLoading = false }
            }

        case .planetPairAngle:
            let p1=planet1, p2=planet2, ang=targetAngle, tol=angleTolerance
            DispatchQueue.global(qos: .userInitiated).async {
                let res = searchPlanetsAtAngle(p1: p1, p2: p2, targetAngle: ang,
                                               jdStart: jd1, jdEnd: jd2, tolerance: tol)
                DispatchQueue.main.async { self.results = res; self.isLoading = false }
            }

        case .multiPlanetDegree:
            let targets = multiTargets; let tol = multiTolerance
            DispatchQueue.global(qos: .userInitiated).async {
                var candidates: [SearchResult] = []
                // Buscar cuándo cada planeta está en su grado
                for t in targets {
                    let r = searchPlanetAtDegree(planet: t.planet, targetLon: t.degree,
                                                 jdStart: jd1, jdEnd: jd2, tolerance: tol * 3)
                    candidates.append(contentsOf: r)
                }
                // Filtrar momentos donde TODOS están simultáneamente en sus grados
                var combined: [SearchResult] = []
                for candidate in candidates {
                    let pos = calcPlanets(jd: candidate.jd)
                    var allMatch = true
                    for t in targets {
                        let lon = pos.first(where:{$0.planet==t.planet})?.eclipticLongitude ?? 999
                        var diff = lon - t.degree; if diff>180{diff-=360}; if diff < -180{diff+=360}
                        if abs(diff) > tol { allMatch = false; break }
                    }
                    if allMatch {
                        if combined.isEmpty || abs(candidate.jd - (combined.last?.jd ?? 0)) > 0.3 {
                            combined.append(candidate)
                        }
                    }
                }
                DispatchQueue.main.async { self.results = combined; self.isLoading = false }
            }
        }
    }
}

struct PlanetTarget: Identifiable {
    let id = UUID()
    var planet: Planet
    var degree: Double
}

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                SpaceBackground()
                ScrollView {
                    VStack(spacing: 16) {

                        // — Modo de búsqueda —
                        VStack(spacing: 10) {
                            SectionHeader(title: "Tipo de Búsqueda")
                            Picker("Modo", selection: $vm.mode) {
                                ForEach(SearchMode.allCases) { m in
                                    Text(m.rawValue).tag(m)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(.goldAccent)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(Color.spaceMid.opacity(0.5))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)

                        // — Rango de fechas —
                        VStack(spacing: 8) {
                            SectionHeader(title: "Rango de Búsqueda")
                            DateTimePicker(title: "Desde", date: $vm.searchStart)
                            DateTimePicker(title: "Hasta", date: $vm.searchEnd)
                            Text("Rango: \(String(format: "%.1f años", abs(jdFromDate(vm.searchEnd)-jdFromDate(vm.searchStart))/365.25))")
                                .font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.horizontal)

                        // — Parámetros según modo —
                        Group {
                            switch vm.mode {
                            case .planetAtDegree:
                                SinglePlanetSearchParams(vm: vm)
                            case .planetPairAngle:
                                PairAngleSearchParams(vm: vm)
                            case .multiPlanetDegree:
                                MultiPlanetSearchParams(vm: vm)
                            }
                        }
                        .padding(.horizontal)

                        // — Botón calcular —
                        VStack(spacing: 8) {
                            if let err = vm.errorMsg {
                                Text(err).font(.system(size: 12)).foregroundColor(.red)
                                    .padding(8).background(Color.red.opacity(0.1)).cornerRadius(6)
                            }
                            CalcButton(title: "Buscar", action: vm.calculate, isLoading: vm.isLoading)
                        }
                        .padding(.horizontal)

                        // — Resultados —
                        if !vm.results.isEmpty {
                            VStack(spacing: 8) {
                                SectionHeader(title: "\(vm.results.count) resultado(s) encontrado(s)").padding(.horizontal)
                                ForEach(Array(vm.results.enumerated()), id: \.offset) { i, r in
                                    SearchResultCard(result: r, index: i+1, mode: vm.mode, vm: vm)
                                        .padding(.horizontal)
                                }
                            }
                        } else if !vm.isLoading && vm.errorMsg == nil {
                            Text("Sin resultados todavía. Ajusta los parámetros y pulsa Buscar.")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.dimText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Búsqueda Planetaria")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Params for mode 1

struct SinglePlanetSearchParams: View {
    @ObservedObject var vm: SearchViewModel
    var body: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Parámetros")
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Planeta").font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                    Picker("", selection: $vm.targetPlanet) {
                        ForEach(Planet.allCases.filter{$0 != .sun}.prefix(7)) { pl in
                            HStack { Text(pl.symbol); Text(pl.rawValue) }.tag(pl)
                        }
                        HStack { Text(Planet.sun.symbol); Text(Planet.sun.rawValue) }.tag(Planet.sun)
                    }
                    .pickerStyle(.menu).accentColor(.goldAccent)
                    .background(Color.spaceMid.opacity(0.5)).cornerRadius(8)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grado objetivo (0-360°)").font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                    HStack {
                        TextField("0.00", value: $vm.targetDegree, format: .number)
                            .font(.system(size: 14, design: .monospaced))
                            .keyboardType(.decimalPad)
                            .padding(8)
                            .background(Color.spaceMid.opacity(0.5))
                            .cornerRadius(8)
                            .foregroundColor(.goldAccent)
                        Text("°").foregroundColor(.dimText)
                    }
                }
            }
            .padding(12).background(Color.spaceDeep.opacity(0.6)).cornerRadius(10)

            // Zodiac helper
            ZodiacDegreeHelper(degree: $vm.targetDegree)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tolerancia: ±\(String(format: "%.2f", vm.tolerance))°").font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                Slider(value: $vm.tolerance, in: 0.01...2.0, step: 0.01).accentColor(.goldAccent)
            }
            .padding(12).background(Color.spaceMid.opacity(0.4)).cornerRadius(8)
        }
    }
}

// MARK: - Params for mode 2

struct PairAngleSearchParams: View {
    @ObservedObject var vm: SearchViewModel
    var body: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Parámetros")
            HStack(spacing: 12) {
                PlanetPicker(label: "Planeta 1", selection: $vm.planet1)
                PlanetPicker(label: "Planeta 2", selection: $vm.planet2)
            }
            .padding(12).background(Color.spaceDeep.opacity(0.6)).cornerRadius(10)

            VStack(alignment: .leading, spacing: 6) {
                Text("Ángulo objetivo entre planetas").font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                HStack {
                    TextField("90.00", value: $vm.targetAngle, format: .number)
                        .font(.system(size: 14, design: .monospaced))
                        .keyboardType(.decimalPad)
                        .padding(8)
                        .background(Color.spaceMid.opacity(0.5))
                        .cornerRadius(8)
                        .foregroundColor(.goldAccent)
                    Text("°").foregroundColor(.dimText)
                }
                // Botones de aspectos comunes
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([0,30,45,60,90,120,135,150,180], id:\.self) { a in
                            Button(action: { vm.targetAngle = Double(a) }) {
                                Text("\(a)°").font(.system(size: 11, design: .monospaced))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(vm.targetAngle == Double(a) ? Color.goldAccent : Color.spaceMid.opacity(0.5))
                                    .foregroundColor(vm.targetAngle == Double(a) ? .spaceDark : .silverAccent)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            .padding(12).background(Color.spaceMid.opacity(0.4)).cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tolerancia: ±\(String(format: "%.1f", vm.angleTolerance))°").font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                Slider(value: $vm.angleTolerance, in: 0.1...5.0, step: 0.1).accentColor(.goldAccent)
            }
            .padding(12).background(Color.spaceMid.opacity(0.4)).cornerRadius(8)
        }
    }
}

// MARK: - Params for mode 3

struct MultiPlanetSearchParams: View {
    @ObservedObject var vm: SearchViewModel
    var body: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Planetas y Grados Objetivo")

            ForEach(vm.multiTargets.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    PlanetPicker(label: "", selection: $vm.multiTargets[i].planet)
                    HStack {
                        TextField("0", value: $vm.multiTargets[i].degree, format: .number)
                            .font(.system(size: 13, design: .monospaced))
                            .keyboardType(.decimalPad)
                            .padding(8)
                            .background(Color.spaceMid.opacity(0.5))
                            .cornerRadius(8)
                            .foregroundColor(.goldAccent)
                        Text("°").foregroundColor(.dimText)
                    }
                    if vm.multiTargets.count > 1 {
                        Button(action: { vm.multiTargets.remove(at: i) }) {
                            Image(systemName: "minus.circle.fill").foregroundColor(.red)
                        }
                    }
                }
                .padding(8).background(Color.spaceDeep.opacity(0.6)).cornerRadius(8)
            }

            Button(action: { vm.multiTargets.append(PlanetTarget(planet: .mars, degree: 0)) }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Añadir planeta")
                }
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.goldAccent)
                .padding(8).background(Color.spaceMid.opacity(0.3)).cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tolerancia: ±\(String(format: "%.2f", vm.multiTolerance))° por planeta").font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                Slider(value: $vm.multiTolerance, in: 0.1...5.0, step: 0.1).accentColor(.goldAccent)
            }
            .padding(12).background(Color.spaceMid.opacity(0.4)).cornerRadius(8)
        }
    }
}

// MARK: - Result card

struct SearchResultCard: View {
    let result: SearchResult
    let index: Int
    let mode: SearchMode
    @ObservedObject var vm: SearchViewModel
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3)) { expanded.toggle() } }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.goldAccent.opacity(0.2)).frame(width: 32, height: 32)
                        Text("\(index)").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.goldAccent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fullDateFormatter.string(from: result.date))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.goldAccent)
                        if mode == .planetAtDegree {
                            HStack(spacing: 4) {
                                Text(result.planet.symbol)
                                Text(lonStr(result.longitude))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.silverAccent)
                                if result.retrograde {
                                    Text("℞").font(.system(size: 10)).foregroundColor(.red)
                                }
                            }
                        } else if mode == .planetPairAngle {
                            Text(String(format: "%@ — %@  Δ=%.4f°", vm.planet1.symbol, vm.planet2.symbol, result.longitude))
                                .font(.system(size: 11, design: .monospaced)).foregroundColor(.silverAccent)
                        } else {
                            Text("Todos los planetas en rango objetivo")
                                .font(.system(size: 11, design: .monospaced)).foregroundColor(.silverAccent)
                        }
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11)).foregroundColor(.dimText)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().background(Color.goldAccent.opacity(0.2))
                let pos = calcPlanets(jd: result.jd)
                VStack(spacing: 5) {
                    InfoRow(label: "Día Juliano", value: String(format: "%.6f", result.jd))
                    InfoRow(label: "Fecha y hora UT", value: fullDateFormatter.string(from: result.date))
                    Divider().background(Color.dimText.opacity(0.3))
                    ForEach(pos) { p in
                        HStack {
                            Text("\(p.planet.symbol) \(p.planet.rawValue)")
                                .font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                            Spacer()
                            Text(lonStr(p.eclipticLongitude))
                                .font(.system(size: 11, design: .monospaced)).foregroundColor(.silverAccent)
                            if p.retrograde { Text("℞").font(.system(size: 10)).foregroundColor(.red) }
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color.spaceMid.opacity(0.5))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldAccent.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Helpers

struct PlanetPicker: View {
    let label: String
    @Binding var selection: Planet
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label).font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
            }
            Picker("", selection: $selection) {
                ForEach(Planet.allCases) { pl in
                    HStack { Text(pl.symbol); Text(pl.rawValue) }.tag(pl)
                }
            }
            .pickerStyle(.menu).accentColor(.goldAccent)
            .background(Color.spaceMid.opacity(0.5)).cornerRadius(8)
        }
    }
}

struct ZodiacDegreeHelper: View {
    @Binding var degree: Double
    @State private var selectedSign = 0
    @State private var signDeg: Double = 0
    @State private var signMin: Double = 0

    let signs = ["♈Aries","♉Tauro","♊Géminis","♋Cáncer","♌Leo","♍Virgo",
                 "♎Libra","♏Escorpio","♐Sagitario","♑Capricornio","♒Acuario","♓Piscis"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("O ingresa por signo zodiacal:")
                .font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
            HStack(spacing: 8) {
                Picker("", selection: $selectedSign) {
                    ForEach(0..<12) { Text(signs[$0]).tag($0) }
                }
                .pickerStyle(.menu).accentColor(.goldAccent)
                .background(Color.spaceMid.opacity(0.5)).cornerRadius(8)

                HStack(spacing: 2) {
                    TextField("0", value: $signDeg, format: .number)
                        .frame(width: 40).keyboardType(.decimalPad)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(6).background(Color.spaceMid.opacity(0.5)).cornerRadius(6)
                        .foregroundColor(.goldAccent)
                    Text("°").foregroundColor(.dimText)
                    TextField("00", value: $signMin, format: .number)
                        .frame(width: 36).keyboardType(.decimalPad)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(6).background(Color.spaceMid.opacity(0.5)).cornerRadius(6)
                        .foregroundColor(.goldAccent)
                    Text("'").foregroundColor(.dimText)
                }

                Button("↵") {
                    degree = norm360(Double(selectedSign)*30 + min(signDeg,29.999) + signMin/60)
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.spaceDark)
                .frame(width: 32, height: 32)
                .background(Color.goldAccent)
                .cornerRadius(8)
            }
        }
        .padding(10)
        .background(Color.spaceDeep.opacity(0.6))
        .cornerRadius(8)
    }
}
