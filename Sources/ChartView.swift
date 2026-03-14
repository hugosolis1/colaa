// ChartView.swift
// Gráfico principal con velas + wavy lines + Gann + estaciones
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ScrollBackground Modifier (iOS 15 compatible)

struct HideScrollBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

extension View {
    func hideScrollBackground() -> some View {
        modifier(HideScrollBackground())
    }
}

// MARK: - Chart State

class ChartState: ObservableObject {
    @Published var visibleStart: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @Published var visibleEnd: Date   = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @Published var priceMin: Double = 0
    @Published var priceMax: Double = 100
    @Published var showRetro: Bool = true
    @Published var showSq9: Bool = false
    @Published var showGann: Bool = false
    @Published var crosshairDate: Date? = nil
    @Published var crosshairPrice: Double? = nil

    func fit(bars: [PriceBar]) {
        guard !bars.isEmpty else { return }
        visibleStart = bars.first!.date
        visibleEnd   = Calendar.current.date(byAdding: .month, value: 3, to: bars.last!.date) ?? bars.last!.date
        let lo = bars.map(\.low).min() ?? 0
        let hi = bars.map(\.high).max() ?? 1
        let pad = (hi - lo) * 0.1
        priceMin = lo - pad
        priceMax = hi + pad
    }
}

// MARK: - Main Chart Tab

struct ChartView: View {
    @EnvironmentObject var appState: WavyAppState
    @StateObject private var chartState = ChartState()
    @State private var showImport = false
    @State private var showAddWavy = false
    @State private var showFCCalc = false
    @State private var showWavyList = false

    var body: some View {
        NavigationView {
            ZStack {
                SpaceBackground()
                VStack(spacing: 0) {
                    // — Toolbar —
                    ChartToolbar(
                        showImport: $showImport,
                        showAddWavy: $showAddWavy,
                        showFCCalc: $showFCCalc,
                        showWavyList: $showWavyList,
                        chartState: chartState
                    )

                    // — Precio actual + info —
                    if !appState.priceBars.isEmpty {
                        PriceInfoBar(chartState: chartState)
                    }

                    // — Gráfico —
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            if appState.priceBars.isEmpty {
                                EmptyChartPlaceholder()
                            } else {
                                PriceChartCanvas(
                                    bars: appState.priceBars,
                                    wavyResults: appState.simpleWavyResults + appState.compositeWavyResults,
                                    retroStations: chartState.showRetro ? appState.retroStations : [],
                                    sq9Levels: chartState.showSq9 ? appState.sq9Levels : [],
                                    chartState: chartState,
                                    size: geo.size
                                )
                            }
                        }
                    }
                    .background(Color(hex: "050C1A"))
                    .cornerRadius(12)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            }
            .navigationTitle("Astro Wavy Pro")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showImport) {
            CSVImportView()
                .environmentObject(appState)
                .onDisappear { chartState.fit(bars: appState.priceBars) }
        }
        .sheet(isPresented: $showAddWavy) {
            AddWavyView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showFCCalc) {
            FCCalculatorView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showWavyList) {
            WavyListView()
                .environmentObject(appState)
        }
        .onChange(of: appState.priceBars.count) { _ in
            chartState.fit(bars: appState.priceBars)
        }
    }
}

// MARK: - Chart Toolbar

struct ChartToolbar: View {
    @Binding var showImport: Bool
    @Binding var showAddWavy: Bool
    @Binding var showFCCalc: Bool
    @Binding var showWavyList: Bool
    @ObservedObject var chartState: ChartState
    @EnvironmentObject var appState: WavyAppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ToolBtn(icon: "square.and.arrow.down", label: "CSV", color: .goldAccent) { showImport = true }
                ToolBtn(icon: "waveform.path", label: "Wavy", color: Color(hex:"4ECDC4")) { showAddWavy = true }
                ToolBtn(icon: "list.bullet", label: "Lista", color: .silverAccent) { showWavyList = true }
                ToolBtn(icon: "divide.circle", label: "FC", color: Color(hex:"FFD700")) { showFCCalc = true }
                Toggle(isOn: $chartState.showRetro) {
                    Text("℞").font(.system(size: 11, weight: .bold)).foregroundColor(.red)
                }
                .toggleStyle(.button)
                .tint(Color.red.opacity(0.3))
                Toggle(isOn: $chartState.showSq9) {
                    Text("Sq9").font(.system(size: 10, weight: .bold)).foregroundColor(.goldAccent)
                }
                .toggleStyle(.button)
                .tint(Color.goldAccent.opacity(0.3))
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
        }
        .background(Color.spaceMid.opacity(0.6))
    }
}

