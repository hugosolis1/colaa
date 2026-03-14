// PositionsView.swift — Tab 1: Posiciones planetarias + modo Helio/Geo
import SwiftUI

class PositionsViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var positions: [PlanetPosition] = []
    @Published var julianDay: Double = 0
    @Published var gmst: Double = 0
    @Published var isLoading = false
    @Published var selectedPlanet: PlanetPosition? = nil
    @Published var viewMode: ViewMode = .geocentric

    var tz: Double { AppState.shared.timezone }

    init() { calculate() }

    func calculate() {
        isLoading = true
        let d = selectedDate, tz = self.tz, mode = viewMode
        DispatchQueue.global(qos: .userInitiated).async {
            let jdUT = jdFromDate(d)
            let T = (jdUT - 2451545.0) / 36525.0
            let g = norm360(280.46061837 + 360.98564736629*(jdUT-2451545.0) + 0.000387933*T*T - T*T*T/38710000)
            let res = calcPlanets(jd: jdUT, mode: mode)
            DispatchQueue.main.async {
                self.positions = res
                self.julianDay = jdUT
                self.gmst = g
                self.isLoading = false
            }
        }
    }
}

struct PositionsView: View {
    @StateObject private var vm = PositionsViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                SpaceBackground()
                ScrollView {
                    VStack(spacing: 16) {

                        // — Controles —
                        VStack(spacing: 10) {
                            DateTimePicker(title: "Fecha y Hora", date: $vm.selectedDate)
                            TimezoneRow()

                            // Selector Geo / Helio
                            HStack(spacing: 0) {
                                ForEach(ViewMode.allCases, id: \.rawValue) { mode in
                                    Button(action: {
                                        vm.viewMode = mode
                                        vm.calculate()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: mode == .geocentric ? "globe" : "sun.max")
                                            Text(mode.rawValue)
                                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        }
                                        .frame(maxWidth: .infinity).frame(height: 38)
                                        .background(vm.viewMode == mode ? Color.goldAccent : Color.spaceMid.opacity(0.5))
                                        .foregroundColor(vm.viewMode == mode ? .spaceDark : .dimText)
                                    }
                                }
                            }
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldAccent.opacity(0.3), lineWidth: 1))

                            CalcButton(title: "Calcular Posiciones", action: vm.calculate, isLoading: vm.isLoading)
                        }
                        .padding(.horizontal)

                        // — Modo actual —
                        if !vm.positions.isEmpty {
                            HStack {
                                Image(systemName: vm.viewMode == .geocentric ? "globe" : "sun.max")
                                    .foregroundColor(.goldAccent)
                                Text(vm.viewMode == .geocentric
                                     ? "Vista desde la Tierra (Geocéntrico)"
                                     : "Vista desde el Sol (Heliocéntrico)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.dimText)
                                Spacer()
                            }
                            .padding(.horizontal)

                            // — Datos técnicos —
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Día Juliano").font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
                                    Text(String(format: "%.6f", vm.julianDay))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.goldAccent)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("T.S. Greenwich").font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
                                    Text(String(format: "%.4f°", vm.gmst))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.silverAccent)
                                }
                            }
                            .padding(12)
                            .background(Color.spaceMid.opacity(0.5))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldAccent.opacity(0.15), lineWidth: 1))
                            .padding(.horizontal)

                            // — Lista planetas —
                            VStack(spacing: 8) {
                                ForEach(vm.positions) { pos in
                                    PlanetCard(pos: pos, mode: vm.viewMode)
                                        .onTapGesture {
                                            vm.selectedPlanet = (vm.selectedPlanet?.planet == pos.planet) ? nil : pos
                                        }
                                    if vm.selectedPlanet?.planet == pos.planet {
                                        PlanetDetail(pos: pos, mode: vm.viewMode)
                                            .transition(.asymmetric(
                                                insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
                                                removal: .opacity))
                                    }
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.selectedPlanet?.planet)
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Posiciones Planetarias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ahora") { vm.selectedDate = Date(); vm.calculate() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.goldAccent)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct PlanetCard: View {
    let pos: PlanetPosition
    let mode: ViewMode

    var body: some View {
        HStack(spacing: 12) {
            PlanetBadge(planet: pos.planet, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(pos.planet.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.silverAccent)
                    if pos.retrograde && mode == .geocentric {
                        Text("℞").font(.system(size: 12, weight: .bold)).foregroundColor(.red)
                    }
                    if mode == .heliocentric {
                        Text("HELIO").font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color.goldAccent.opacity(0.2))
                            .foregroundColor(.goldAccent)
                            .cornerRadius(4)
                    }
                }
                Text(lonStr(pos.eclipticLongitude))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.goldAccent)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(pos.zodiacSign)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.dimText)
                Text(String(format: "%.4f°", pos.eclipticLongitude))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.silverAccent)
            }
        }
        .padding(12)
        .background(Color.spaceMid.opacity(0.5))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pos.planet.swiftUIColor.opacity(0.35), lineWidth: 1))
    }
}

