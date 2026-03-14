// AddWavyView.swift
// Crear Wavy Simple y Wavy Compuesta

import SwiftUI

struct AddWavyView: View {
    @EnvironmentObject var appState: WavyAppState
    @Environment(\.dismiss) var dismiss
    @State private var tab = 0

    var body: some View {
        NavigationView {
            ZStack {
                SpaceBackground()
                VStack(spacing: 0) {
                    Picker("", selection: $tab) {
                        Text("Wavy Simple").tag(0)
                        Text("Wavy Compuesta").tag(1)
                    }.pickerStyle(.segmented).padding()

                    if tab == 0 {
                        SimpleWavyForm(dismiss: dismiss)
                            .environmentObject(appState)
                    } else {
                        CompositeWavyForm(dismiss: dismiss)
                            .environmentObject(appState)
                    }
                }
            }
            .navigationTitle("Nueva Wavy Line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundColor(.dimText)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Simple Wavy Form

struct SimpleWavyForm: View {
    @EnvironmentObject var appState: WavyAppState
    let dismiss: DismissAction

    @State private var name = "Wavy_1"
    @State private var planet: Planet = .moon
    @State private var fc: Double = 1.0
    @State private var direction: WavyDirection = .suma
    @State private var mode: WavyMode = .dinamico
    @State private var hitoStep: Double = 90
    @State private var helio = false
    @State private var startDate = Date()
    @State private var startPrice: Double = 100
    @State private var useLastBar = true

    var lastClose: Double { appState.priceBars.last?.close ?? 100 }
    var lastDate:  Date   { appState.priceBars.last?.date  ?? Date() }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                FormCard(title: "NOMBRE") {
                    TextField("Nombre", text: $name)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.goldAccent)
                        .padding(8)
                        .background(Color.spaceMid.opacity(0.4))
                        .cornerRadius(8)
                }

                FormCard(title: "PLANETA") {
                    Picker("", selection: $planet) {
                        ForEach(Planet.allCases.filter { $0 != .sun || true }) { pl in
                            Label(pl.rawValue, systemImage: "circle.fill").tag(pl)
                        }
                    }.pickerStyle(.menu).accentColor(.goldAccent)
                        .background(Color.spaceMid.opacity(0.4)).cornerRadius(8)

                    Toggle("Heliocéntrico", isOn: $helio)
                        .tint(.goldAccent)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.dimText)
                }

                FormCard(title: "FC — FACTOR DE CONVERSIÓN") {
                    HStack {
                        Text("FC =")
                            .font(.system(size: 13, design: .monospaced)).foregroundColor(.dimText)
                        TextField("1.0", value: $fc, format: .number)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.goldAccent)
                            .keyboardType(.decimalPad)
                            .padding(8)
                            .background(Color.spaceMid.opacity(0.4))
                            .cornerRadius(8)
                        Text("precio/grado").font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
                    }
                    Text("precio(t) = P₀ + dir × FC × Δgrados")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.dimText.opacity(0.7))

                    // Armónicos rápidos
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach([0.25, 0.5, 1.0, 2.0, 4.0, 8.0], id: \.self) { mult in
                                let v = round(fc * mult * 1000) / 1000
                                Button(action: { fc = v }) {
                                    Text("×\(mult <= 1 ? String(format:"%.2f",mult) : String(Int(mult)))")
                                        .font(.system(size: 9, design: .monospaced))
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Color.spaceMid.opacity(0.5)).cornerRadius(6)
                                        .foregroundColor(.silverAccent)
                                }
                            }
                        }
                    }
                }

                FormCard(title: "DIRECCIÓN") {
                    HStack(spacing: 0) {
                        ForEach(WavyDirection.allCases, id: \.rawValue) { d in
                            Button(action: { direction = d }) {
                                Text(d.rawValue)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .frame(maxWidth: .infinity).frame(height: 36)
                                    .background(direction == d ? Color.goldAccent : Color.spaceMid.opacity(0.4))
                                    .foregroundColor(direction == d ? .spaceDark : .dimText)
                            }
                        }
                    }
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldAccent.opacity(0.2)))
                }

                FormCard(title: "MODO") {
                    HStack(spacing: 0) {
                        ForEach(WavyMode.allCases, id: \.rawValue) { m in
                            Button(action: { mode = m }) {
                                Text(m.rawValue)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .frame(maxWidth: .infinity).frame(height: 34)
                                    .background(mode == m ? Color.spaceMid : Color.clear)
                                    .foregroundColor(mode == m ? .goldAccent : .dimText)
                            }
                        }
                    }
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dimText.opacity(0.2)))

                    if mode == .hitos {
                        HStack {
                            Text("Intervalo:").font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                            TextField("90", value: $hitoStep, format: .number)
                                .frame(width: 60).keyboardType(.decimalPad)
                                .foregroundColor(.goldAccent)
                                .padding(6).background(Color.spaceMid.opacity(0.4)).cornerRadius(6)
                            Text("°").foregroundColor(.dimText)
                            ForEach([30.0, 45.0, 90.0, 180.0, 360.0], id: \.self) { v in
                                Button("\(Int(v))°") { hitoStep = v }
                                    .font(.system(size: 9)).foregroundColor(.silverAccent)
                                    .padding(.horizontal, 4).padding(.vertical, 3)
                                    .background(Color.spaceMid.opacity(0.3)).cornerRadius(4)
                            }
                        }
                    }
                }

                FormCard(title: "PUNTO DE ANCLAJE") {
                    if !appState.priceBars.isEmpty {
                        Toggle("Usar última barra del CSV", isOn: $useLastBar)
                            .tint(.goldAccent)
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(.dimText)
                    }

                    if !useLastBar || appState.priceBars.isEmpty {
                        VStack(spacing: 8) {
                            DatePicker("Fecha inicio", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                .colorScheme(.dark).accentColor(.goldAccent)
                                .font(.system(size: 12, design: .monospaced)).foregroundColor(.silverAccent)
                            HStack {
                                Text("Precio inicio:")
                                    .font(.system(size: 12, design: .monospaced)).foregroundColor(.dimText)
                                TextField("100", value: $startPrice, format: .number)
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(.goldAccent)
                                    .padding(6).background(Color.spaceMid.opacity(0.4)).cornerRadius(8)
                            }
                        }
                    } else {
                        HStack {
                            Text("Fecha: \(medDateFmt.string(from: lastDate))")
                            Spacer()
                            Text("Precio: \(String(format:"%.4f", lastClose))")
                        }
                        .font(.system(size: 11, design: .monospaced)).foregroundColor(.silverAccent)
                    }
                }

                // — Botón crear —
                Button(action: create) {
                    HStack {
                        Image(systemName: "waveform.path")
                        Text("CREAR WAVY SIMPLE")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.goldAccent).foregroundColor(.spaceDark)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .padding()
        }
    }

    func create() {
        let anchorDate  = (useLastBar && !appState.priceBars.isEmpty) ? lastDate  : startDate
        let anchorPrice = (useLastBar && !appState.priceBars.isEmpty) ? lastClose : startPrice
        let cfg = WavyConfig(name: name.isEmpty ? "Wavy" : name,
                              planet: planet, fc: fc, direction: direction,
                              mode: mode, hitoStep: hitoStep, helio: helio,
                              startDate: anchorDate, startPrice: anchorPrice,
                              color: nextWavyColor())
        appState.addSimpleWavy(cfg)
        dismiss()
    }
}