struct ToolBtn: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 9, design: .monospaced))
            }
            .foregroundColor(color)
            .frame(width: 50, height: 40)
            .background(color.opacity(0.12))
            .cornerRadius(8)
        }
    }
}

// MARK: - Price Info Bar

struct PriceInfoBar: View {
    @ObservedObject var chartState: ChartState
    @EnvironmentObject var appState: WavyAppState

    var lastBar: PriceBar? { appState.priceBars.last }

    var body: some View {
        HStack(spacing: 16) {
            if let b = lastBar {
                Group {
                    PriceInfoItem(label: "C", value: String(format:"%.4f", b.close), color: b.close >= b.open ? .green : .red)
                    PriceInfoItem(label: "O", value: String(format:"%.4f", b.open))
                    PriceInfoItem(label: "H", value: String(format:"%.4f", b.high), color: .green)
                    PriceInfoItem(label: "L", value: String(format:"%.4f", b.low), color: .red)
                }
            }
            Spacer()
            Text(appState.priceFileName)
                .font(.system(size: 9, design: .monospaced)).foregroundColor(.dimText).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.spaceDeep.opacity(0.8))
    }
}

struct PriceInfoItem: View {
    let label: String; let value: String; var color: Color = .silverAccent
    var body: some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 9, design: .monospaced)).foregroundColor(.dimText)
            Text(value).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(color)
        }
    }
}

// MARK: - Price Chart Canvas

struct PriceChartCanvas: View {
    let bars: [PriceBar]
    let wavyResults: [WavyResult]
    let retroStations: [RetroStation]
    let sq9Levels: [Sq9Level]
    @ObservedObject var chartState: ChartState
    let size: CGSize

    @GestureState private var dragOffset: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var visibleBars: [PriceBar] {
        bars.filter { $0.date >= chartState.visibleStart && $0.date <= chartState.visibleEnd }
    }

    var body: some View {
        ZStack {
            // Grid
            ChartGrid(chartState: chartState, size: size)

            // Velas
            Canvas { ctx, sz in
                drawCandles(ctx: ctx, size: sz)
            }

            // Wavy Lines
            ForEach(wavyResults.filter(\.visible)) { result in
                WavyLineView(result: result, chartState: chartState, size: size)
            }

            // Estaciones retrógradas
            ForEach(retroStations) { station in
                RetroLine(station: station, chartState: chartState, size: size)
            }

            // Sq9 levels
            ForEach(sq9Levels.prefix(20), id: \.price) { lvl in
                let y = priceToY(lvl.price, size: size)
                Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)) }
                    .stroke(Color.goldAccent.opacity(0.35), style: StrokeStyle(lineWidth: 0.5, dash: [4,4]))
            }

            // Crosshair + info
            if let date = chartState.crosshairDate, let price = chartState.crosshairPrice {
                CrosshairView(date: date, price: price, chartState: chartState, size: size)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    let dx = val.translation.width
                    let totalSeconds = chartState.visibleEnd.timeIntervalSince(chartState.visibleStart)
                    let secsPerPt = totalSeconds / Double(size.width)
                    let shift = -dx * secsPerPt
                    chartState.visibleStart = chartState.visibleStart.addingTimeInterval(shift / 60) // throttle
                    chartState.visibleEnd   = chartState.visibleEnd.addingTimeInterval(shift / 60)
                    // Crosshair
                    let x = val.location.x
                    let date = xToDate(x, size: size)
                    let y = val.location.y
                    let price = yToPrice(y, size: size)
                    chartState.crosshairDate  = date
                    chartState.crosshairPrice = price
                }
                .onEnded { _ in chartState.crosshairDate = nil }
        )
        .gesture(
            MagnificationGesture()
                .onChanged { val in
                    let delta = val / lastScale
                    let center = chartState.visibleStart.addingTimeInterval(
                        chartState.visibleEnd.timeIntervalSince(chartState.visibleStart)/2)
                    let half = chartState.visibleEnd.timeIntervalSince(chartState.visibleStart)/2/Double(delta)
                    chartState.visibleStart = center.addingTimeInterval(-half)
                    chartState.visibleEnd   = center.addingTimeInterval(half)
                    lastScale = val
                }
                .onEnded { _ in lastScale = 1 }
        )
    }

    // MARK: Coordinate helpers
    func dateToX(_ date: Date, size: CGSize) -> CGFloat {
        let total = chartState.visibleEnd.timeIntervalSince(chartState.visibleStart)
        guard total > 0 else { return 0 }
        let offset = date.timeIntervalSince(chartState.visibleStart)
        return CGFloat(offset / total) * size.width
    }

    func xToDate(_ x: CGFloat, size: CGSize) -> Date {
        let total = chartState.visibleEnd.timeIntervalSince(chartState.visibleStart)
        let offset = Double(x / size.width) * total
        return chartState.visibleStart.addingTimeInterval(offset)
    }

    func priceToY(_ price: Double, size: CGSize) -> CGFloat {
        let range = chartState.priceMax - chartState.priceMin
        guard range > 0 else { return size.height / 2 }
        let norm = (price - chartState.priceMin) / range
        return size.height * (1 - CGFloat(norm))
    }

    func yToPrice(_ y: CGFloat, size: CGSize) -> Double {
        let norm = 1 - Double(y / size.height)
        return chartState.priceMin + norm * (chartState.priceMax - chartState.priceMin)
    }

    // MARK: Draw Candles
    func drawCandles(ctx: GraphicsContext, size: CGSize) {
        let vBars = visibleBars
        guard !vBars.isEmpty else { return }
        let candleW = max(1, size.width / CGFloat(vBars.count) * 0.7)

        for bar in vBars {
            let x = dateToX(bar.date, size: size)
            let openY  = priceToY(bar.open,  size: size)
            let closeY = priceToY(bar.close, size: size)
            let highY  = priceToY(bar.high,  size: size)
            let lowY   = priceToY(bar.low,   size: size)
            let isUp   = bar.close >= bar.open
            let color  = isUp ? Color.green : Color.red

            // Wick
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: x, y: highY))
                p.addLine(to: CGPoint(x: x, y: lowY))
            }, with: .color(color), lineWidth: 1)

            // Body
            let bodyY = min(openY, closeY)
            let bodyH = max(1, abs(closeY - openY))
            ctx.fill(Path(CGRect(x: x - candleW/2, y: bodyY, width: candleW, height: bodyH)),
                     with: .color(color))
        }
    }
}