struct PlanetDetail: View {
    let pos: PlanetPosition
    let mode: ViewMode

    var distLabel: String {
        pos.planet == .moon ? "Distancia (UA)" : "Dist. Geocéntrica (UA)"
    }
    var distValue: String {
        if pos.planet == .moon {
            return String(format: "%.0f km / %.6f UA", pos.geocentricDistance * 149597870.7, pos.geocentricDistance)
        }
        return String(format: "%.8f UA", pos.geocentricDistance)
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Color.goldAccent.opacity(0.2))
            VStack(spacing: 6) {
                Group {
                    InfoRow(label: mode == .heliocentric ? "Long. Heliocéntrica" : "Long. Eclíptica (geo)",
                            value: String(format: "%.6f°", pos.eclipticLongitude), highlight: true)
                    InfoRow(label: "Latitud Eclíptica",   value: String(format: "%.6f°", pos.eclipticLatitude))
                    InfoRow(label: "Longitud Zodiacal",   value: lonStr(pos.eclipticLongitude), highlight: true)
                    InfoRow(label: "Grado en signo",      value: String(format: "%.4f° de %@", pos.zodiacDegree, pos.zodiacSign))
                }
                Divider().background(Color.dimText.opacity(0.3))
                Group {
                    InfoRow(label: "Ascensión Recta",     value: raStr(pos.rightAscension))
                    InfoRow(label: "Declinación",         value: dmsStr(pos.declination))
                    if mode == .geocentric {
                        InfoRow(label: "Long. Heliocéntrica", value: String(format: "%.6f°", pos.helioLongitude))
                        InfoRow(label: "Lat. Heliocéntrica",  value: String(format: "%.6f°", pos.helioLatitude))
                    }
                    InfoRow(label: "Radio Helioc. (UA)",  value: String(format: "%.8f", pos.helioRadius))
                    InfoRow(label: distLabel,             value: distValue)
                }
                if pos.planet != .sun && mode == .geocentric {
                    Divider().background(Color.dimText.opacity(0.3))
                    InfoRow(label: "Elongación del Sol",  value: String(format: "%.4f°", pos.elongation))
                    InfoRow(label: "Estado",
                            value: pos.retrograde ? "RETRÓGRADO ℞" : "Directo →",
                            highlight: pos.retrograde)
                    if pos.planet == .moon {
                        let phase = moonPhaseName(elongation: pos.elongation)
                        InfoRow(label: "Fase lunar", value: phase, highlight: true)
                    }
                }
            }
            .padding(12)
        }
        .background(Color.spaceDeep.opacity(0.9))
        .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldAccent.opacity(0.15), lineWidth: 1))
    }
}

func moonPhaseName(elongation: Double) -> String {
    switch elongation {
    case 0..<22.5:   return "🌑 Luna Nueva"
    case 22.5..<67.5: return "🌒 Cuarto Creciente"
    case 67.5..<112.5: return "🌓 Cuarto Creciente"
    case 112.5..<157.5: return "🌔 Gibosa Creciente"
    case 157.5..<180: return "🌕 Luna Llena"
    default:          return "🌖 Fase Menguante"
    }
}

struct TimezoneRow: View {
    @AppStorage("tzOffset") var tzOffset: Double = Double(TimeZone.current.secondsFromGMT())/3600

    var body: some View {
        HStack {
            Text("Zona Horaria")
                .font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
            Spacer()
            Text(String(format: "UTC%+.1f", tzOffset))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.silverAccent)
            Stepper("", value: $tzOffset, in: -12...14, step: 0.5)
                .labelsHidden()
                .onChange(of: tzOffset) { AppState.shared.timezone = $0 }
        }
        .padding(12)
        .background(Color.spaceMid.opacity(0.4))
        .cornerRadius(8)
    }
}


