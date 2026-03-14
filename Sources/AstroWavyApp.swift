// AstroWavyApp.swift
// Astro Wavy Pro — iOS version
// Basado en Astro Wavy Pro v13 (Python/tkinter) — adaptado a SwiftUI/iOS

import SwiftUI

@main
struct AstroWavyApp: App {
    @StateObject private var appState = WavyAppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var appState: WavyAppState

    var body: some View {
        TabView {
            ChartView()
                .tabItem { Label("Gráfico", systemImage: "chart.xyaxis.line") }
                .environmentObject(appState)

            PositionsTabView()
                .tabItem { Label("Planetas", systemImage: "globe") }
                .environmentObject(appState)

            GannView()
                .tabItem { Label("Gann", systemImage: "square.grid.3x3") }
                .environmentObject(appState)

            DegreesTabView()
                .tabItem { Label("Recorrido", systemImage: "arrow.forward.circle") }

            SearchTabView()
                .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
        }
        .accentColor(.goldAccent)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Planets Tab (wrapper over existing PositionsView)

struct PositionsTabView: View {
    @StateObject private var vm = PositionsViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                SpaceBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 10) {
                            DateTimePicker(title: "Fecha y Hora", date: $vm.selectedDate)
                            TimezoneRow()
                            ModeToggle(viewMode: $vm.viewMode, onChanged: { vm.calculate() })
                            CalcButton(title: "Calcular Posiciones", action: vm.calculate, isLoading: vm.isLoading)
                        }
                        .padding(.horizontal)

                        if !vm.positions.isEmpty {
                            // JD info
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Día Juliano").font(.system(size: 9, design: .monospaced)).foregroundColor(.dimText)
                                    Text(String(format: "%.6f", vm.julianDay))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.goldAccent)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("T.S. Greenwich").font(.system(size: 9, design: .monospaced)).foregroundColor(.dimText)
                                    Text(String(format: "%.4f°", vm.gmst))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.silverAccent)
                                }
                            }
                            .padding(10)
                            .background(Color.spaceMid.opacity(0.4))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldAccent.opacity(0.15), lineWidth: 1))
                            .padding(.horizontal)

                            // Mode label
                            HStack {
                                Image(systemName: vm.viewMode == .geocentric ? "globe" : "sun.max")
                                    .foregroundColor(.goldAccent)
                                Text(vm.viewMode == .geocentric ? "Vista Geocéntrica" : "Vista Heliocéntrica")
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                                Spacer()
                            }.padding(.horizontal)

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
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.goldAccent)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Mode Toggle helper

struct ModeToggle: View {
    @Binding var viewMode: ViewMode
    var onChanged: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.rawValue) { mode in
                Button(action: { viewMode = mode; onChanged() }) {
                    HStack(spacing: 5) {
                        Image(systemName: mode == .geocentric ? "globe" : "sun.max")
                            .font(.system(size: 12))
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity).frame(height: 36)
                    .background(viewMode == mode ? Color.goldAccent : Color.spaceMid.opacity(0.5))
                    .foregroundColor(viewMode == mode ? .spaceDark : .dimText)
                }
            }
        }
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldAccent.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Degrees Tab (wrapper)

struct DegreesTabView: View {
    @StateObject private var vm = DegreesViewModel()
    @State private var showPlanetPicker = false

    var daysSpan: Double { abs(jdFromDate(vm.dateEnd) - jdFromDate(vm.dateStart)) }

    var body: some View {
        NavigationView {
            ZStack {
                SpaceBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 10) {
                            DateTimePicker(title: "Fecha Inicio", date: $vm.dateStart)
                            DateTimePicker(title: "Fecha Fin",    date: $vm.dateEnd)
                            HStack {
                                Image(systemName: "calendar.badge.clock").foregroundColor(.goldAccent)
                                Text(String(format: "%.1f días (%.2f años)", daysSpan, daysSpan/365.25))
                                    .font(.system(size: 12, design: .monospaced)).foregroundColor(.silverAccent)
                                Spacer()
                            }
                            Button(action: { showPlanetPicker.toggle() }) {
                                HStack {
                                    Image(systemName: "checklist")
                                    Text("Planetas: \(vm.selectedPlanets.count)/\(Planet.allCases.count)")
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    Spacer()
                                    Image(systemName: showPlanetPicker ? "chevron.up" : "chevron.down")
                                }.foregroundColor(.goldAccent)
                                .padding(10).background(Color.spaceMid.opacity(0.5)).cornerRadius(8)
                            }
                            if showPlanetPicker {
                                PlanetMultiPicker(selected: $vm.selectedPlanets)
                            }
                            CalcButton(title: "Calcular Recorridos", action: vm.calculate, isLoading: vm.isLoading)
                        }
                        .padding(.horizontal)

                        if !vm.results.isEmpty {
                            VStack(spacing: 8) {
                                SectionHeader(title: "Grados Recorridos").padding(.horizontal)
                                ForEach(vm.results) { row in TravelCard(row: row) }
                            }.padding(.horizontal)
                        }
                        Spacer(minLength: 30)
                    }.padding(.top, 12)
                }
            }
            .navigationTitle("Grados Recorridos")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Search Tab (wrapper)