// MARK: - Chart Grid

struct ChartGrid: View {
    @ObservedObject var chartState: ChartState
    let size: CGSize

    var body: some View {
        Canvas { ctx, sz in
            let priceStep = niceStep(range: chartState.priceMax - chartState.priceMin, divisions: 6)
            var p = floor(chartState.priceMin / priceStep) * priceStep
            while p <= chartState.priceMax {
                let y = sz.height * CGFloat(1 - (p - chartState.priceMin)/(chartState.priceMax - chartState.priceMin))
                ctx.stroke(Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: sz.width, y: y))
                }, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
                // Label
                let txt = Text(String(format: "%.2f", p))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.init(Color.dimText))
                ctx.draw(txt, at: CGPoint(x: sz.width - 2, y: y - 6), anchor: .topTrailing)
                p += priceStep
            }
        }
    }

    func niceStep(range: Double, divisions: Int) -> Double {
        let raw = range / Double(divisions)
        let pow10 = pow(10, floor(log10(raw)))
        let norm = raw / pow10
        let nice: Double = norm < 1.5 ? 1 : norm < 3 ? 2 : norm < 7 ? 5 : 10
        return nice * pow10
    }
}

// MARK: - Wavy Line View

struct WavyLineView: View {
    let result: WavyResult
    @ObservedObject var chartState: ChartState
    let size: CGSize