// MARK: - Composite Wavy Form

struct CompositeWavyForm: View {
    @EnvironmentObject var appState: WavyAppState
    let dismiss: DismissAction

    @State private var name = "Compuesta_1"
    @State private var direction: WavyDirection = .suma
    @State private var startDate = Date()
    @State private var startPrice: Double = 100
    @State private var useLastBar = true
    @State private var planets: [CompositePlanetEntry] = []

    // Add planet form
    @State private var addPlanet: Planet = .sun
    @State private var addFC: Double = 1.0
    @State private var addWeight: Double = 1.0
    @State private var addHelio = false

    var lastClose: Double { appState.priceBars.last?.close ?? 100 }
    var lastDate:  Date   { appState.priceBars.last?.date  ?? Date() }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                FormCard(title: "NOMBRE") {
                    TextField("Nombre", text: $name)
                        .font(.system(size: 14, design: .monospaced)).foregroundColor(.goldAccent)
                        .padding(8).background(Color.spaceMid.opacity(0.4)).cornerRadius(8)
                }

                FormCard(title: "AGREGAR PLANETA") {
                    HStack(spacing: 8) {
                        Picker("", selection: $addPlanet) {
                            ForEach(Planet.allCases) { pl in
                                Text("\(pl.symbol) \(pl.rawValue)").tag(pl)
                            }
                        }.pickerStyle(.menu).accentColor(.goldAccent)
                            .background(Color.spaceMid.opacity(0.4)).cornerRadius(8)
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("FC").font(.system(size: 9, design: .monospaced)).foregroundColor(.dimText)
                            TextField("1.0", value: $addFC, format: .number)
                                .keyboardType(.decimalPad).foregroundColor(.goldAccent)
                                .frame(width: 70).padding(6)
                                .background(Color.spaceMid.opacity(0.4)).cornerRadius(6)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Peso").font(.system(size: 9, design: .monospaced)).foregroundColor(.dimText)
                            TextField("1.0", value: $addWeight, format: .number)
                                .keyboardType(.decimalPad).foregroundColor(.goldAccent)
                                .frame(width: 60).padding(6)
                                .background(Color.spaceMid.opacity(0.4)).cornerRadius(6)
                        }
                        Toggle("Helio", isOn: $addHelio).tint(.goldAccent)
                            .font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                    }
                    Button(action: {
                        planets.append(CompositePlanetEntry(planet: addPlanet, fc: addFC,
                                                            weight: addWeight, helio: addHelio))
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Agregar \(addPlanet.symbol) \(addPlanet.rawValue)")
                        }
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(Color.spaceMid.opacity(0.5)).foregroundColor(.goldAccent)
                        .cornerRadius(8)
                    }
                }

                if !planets.isEmpty {
                    FormCard(title: "PLANETAS CONFIGURADOS (\(planets.count))") {
                        ForEach(planets) { entry in
                            HStack {
                                Text(entry.planet.symbol).font(.system(size: 16))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.planet.rawValue).font(.system(size: 12, weight: .semibold)).foregroundColor(.silverAccent)
                                    Text("FC=\(String(format:"%.3f",entry.fc)) · Peso=\(String(format:"%.1f",entry.weight))\(entry.helio ? " · Helio" : "")")
                                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.dimText)
                                }
                                Spacer()
                                Button(action: { planets.removeAll { $0.id == entry.id } }) {
                                    Image(systemName: "minus.circle.fill").foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                FormCard(title: "DIRECCIÓN") {
                    HStack(spacing: 0) {
                        ForEach(WavyDirection.allCases, id: \.rawValue) { d in
                            Button(action: { direction = d }) {
                                Text(d.rawValue)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .frame(maxWidth: .infinity).frame(height: 36)
                                    .background(direction == d ? Color.goldAccent : Color.spaceMid.opacity(0.4))
                                    .foregroundColor(direction == d ? .spaceDark : .dimText)
                            }
                        }
                    }.cornerRadius(8)
                }

                FormCard(title: "ANCLAJE") {
                    if !appState.priceBars.isEmpty {
                        Toggle("Usar última barra del CSV", isOn: $useLastBar)
                            .tint(.goldAccent).font(.system(size: 12, design: .monospaced)).foregroundColor(.dimText)
                    }
                    if !useLastBar || appState.priceBars.isEmpty {
                        DatePicker("Fecha", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                            .colorScheme(.dark).accentColor(.goldAccent)
                        HStack {
                            Text("Precio:").font(.system(size: 12, design: .monospaced)).foregroundColor(.dimText)
                            TextField("100", value: $startPrice, format: .number)
                                .keyboardType(.decimalPad).foregroundColor(.goldAccent)
                                .padding(6).background(Color.spaceMid.opacity(0.4)).cornerRadius(8)
                        }
                    } else {
                        Text("Precio: \(String(format:"%.4f",lastClose)) · \(medDateFmt.string(from: lastDate))")
                            .font(.system(size: 11, design: .monospaced)).foregroundColor(.silverAccent)
                    }
                }

                Button(action: create) {
                    HStack {
                        Image(systemName: "waveform.path.badge.plus")
                        Text("CREAR WAVY COMPUESTA")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(planets.isEmpty ? Color.dimText.opacity(0.3) : Color.goldAccent)
                    .foregroundColor(.spaceDark).cornerRadius(12)
                }
                .disabled(planets.isEmpty)
                .padding(.horizontal).padding(.bottom, 30)
            }
            .padding()
        }
    }

    func create() {
        guard !planets.isEmpty else { return }
        let anchorDate  = (useLastBar && !appState.priceBars.isEmpty) ? lastDate  : startDate
        let anchorPrice = (useLastBar && !appState.priceBars.isEmpty) ? lastClose : startPrice
        let cfg = CompositeWavyConfig(name: name.isEmpty ? "Compuesta" : name,
                                       planets: planets, direction: direction,
                                       startDate: anchorDate, startPrice: anchorPrice,
                                       color: nextWavyColor())
        appState.addCompositeWavy(cfg)
        dismiss()
    }
}

// MARK: - FormCard helper

struct FormCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.goldAccent)
                .tracking(1.5)
            content
        }
        .padding(12)
        .background(Color.spaceMid.opacity(0.4))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldAccent.opacity(0.15), lineWidth: 1))
    }
}