struct SearchTabView: View {
    var body: some View {
        SearchView()
    }
}

// MARK: - Shared UI (copied from previous version)

extension Color {
    static let spaceDark    = Color(red: 0.02, green: 0.04, blue: 0.10)
    static let spaceDeep    = Color(red: 0.04, green: 0.08, blue: 0.18)
    static let spaceMid     = Color(red: 0.07, green: 0.13, blue: 0.28)
    static let goldAccent   = Color(red: 1.0,  green: 0.84, blue: 0.0)
    static let silverAccent = Color(red: 0.75, green: 0.85, blue: 0.95)
    static let dimText      = Color(red: 0.55, green: 0.65, blue: 0.80)

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(red: Double((int>>16)&0xFF)/255,
                  green: Double((int>>8)&0xFF)/255,
                  blue: Double(int&0xFF)/255)
    }
}

extension Planet {
    var swiftUIColor: Color { Color(hex: color) }
}

class AppState: ObservableObject {
    @Published var timezone: Double = Double(TimeZone.current.secondsFromGMT()) / 3600.0
    static let shared = AppState()
}

struct SpaceBackground: View {
    var body: some View {
        LinearGradient(gradient: Gradient(colors: [.spaceDark, .spaceDeep, .spaceMid]),
                       startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.goldAccent)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }
}

struct PlanetBadge: View {
    let planet: Planet; var size: CGFloat = 32
    var body: some View {
        ZStack {
            Circle().fill(planet.swiftUIColor.opacity(0.2)).frame(width: size, height: size)
            Circle().stroke(planet.swiftUIColor.opacity(0.6), lineWidth: 1).frame(width: size, height: size)
            Text(planet.symbol).font(.system(size: size * 0.5))
        }
    }
}

struct InfoRow: View {
    let label: String; let value: String; var highlight: Bool = false
    var body: some View {
        HStack {
            Text(label).font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: highlight ? .bold : .regular, design: .monospaced))
                .foregroundColor(highlight ? .goldAccent : .silverAccent)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct DateTimePicker: View {
    let title: String; @Binding var date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.goldAccent).textCase(.uppercase)
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact).colorScheme(.dark).accentColor(.goldAccent).labelsHidden()
        }
        .padding(12)
        .background(Color.spaceMid.opacity(0.5)).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldAccent.opacity(0.2), lineWidth: 1))
    }
}

struct CalcButton: View {
    let title: String; let action: () -> Void; var isLoading: Bool = false
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .spaceDark)).scaleEffect(0.8) }
                else { Image(systemName: "sparkles").font(.system(size: 14)) }
                Text(isLoading ? "Calculando..." : title)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
            }
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(isLoading ? Color.goldAccent.opacity(0.6) : Color.goldAccent)
            .foregroundColor(.spaceDark).cornerRadius(10)
        }.disabled(isLoading)
    }
}

struct PlanetMultiPicker: View {
    @Binding var selected: Set<Planet>
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button("Todo") { selected = Set(Planet.allCases) }.font(.system(size: 11)).foregroundColor(.goldAccent)
                Spacer()
                Button("Nada") { selected.removeAll() }.font(.system(size: 11)).foregroundColor(.dimText)
            }.padding(.horizontal, 4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 6) {
                ForEach(Planet.allCases) { pl in
                    let sel = selected.contains(pl)
                    Button(action: { if sel { selected.remove(pl) } else { selected.insert(pl) } }) {
                        HStack(spacing: 4) {
                            Text(pl.symbol).font(.system(size: 12))
                            Text(pl.rawValue).font(.system(size: 10)).lineLimit(1)
                        }
                        .padding(.vertical, 5).padding(.horizontal, 6)
                        .background(sel ? pl.swiftUIColor.opacity(0.2) : Color.spaceDark.opacity(0.5))
                        .cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(sel ? pl.swiftUIColor : Color.dimText.opacity(0.3), lineWidth: 1))
                        .foregroundColor(sel ? pl.swiftUIColor : .dimText)
                    }
                }
            }
        }
        .padding(10).background(Color.spaceDeep.opacity(0.8)).cornerRadius(10)
    }
}

struct TimezoneRow: View {
    @AppStorage("tzOffset") var tzOffset: Double = Double(TimeZone.current.secondsFromGMT())/3600
    var body: some View {
        HStack {
            Text("Zona Horaria").font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
            Spacer()
            Text(String(format: "UTC%+.1f", tzOffset))
                .font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(.silverAccent)
            Stepper("", value: $tzOffset, in: -12...14, step: 0.5).labelsHidden()
                .onChange(of: tzOffset) { AppState.shared.timezone = $0 }
        }
        .padding(12).background(Color.spaceMid.opacity(0.4)).cornerRadius(8)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner2(radius: radius, corners: corners))
    }
}
struct RoundedCorner2: Shape {
    var radius: CGFloat; var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}