    var body: some View {
        Canvas { ctx, sz in
            let color = Color(hex: result.color)
            let visPoints = result.points.filter {
                $0.date >= chartState.visibleStart.addingTimeInterval(-86400) &&
                $0.date <= chartState.visibleEnd.addingTimeInterval(86400)
            }
            guard visPoints.count >= 2 else { return }

            var path = Path()
            var first = true
            for pt in visPoints {
                let x = dateToX(pt.date, size: sz)
                let y = priceToY(pt.price, size: sz)
                if first { path.move(to: CGPoint(x: x, y: y)); first = false }
                else      { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(path, with: .color(color), lineWidth: 1.5)

            // Hitos
            for pt in visPoints where pt.isHito {
                let x = dateToX(pt.date, size: sz)
                let y = priceToY(pt.price, size: sz)
                ctx.fill(Path(ellipseIn: CGRect(x: x-3, y: y-3, width: 6, height: 6)),
                         with: .color(color))
            }
        }
    }

    func dateToX(_ date: Date, size: CGSize) -> CGFloat {
        let total = chartState.visibleEnd.timeIntervalSince(chartState.visibleStart)
        guard total > 0 else { return 0 }
        return CGFloat(date.timeIntervalSince(chartState.visibleStart) / total) * size.width
    }

    func priceToY(_ price: Double, size: CGSize) -> CGFloat {
        let range = chartState.priceMax - chartState.priceMin
        guard range > 0 else { return size.height/2 }
        return size.height * CGFloat(1 - (price - chartState.priceMin) / range)
    }
}

// MARK: - Retro Station Line

struct RetroLine: View {
    let station: RetroStation
    @ObservedObject var chartState: ChartState
    let size: CGSize

    var body: some View {
        let color = Color(hex: station.type.color)
        let total = chartState.visibleEnd.timeIntervalSince(chartState.visibleStart)
        guard total > 0 else { return AnyView(EmptyView()) }
        let x = CGFloat(station.date.timeIntervalSince(chartState.visibleStart) / total) * size.width
        guard x >= 0 && x <= size.width else { return AnyView(EmptyView()) }

        return AnyView(
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4,3]))

                Text(station.type.symbol)
                    .font(.system(size: 9, weight: .bold)).foregroundColor(color)
                    .offset(x: x + 2, y: 4)
            }
        )
    }
}

// MARK: - Crosshair

struct CrosshairView: View {
    let date: Date; let price: Double
    @ObservedObject var chartState: ChartState
    let size: CGSize

    var x: CGFloat {
        let total = chartState.visibleEnd.timeIntervalSince(chartState.visibleStart)
        guard total > 0 else { return 0 }
        return CGFloat(date.timeIntervalSince(chartState.visibleStart)/total) * size.width
    }
    var y: CGFloat {
        let range = chartState.priceMax - chartState.priceMin
        guard range > 0 else { return size.height/2 }
        return size.height * CGFloat(1-(price-chartState.priceMin)/range)
    }

    var body: some View {
        ZStack {
            Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)) }
                .stroke(Color.goldAccent.opacity(0.5), lineWidth: 0.7)
            Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)) }
                .stroke(Color.goldAccent.opacity(0.5), lineWidth: 0.7)
            // Info label
            VStack(alignment: .leading, spacing: 2) {
                Text(medDateFmt.string(from: date))
                    .font(.system(size: 9, design: .monospaced))
                Text(String(format: "%.4f", price))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.goldAccent)
            .padding(4)
            .background(Color.spaceDeep.opacity(0.85))
            .cornerRadius(6)
            .offset(x: x + 6, y: y - 30)
        }
    }
}

// MARK: - Empty Placeholder

struct EmptyChartPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line").font(.system(size: 48)).foregroundColor(.dimText)
            Text("Importa un CSV de precios").font(.system(size: 15, weight: .semibold)).foregroundColor(.silverAccent)
            Text("o agrega puntos de precio manuales\npara calcular Wavy Lines").font(.system(size: 12, design: .monospaced)).foregroundColor(.dimText).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - CSV Import View

struct CSVImportView: View {
    @EnvironmentObject var appState: WavyAppState
    @Environment(\.dismiss) var dismiss
    @State private var showPicker = false
    @State private var manualText = ""
    @State private var errorMsg = ""
    @State private var tab = 0

