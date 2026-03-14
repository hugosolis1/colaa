// DegreesView.swift — Tab 2: Grados recorridos entre dos fechas
import SwiftUI

struct TravelRow: Identifiable {
    var id: String { result.planet.rawValue }
    let result: TravelResult
}

class DegreesViewModel: ObservableObject {
    @Published var dateStart = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var dateEnd   = Date()
    @Published var results: [TravelRow] = []
    @Published var isLoading = false
    @Published var selectedPlanets: Set<Planet> = Set(Planet.allCases)
    @Published var resolution: Int = 1440   // steps

    func calculate() {
        isLoading = true
        let jd1 = jdFromDate(dateStart)
        let jd2 = jdFromDate(dateEnd)
        let planets = Array(selectedPlanets)
        let steps = resolution
        DispatchQueue.global(qos: .userInitiated).async {
            var rows: [TravelRow] = []
            for pl in Planet.allCases where planets.contains(pl) {
                let r = degreesTraversed(planet: pl, jdStart: jd1, jdEnd: jd2, steps: steps)
                rows.append(TravelRow(result: r))
            }
            DispatchQueue.main.async {
                self.results = rows
                self.isLoading = false
            }
        }
    }
}

struct DegreesView: View {
    @StateObject private var vm = DegreesViewModel()
    @State private var showPlanetPicker = false

    var daysSpan: Double { abs(jdFromDate(vm.dateEnd) - jdFromDate(vm.dateStart)) }

    var body: some View {
        NavigationView {
            ZStack {
                SpaceBackground()
                ScrollView {
                    VStack(spacing: 16) {

                        // — Rango de fechas —
                        VStack(spacing: 10) {
                            DateTimePicker(title: "Fecha Inicio", date: $vm.dateStart)
                            DateTimePicker(title: "Fecha Fin",    date: $vm.dateEnd)

                            // Span info
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.goldAccent)
                                Text(String(format: "Período: %.1f días (%.2f años)", daysSpan, daysSpan/365.25))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.silverAccent)
                                Spacer()
                            }
                            .padding(.horizontal, 4)

                            // Resolución
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Resolución de cálculo")
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                                Picker("Resolución", selection: $vm.resolution) {
                                    Text("Baja (cada 1 día)").tag(Int(daysSpan))
                                    Text("Media (cada 1 hora)").tag(Int(daysSpan*24))
                                    Text("Alta (cada 10 min)").tag(Int(daysSpan*144))
                                    Text("Máxima (cada 1 min)").tag(Int(daysSpan*1440))
                                }
                                .pickerStyle(.menu)
                                .accentColor(.goldAccent)
                                .background(Color.spaceMid.opacity(0.5))
                                .cornerRadius(8)
                            }
                            .padding(12)
                            .background(Color.spaceMid.opacity(0.4))
                            .cornerRadius(10)

                            // Selector de planetas
                            Button(action: { showPlanetPicker.toggle() }) {
                                HStack {
                                    Image(systemName: "checklist")
                                    Text("Planetas: \(vm.selectedPlanets.count)/\(Planet.allCases.count)")
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    Spacer()
                                    Image(systemName: showPlanetPicker ? "chevron.up" : "chevron.down")
                                }
                                .foregroundColor(.goldAccent)
                                .padding(10)
                                .background(Color.spaceMid.opacity(0.5))
                                .cornerRadius(8)
                            }

                            if showPlanetPicker {
                                PlanetMultiPicker(selected: $vm.selectedPlanets)
                            }

                            CalcButton(title: "Calcular Recorridos", action: vm.calculate, isLoading: vm.isLoading)
                        }
                        .padding(.horizontal)

                        // — Resultados —
                        if !vm.results.isEmpty {
                            VStack(spacing: 8) {
                                SectionHeader(title: "Grados Recorridos").padding(.horizontal)
                                ForEach(vm.results) { row in
                                    TravelCard(row: row)
                                }
                            }
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Grados Recorridos")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: .constant(false)) {}
    }
}

struct TravelCard: View {
    let row: TravelRow
    @State private var expanded = false

    var r: TravelResult { row.result }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { expanded.toggle() } }) {
                HStack(spacing: 12) {
                    PlanetBadge(planet: r.planet, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.planet.rawValue).font(.system(size: 15, weight: .semibold)).foregroundColor(.silverAccent)
                        Text(String(format: "Total: %+.4f°", r.totalTravel))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(r.totalTravel >= 0 ? .green : .red)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f°", abs(r.totalTravel)))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.goldAccent)
                        Text(String(format: "%.1f siglos", abs(r.totalTravel)/360))
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
                    }
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().background(Color.goldAccent.opacity(0.2))
                VStack(spacing: 6) {
                    InfoRow(label: "Longitud inicial", value: lonStr(r.lonStart))
                    InfoRow(label: "Longitud final",   value: lonStr(r.lonEnd))
                    InfoRow(label: "Recorrido total",  value: String(format: "%+.6f°", r.totalTravel), highlight: true)
                    InfoRow(label: "Recorrido directo",value: String(format: "%+.4f°", r.directTravel))
                    InfoRow(label: "Recorrido ℞",      value: String(format: "%+.4f°", r.retroTravel))
                    InfoRow(label: "Estaciones (D↔R)", value: "\(r.stationCount)")
                    Divider().background(Color.dimText.opacity(0.3))
                    InfoRow(label: "Vueltas completas",value: String(format: "%.4f", abs(r.totalTravel)/360))
                    InfoRow(label: "Grados/día",       value: {
                        let days = abs(jdFromDate(Date()) - jdFromDate(Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()))
                        return String(format: "%.6f°/día", abs(r.totalTravel) / max(days, 1))
                    }())
                }
                .padding(12)
            }
        }
        .background(Color.spaceMid.opacity(0.5))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(r.planet.swiftUIColor.opacity(0.35), lineWidth: 1))
    }
}

struct PlanetMultiPicker: View {
    @Binding var selected: Set<Planet>
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button("Todo") { selected = Set(Planet.allCases) }
                    .font(.system(size: 11)).foregroundColor(.goldAccent)
                Spacer()
                Button("Nada") { selected.removeAll() }
                    .font(.system(size: 11)).foregroundColor(.dimText)
            }
            .padding(.horizontal, 4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(Planet.allCases) { pl in
                    let sel = selected.contains(pl)
                    Button(action: {
                        if sel { selected.remove(pl) } else { selected.insert(pl) }
                    }) {
                        HStack(spacing: 6) {
                            Text(pl.symbol).font(.system(size: 14))
                            Text(pl.rawValue).font(.system(size: 11)).lineLimit(1)
                        }
                        .padding(.vertical, 6).padding(.horizontal, 8)
                        .background(sel ? pl.swiftUIColor.opacity(0.25) : Color.spaceDark.opacity(0.5))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(sel ? pl.swiftUIColor : Color.dimText.opacity(0.3), lineWidth: 1))
                        .foregroundColor(sel ? pl.swiftUIColor : .dimText)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.spaceDeep.opacity(0.8))
        .cornerRadius(10)
    }
}