    var body: some View {
        NavigationView {
            ZStack {
                SpaceBackground()
                VStack(spacing: 0) {
                    Picker("", selection: $tab) {
                        Text("Archivo CSV").tag(0)
                        Text("Puntos Manuales").tag(1)
                    }.pickerStyle(.segmented).padding()

                    if tab == 0 {
                        csvFileTab
                    } else {
                        manualTab
                    }
                }
            }
            .navigationTitle("Importar Precios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") { dismiss() }.foregroundColor(.goldAccent)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    var csvFileTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Formato CSV:\nfecha,open,high,low,close,volume\n\nFormatos de fecha soportados:\nyyyy-MM-dd HH:mm:ss\nyyyy-MM-dd\ndd/MM/yyyy HH:mm")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.dimText)
                    .padding(12)
                    .background(Color.spaceMid.opacity(0.4))
                    .cornerRadius(8)
                    .padding(.horizontal)

                Button(action: { showPicker = true }) {
                    HStack {
                        Image(systemName: "doc.text").font(.system(size: 18))
                        Text("Seleccionar archivo CSV")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.goldAccent)
                    .foregroundColor(.spaceDark)
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                if !appState.priceFileName.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("\(appState.priceBars.count) barras cargadas: \(appState.priceFileName)")
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(.silverAccent)
                    }
                    .padding()
                }

                if !errorMsg.isEmpty {
                    Text(errorMsg).font(.system(size: 12)).foregroundColor(.red).padding()
                }
            }
            .padding(.top)
        }
        .fileImporter(isPresented: $showPicker,
                      allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText]) { result in
            switch result {
            case .success(let url):
                do {
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let bars = parsePriceCSV(content)
                    if bars.isEmpty { errorMsg = "No se pudieron parsear los datos" }
                    else {
                        DispatchQueue.main.async {
                            appState.priceBars = bars
                            appState.priceFileName = url.lastPathComponent
                            errorMsg = ""
                            dismiss()
                        }
                    }
                } catch { errorMsg = error.localizedDescription }
            case .failure(let e): errorMsg = e.localizedDescription
            }
        }
    }

    var manualTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Pega datos en formato:\nfecha,precio\n(una línea por barra)")
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.dimText)
                    .padding().frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $manualText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.silverAccent)
                    .frame(height: 200)
                    .padding(8)
                    .background(Color.spaceMid.opacity(0.4))
                    .cornerRadius(8)
                    .padding(.horizontal)

                Button("Cargar") {
                    let bars = parsePriceCSV("date,open,high,low,close\n" + manualText)
                    if bars.isEmpty {
                        errorMsg = "Formato inválido"
                    } else {
                        appState.priceBars = bars
                        appState.priceFileName = "Manual"
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Color.goldAccent).foregroundColor(.spaceDark)
                .cornerRadius(10).padding(.horizontal)

                if !errorMsg.isEmpty {
                    Text(errorMsg).foregroundColor(.red).font(.system(size: 12)).padding()
                }
            }.padding(.top)
        }
    }
}

// MARK: - Wavy List

struct WavyListView: View {
    @EnvironmentObject var appState: WavyAppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                SpaceBackground()
                List {
                    if appState.simpleWavyResults.isEmpty && appState.compositeWavyResults.isEmpty {
                        Text("Sin wavys. Crea una en la pestaña de Wavy.")
                            .foregroundColor(.dimText)
                            .font(.system(size: 12, design: .monospaced))
                            .listRowBackground(Color.clear)
                    }
                    Section(header: SectionHeader(title: "Wavys Simples")) {
                        ForEach($appState.simpleWavys) { $cfg in
                            HStack {
                                Circle().fill(Color(hex: cfg.color)).frame(width: 10, height: 10)
                                Text(cfg.name).font(.system(size: 13)).foregroundColor(.silverAccent)
                                Spacer()
                                Text("\(cfg.planet.symbol) FC=\(String(format:"%.3f",cfg.fc))")
                                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
                                Toggle("", isOn: $cfg.visible).labelsHidden().tint(.goldAccent)
                                    .onChange(of: cfg.visible) { _ in appState.recalculateAllWavys() }
                            }
                            .listRowBackground(Color.spaceMid.opacity(0.3))
                        }
                        .onDelete { idx in
                            idx.forEach { appState.simpleWavys.remove(at: $0) }
                            appState.recalculateAllWavys()
                        }
                    }
                    Section(header: SectionHeader(title: "Wavys Compuestas")) {
                        ForEach($appState.compositeWavys) { $cfg in
                            HStack {
                                Circle().fill(Color(hex: cfg.color)).frame(width: 10, height: 10)
                                Text(cfg.name).font(.system(size: 13)).foregroundColor(.silverAccent)
                                Spacer()
                                Text("\(cfg.planets.count) planetas")
                                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.dimText)
                                Toggle("", isOn: $cfg.visible).labelsHidden().tint(.goldAccent)
                                    .onChange(of: cfg.visible) { _ in appState.recalculateAllWavys() }
                            }
                            .listRowBackground(Color.spaceMid.opacity(0.3))
                        }
                        .onDelete { idx in
                            idx.forEach { appState.compositeWavys.remove(at: $0) }
                            appState.recalculateAllWavys()
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .hideScrollBackground()   // ← fix: compatible con iOS 15 y 16+
            }
            .navigationTitle("Gestionar Wavys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") { dismiss() }.foregroundColor(.goldAccent)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
