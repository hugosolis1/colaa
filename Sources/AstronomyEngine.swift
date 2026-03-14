// AstronomyEngine.swift
// VSOP87B + Meeus Luna Cap.47 — Alta precisión
import Foundation

// MARK: - Modelos

struct PlanetPosition: Identifiable, Equatable {
    var id: String { planet.rawValue }
    let planet: Planet
    let eclipticLongitude: Double   // geocéntrica aparente, grados
    let eclipticLatitude: Double
    let helioLongitude: Double
    let helioLatitude: Double
    let helioRadius: Double         // UA
    let geocentricDistance: Double  // UA o km para Luna
    let rightAscension: Double
    let declination: Double
    let zodiacSign: String
    let zodiacDegree: Double
    let retrograde: Bool
    let elongation: Double

    static func == (lhs: PlanetPosition, rhs: PlanetPosition) -> Bool {
        lhs.planet == rhs.planet && lhs.eclipticLongitude == rhs.eclipticLongitude
    }
}

enum Planet: String, CaseIterable, Identifiable, Codable, Hashable {
    case sun      = "Sol"
    case moon     = "Luna"
    case mercury  = "Mercurio"
    case venus    = "Venus"
    case mars     = "Marte"
    case jupiter  = "Júpiter"
    case saturn   = "Saturno"
    case uranus   = "Urano"
    case neptune  = "Neptuno"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .sun:     return "☉"
        case .moon:    return "☽"
        case .mercury: return "☿"
        case .venus:   return "♀"
        case .mars:    return "♂"
        case .jupiter: return "♃"
        case .saturn:  return "♄"
        case .uranus:  return "♅"
        case .neptune: return "♆"
        }
    }

    var color: String {
        switch self {
        case .sun:     return "#FFD700"
        case .moon:    return "#E8E8D0"
        case .mercury: return "#A8C0D0"
        case .venus:   return "#F4A460"
        case .mars:    return "#CD5C5C"
        case .jupiter: return "#DEB887"
        case .saturn:  return "#C8A000"
        case .uranus:  return "#7FFFD4"
        case .neptune: return "#4169E1"
        }
    }

    var isSolarSystemBody: Bool { true }
}

// MARK: - Matemáticas

func toRad(_ d: Double) -> Double { d * .pi / 180 }
func toDeg(_ r: Double) -> Double { r * 180 / .pi }
func norm360(_ a: Double) -> Double { var x = a.truncatingRemainder(dividingBy: 360); if x < 0 { x += 360 }; return x }
func normRad(_ r: Double) -> Double { var x = r.truncatingRemainder(dividingBy: 2 * .pi); if x < 0 { x += 2 * .pi }; return x }

func angleDiff(_ a: Double, _ b: Double) -> Double {
    var d = norm360(a) - norm360(b)
    if d > 180 { d -= 360 }
    if d < -180 { d += 360 }
    return d
}

// MARK: - Evaluador VSOP87

typealias VTerm = (Double, Double, Double)

func vsop87(_ series: [[VTerm]], tau: Double) -> Double {
    var result = 0.0, tPow = 1.0
    for terms in series {
        var s = 0.0
        for t in terms { s += t.0 * cos(t.1 + t.2 * tau) }
        result += s * tPow; tPow *= tau
    }
    return result
}

// MARK: - VSOP87B Coeficientes

// ── MERCURIO ──────────────────────────────────────────────────────
let merL: [[VTerm]] = [
 [(440250710,0,0),(40989415,1.48302034,26087.9031416),(5046294,4.47785449,52175.8062831),
  (855347,1.16520083,78263.7094247),(165590,4.11969163,104351.6125663),(34562,0.77930768,130439.5157079),
  (7583,3.71348,156527.4188),(1803,4.10339,5661.332),(1726,0.35833,182615.322),
  (1590,2.9951,25028.521),(1365,4.59918,27197.282),(1017,1.59423,208703.225),
  (714,1.54176,24978.525),(644,5.30266,11243.686),(451,6.04989,58643.708)],
 [(2608814706223,0,0),(1126008,6.21703970,26087.9031416),(303471,3.05565472,52175.8062831),
  (80538,6.10454,78263.709),(21245,2.83532,104351.613),(5592,5.82676,130439.516),
  (1472,2.51336,156527.419),(388,5.48039,182615.322)],
 [(53050,0,0),(16904,4.69072,26087.903),(7397,1.34735,52175.806),
  (3018,4.45643,78263.709),(1107,1.26227,104351.613)],
 [(188,0.349,52175.806),(142,3.125,26087.903)],
 [(114,3.142,0)],[(1,3.14,0)]
]
let merB: [[VTerm]] = [
 [(11737529,1.98357499,26087.9031416),(2388077,5.03738959,52175.8062831),(1222840,3.14159265,0),
  (543252,1.79644363,78263.7094247),(129779,4.83232499,104351.6125663),(31867,1.58088980,130439.5157079),
  (7963,4.60973,156527.419),(2014,1.35324,182615.322)],
 [(429152,3.50169780,26087.9031416),(146234,3.14159265,0),(22675,0.01516,52175.806),
  (10895,0.48435,78263.709),(6353,3.42705,104351.613),(2496,0.17556,130439.516)],
 [(11831,4.79066,26087.903),(1914,0,0),(1045,1.21216,52175.806)],
 [(235,0.354,26087.903),(161,0,0)]
]
let merR: [[VTerm]] = [
 [(39528272,0,0),(7834132,6.19233722,26087.9031416),(795526,2.95989692,52175.8062831),
  (121282,6.01064,78263.709),(21922,2.7782,104351.613),(4354,5.82895,130439.516)],
 [(217348,4.65617158,26087.9031416),(44142,1.42386,52175.806),(10094,4.47466,78263.709),
  (2433,1.24226,104351.613),(1624,0,0)],
 [(3118,3.08232,26087.903),(1245,6.15184,52175.806),(425,2.92583,78263.709)],
 [(33,1.68,26087.903)]
]

// ── VENUS ────────────────────────────────────────────────────────
let venL: [[VTerm]] = [
 [(317614667,0,0),(1353968,5.59313319,10213.2855462),(89892,5.30650048,20426.5710914),
  (5477,4.4163,7860.419),(3456,2.69964,11790.629),(2372,2.99377,3930.210),
  (1664,4.25019,1577.344),(1438,4.15745,9153.904),(1317,5.18668,26.298),
  (1201,6.15357,30639.857),(769,0.81629,9437.763),(761,1.95015,529.691)],
 [(1021352943052,0,0),(95708,2.46424449,10213.2855462),(14445,0.51626,20426.5711),
  (213,1.79548,30639.857),(174,2.65458,26.298)],
 [(54127,0,0),(3891,0.34581,10213.286),(1338,2.02011,20426.571)],
 [(136,4.804,10213.286),(78,3.67,20426.571)],
 [(114,3.142,0)],[(1,3.14,0)]
]
let venB: [[VTerm]] = [
 [(5923638,0.26702775,10213.2855462),(40108,1.14737178,20426.5710914),(32815,3.14159265,0),
  (1011,1.08946,30639.857)],
 [(513348,1.80364399,10213.2855462),(4380,3.38616,20426.571),(199,0,0)],
 [(22378,3.3851,10213.286),(282,0,0)],
 [(647,4.992,10213.286)]
]
let venR: [[VTerm]] = [
 [(72334821,0,0),(489824,4.02151799,10213.2855462),(1658,4.90206,20426.571),
  (1632,2.84548,7860.419),(1378,1.12847,11790.629),(498,2.58682,9153.904)],
 [(34551,0.89199706,10213.2855462),(234,1.77224,20426.571),(234,3.14159,0)],
 [(1407,5.06367,10213.286)],
 [(50,3.22,10213.286)]
]

// ── TIERRA ───────────────────────────────────────────────────────
let earL: [[VTerm]] = [
 [(175347046,0,0),(3341656,4.6709610,6283.0758500),(34894,4.6261,12566.1517),
  (3497,2.7441,5753.3849),(3418,2.8289,3.5231),(3136,3.6277,77713.7715),
  (2676,4.4181,7860.4194),(2343,6.1352,3930.2097),(1324,0.7425,11506.7698),
  (1273,2.0371,529.691),(1199,1.1096,1577.344),(990,5.233,5884.927),
  (902,2.045,26.298),(857,3.508,398.149),(780,1.179,5223.694),
  (753,2.533,5507.553),(505,4.583,18849.228),(492,4.205,775.523),
  (357,2.92,0.067),(317,5.849,11790.629),(284,1.899,796.298),
  (271,0.315,10977.079),(243,0.345,5486.778),(206,4.806,2544.314),
  (205,1.869,5573.143),(202,2.458,6069.777),(156,0.833,213.299),
  (132,3.411,2942.463),(126,1.083,20.775),(115,0.645,0.98)],
 [(628331966747,0,0),(206059,2.678235,6283.07585),(4303,2.6351,12566.1517),
  (425,1.59,3.523),(119,5.796,26.298),(109,2.966,1577.344),
  (93,2.59,18849.23),(72,1.14,529.69),(68,1.87,398.15),
  (67,4.41,5507.55),(59,2.89,5223.69),(56,2.17,155.42),
  (45,0.4,796.3),(36,0.47,775.52),(29,2.65,7.11)],
 [(52919,0,0),(8720,1.0721,6283.0758),(309,0.867,12566.152),
  (27,0.05,3.52),(16,5.19,26.3),(10,0.76,18849.23)],
 [(289,5.844,6283.076),(35,0,0),(17,5.49,12566.15)],
 [(114,3.142,0),(8,4.13,6283.08)],[(1,3.14,0)]
]
let earB: [[VTerm]] = [
 [(280,3.199,84334.662),(102,5.422,5507.553),(80,3.88,5223.69),(44,3.7,2352.87)],
 [(9,3.9,5507.55),(6,1.73,5223.69)]
]
let earR: [[VTerm]] = [
 [(100013989,0,0),(1670700,3.0984635,6283.0758500),(13956,3.05525,12566.1517),
  (3084,5.1985,77713.772),(1628,1.1739,5753.385),(1576,2.8469,7860.419),
  (925,5.453,11506.770),(542,4.564,3930.21),(472,3.661,5884.927),
  (346,0.964,5507.553),(329,5.9,5223.694),(307,0.299,5573.143),
  (243,4.273,11790.629),(212,5.847,1577.344),(186,5.022,10977.079),
  (175,3.012,18849.228),(110,5.055,5486.778)],
 [(103019,1.10749,6283.07585),(1721,1.0644,12566.1517),(702,3.142,0),
  (32,1.02,18849.23),(31,2.84,5507.55),(25,1.32,5223.69)],
 [(4359,5.7846,6283.0758),(124,5.579,12566.152),(12,3.14,0)],
 [(145,4.273,6283.076)],[(4,2.56,6283.08)]
]

// ── MARTE ────────────────────────────────────────────────────────
let marL: [[VTerm]] = [
 [(620347712,0,0),(18656368,5.05037100,3340.6124267),(1108217,5.40099837,6681.2248534),
  (91798,6.11005153,10021.8372801),(27745,3.78015612,5621.8429232),(12316,5.44681560,2274.1161752),
  (10610,2.93958560,2281.2304965),(8716,6.11006,13362.4497),(7775,3.33968,5088.629),
  (6798,0.36462,398.149),(4161,0.22815,3154.687),(3575,1.66187,2942.463),
  (3075,0.85697,191.448),(2628,0.64807,3337.089),(2580,0.0302,3344.135)],
 [(334085627474,0,0),(1458227,3.60433733,3340.6124267),(164901,3.92631478,6681.2248534),
  (19963,4.18621477,10021.8372801),(3452,4.7321,3154.687),(2485,4.61768,13362.4497)],
 [(58016,2.04979,3340.61243),(54188,0,0),(13906,2.45742,6681.22485),
  (2912,0,0),(349,3.919,10021.837)],
 [(1482,0.444,3340.612),(662,0.884,6681.225),(188,1.288,10021.837)],
 [(114,3.142,0)],[(1,3.14,0)]
]
let marB: [[VTerm]] = [
 [(3197135,3.76832042,3340.6124267),(298033,4.10616996,6681.2248534),(289105,0,0),
  (31366,4.44651052,10021.8372801),(3484,4.78813,13362.4497),(443,5.026,16703.062)],
 [(350069,5.36848036,3340.6124267),(14116,5.76801130,6681.2248534),(9671,5.47766046,10021.8372801),
  (1472,3.20286306,13362.4497),(426,0,0)],
 [(16727,0.60221633,3340.6124267),(4987,3.14159265,0),(1479,3.62276,6681.2249)],
 [(607,1.981,3340.612),(297,0,0)]
]
let marR: [[VTerm]] = [
 [(153033488,0,0),(14184953,3.47971284,3340.6124267),(660776,3.81783440,6681.2248534),
  (46179,4.15595316,10021.8372801),(8110,5.55255,2810.921),(7485,1.77239,5621.843),
  (5523,5.73561,13362.4497),(3825,4.49407,2281.23),(3604,3.39811,2942.463)],
 [(1107433,2.03250524,3340.6124267),(103176,2.37071606,6681.2248534),(12877,0,0),
  (10816,2.70888094,10021.8372801),(2457,2.0253,3154.687)],
 [(44242,0.47931,3340.6124),(8138,0.87,6681.22),(1275,1.22,10021.84)],
 [(1113,5.143,3340.612),(424,5.613,6681.225)]
]

// ── JÚPITER ──────────────────────────────────────────────────────
let jupL: [[VTerm]] = [
 [(59954691,0,0),(9695899,5.06191793,529.6909651),(573610,1.44406205,7.1135470),
  (306389,5.41734306,1059.3819302),(97178,4.14264738,632.7837539),(72903,3.64042168,522.5774180),
  (64264,3.41145165,103.0927742),(39806,2.29376740,419.4846438),(38858,1.27231755,316.3918770),
  (27965,1.78454589,536.8045120),(13590,5.77481250,1589.0728952),(8769,3.63001,949.1756),
  (8246,3.58227,206.1855),(7368,5.08101,735.8765),(6263,0.02497,213.2991)],
 [(52993480757,0,0),(489741,4.22066926,529.6909651),(228919,6.02647850,7.1135470),
  (27655,4.57265776,1059.3819302),(20721,5.45938880,522.5774180),(12106,0.16986810,536.8045120),
  (6068,4.4242,103.0928),(5765,5.46071,419.4846),(4189,0.99946,632.7838)],
 [(47234,4.32148,7.1135),(38966,0,0),(30629,2.93021,529.691),
  (3189,1.05505,522.5774),(2729,4.84507,536.8045)],
 [(6268,4.38641,7.11355),(5007,3.84091,529.69097),(1136,0,0)],
 [(669,0.853,7.114),(114,3.142,0)],[(12,0.70,7.11)]
]
let jupB: [[VTerm]] = [
 [(2268616,3.55852606,529.6909651),(110090,0,0),(109972,3.90809347,1059.3819302),
  (8101,3.6051,522.5774),(6438,0.30628,536.8045),(6044,4.25884,1589.0729)],
 [(177352,5.70166590,529.6909651),(3230,5.70538,1059.382),(3081,5.64785,522.5774),
  (2212,4.73499,536.8045),(1694,3.14159265,0)],
 [(403,0,0),(8564,5.5544,529.69097),(1007,3.8433,1059.382)],
 [(272,3.356,529.691)]
]
let jupR: [[VTerm]] = [
 [(520887429,0,0),(25209327,3.49108640,529.6909651),(610600,3.84115365,1059.3819302),
  (282029,2.57419919,632.7837539),(187647,2.07590588,522.5774180),(86793,0.71811745,419.4846438),
  (72062,0.21465724,536.8045120),(65517,5.97995026,316.3918770),(59980,4.12893048,949.1756089),
  (46115,3.48975590,735.8765135),(43526,6.04110219,1589.0728952),(31841,1.58088172,103.0927742)],
 [(1271802,2.64937512,529.6909651),(61661,3.00076028,1059.3819302),(53930,3.89599890,522.5774180),
  (26009,3.14159265,0),(25208,1.21267,536.8045),(21236,2.99886,419.4846)],
 [(79645,1.35467040,529.6909651),(8252,5.74,522.577),(7030,3.275,536.805)],
 [(2501,3.628,529.691)]
]

// ── SATURNO ──────────────────────────────────────────────────────
let satL: [[VTerm]] = [
 [(87401354,0,0),(11107660,3.96205090,213.2990954),(1414151,4.58581516,7.1135470),
  (398379,0.52112032,206.1855484),(350769,3.30329907,426.5981909),(206816,0.24658104,103.0927742),
  (79271,3.84007080,220.4126424),(23990,4.66976590,110.2063212),(16574,0.43719536,419.4846438),
  (15820,0.93808630,632.7837539),(15054,2.71670729,639.8972810),(14907,5.76903183,316.3918770),
  (14610,1.56518504,3.9321532),(13143,0.65092854,227.5260284),(12869,3.50504710,433.7117378)],
 [(21354295596,0,0),(1296855,1.82820532,213.2990954),(564347,2.88529225,7.1135470),
  (107679,2.27769690,206.1855484),(98323,1.08484100,426.5981909),(40255,2.04128200,220.4126424),
  (19942,1.27954720,103.0927742),(10512,2.74880360,14.2270940),(6939,0.40321700,639.8972810)],
 [(116441,1.179752,7.113547),(91921,0,0),(90592,1.46424470,213.2990954),
  (15277,4.05531060,206.1855484),(10631,0.25473370,220.4126424),(10605,5.40782200,426.5981909)],
 [(16039,5.73945,7.11355),(4250,4.58171,213.2991),(1907,4.76082,220.4126),
  (1466,5.91326,206.1855),(1162,5.61343,14.2271)],
 [(1662,3.9983,7.1135),(257,2.984,220.413),(114,3.142,0)],
 [(124,2.259,7.114)]
]
let satB: [[VTerm]] = [
 [(4330678,3.60284428,213.2990954),(240348,2.85238489,426.5981909),(84746,0,0),
  (34116,0.57297400,206.1855484),(30863,3.48441810,220.4126424),(14734,2.11846020,639.8972810),
  (9917,5.79072380,419.4846438),(6994,4.73604730,7.1135470)],
 [(397555,5.33299540,213.2990954),(49479,3.14159265,0),(18572,6.09919840,426.5981909),
  (14801,2.30586370,206.1855484),(9780,5.97517260,220.4126424)],
 [(20630,0.90721,213.2991),(3720,3.14159,0),(1622,3.92498,426.5982)],
 [(666,1.99,213.299),(632,5.698,426.598),(398,0,0)]
]
let satR: [[VTerm]] = [
 [(955758136,0,0),(52921382,2.39226220,213.2990954),(1873680,5.23549926,206.1855484),
  (1464664,1.64763416,426.5981909),(821891,5.93520510,316.3918770),(547507,5.01532790,103.0927742),
  (371684,2.27122330,220.4126424),(361778,3.13904920,7.1135470),(140618,5.70476500,632.7837539),
  (108975,3.29313600,639.8972810),(69007,5.94099650,419.4846438),(61053,0.94037680,433.7117378)],
 [(6182981,0.25843511,213.2990954),(506578,0.71114047,206.1855484),(341394,5.79635850,426.5981909),
  (188491,0.47215479,220.4126424),(186262,3.14159265,0),(143891,1.40744348,7.1135470)],
 [(436902,4.786717,213.299095),(71923,2.5007,206.18555),(49767,4.97168,220.41264),
  (43221,3.8694,426.59819),(29646,5.9631,7.11355)],
 [(20315,3.02176,213.2991),(8924,3.19311,206.1855),(6909,4.36059,426.5982)]
]

// ── URANO ────────────────────────────────────────────────────────
let uraL: [[VTerm]] = [
 [(548129294,0,0),(9260408,0.89106421,74.7815986),(1504248,3.62719262,1.4844727),
  (365982,1.89962234,73.2971213),(272328,3.35823671,149.5631971),(70328,5.39254093,63.7358983),
  (52685,1.59870443,76.2660759),(46362,1.03231262,2.9689454),(33952,1.29241665,11.0457002),
  (17458,3.29407564,77.7505532),(17187,2.47407040,350.3321196),(14918,3.96507304,796.2980068)],
 [(7502543122,0,0),(154458,5.24201945,74.7815986),(24456,1.71255176,1.4844727),
  (24192,0.37209152,73.2971213),(16468,1.25600210,149.5631971),(13007,2.10216740,11.0457002)],
 [(53033,0,0),(20714,6.05578130,74.7815986),(4905,0.355,1.4844727),(4497,1.67745,73.2971213)],
 [(6763,4.1735,74.7816),(1453,0,0)],
 [(114,3.142,0)]
]
let uraB: [[VTerm]] = [
 [(1346278,2.61877810,74.7815986),(62341,5.08111820,149.5631971),(61601,3.14159265,0),
  (9948,2.91270760,73.2971213),(9282,5.20904680,11.0457002),(7276,1.44933620,1.4844727)],
 [(206366,4.12343550,74.7815986),(8650,3.14159265,0),(7498,0.47443370,149.5631971),
  (2397,3.29723540,73.2971213)],
 [(9212,5.8004,74.7816),(557,0,0)],
 [(268,1.251,74.782)]
]
let uraR: [[VTerm]] = [
 [(1921264848,0,0),(88784984,5.60377527,74.7815986),(3440836,0.32836099,73.2971213),
  (2055653,1.78295435,149.5631971),(649322,4.52247640,76.2660759),(506492,1.25435038,1.4844727),
  (308569,0.83368905,11.0457002),(174901,3.26457264,148.0787198)],
 [(1479896,3.67205697,74.7815986),(71212,6.22219752,63.7358983),(68627,6.13462090,149.5631971),
  (24060,3.14159265,0),(21468,2.60103620,11.0457002)],
 [(22476,2.286,74.7816),(4727,3.14159,0),(3572,6.0099,63.7359)],
 [(538,0.814,74.782)]
]

// ── NEPTUNO ───────────────────────────────────────────────────────
let nepL: [[VTerm]] = [
 [(531188633,0,0),(1798476,2.90101273,38.1330356),(1019728,0.48580922,1.4844727),
  (124532,4.83008090,36.6485583),(42064,5.41054210,2.9689454),(37714,6.09221380,35.1640810),
  (33405,0,0),(16604,4.28425260,76.2660759)],
 [(3837687717,0,0),(16604,4.86319700,1.4844727),(15807,2.27798220,38.1330356)],
 [(53893,0,0),(296,1.855,1.485),(288,1.036,38.133)],
 [(31,0,0)],[(114,3.142,0)]
]
let nepB: [[VTerm]] = [
 [(3088623,1.44104375,38.1330356),(27780,5.91271180,76.2660759),(27624,0,0),
  (15448,3.50877680,39.6175129),(15448,0.11423320,36.6485583),(9721,5.31799300,1.4844727)],
 [(227279,3.80793460,38.1330356),(1803,1.97524770,76.2660759),(1433,3.14159265,0)],
 [(9691,5.5712,38.133),(79,3.63,76.266)],
 [(273,1.017,38.133)]
]
let nepR: [[VTerm]] = [
 [(3007013206,0,0),(27062259,1.32999459,38.1330356),(1691764,3.25186138,36.6485583),
  (807830,5.18592721,1.4844727),(537761,4.52113850,35.1640810),(495726,1.57105060,491.5579587),
  (274572,1.84552940,175.1660680),(270339,5.72408070,39.6175129)],
 [(236339,0.70498481,38.1330356),(13220,3.32015817,1.4844727),(8622,6.2118,35.1641)],
 [(4247,5.8991,38.133),(218,0,0)],
 [(166,4.552,38.133)]
]

// MARK: - Posición Heliocéntrica VSOP87

struct HelioPos { let L, B, R: Double }

func helioPos(_ planet: Planet, tau: Double) -> HelioPos {
    func mk(_ l: [[VTerm]], _ b: [[VTerm]], _ r: [[VTerm]]) -> HelioPos {
        HelioPos(L: normRad(vsop87(l, tau: tau) * 1e-8),
                 B: vsop87(b, tau: tau) * 1e-8,
                 R: vsop87(r, tau: tau) * 1e-8)
    }
    switch planet {
    case .mercury: return mk(merL, merB, merR)
    case .venus:   return mk(venL, venB, venR)
    case .mars:    return mk(marL, marB, marR)
    case .jupiter: return mk(jupL, jupB, jupR)
    case .saturn:  return mk(satL, satB, satR)
    case .uranus:  return mk(uraL, uraB, uraR)
    case .neptune: return mk(nepL, nepB, nepR)
    default:       return HelioPos(L: 0, B: 0, R: 1)
    }
}

func earthHelioPos(tau: Double) -> HelioPos {
    HelioPos(L: normRad(vsop87(earL, tau: tau) * 1e-8),
             B: vsop87(earB, tau: tau) * 1e-8,
             R: vsop87(earR, tau: tau) * 1e-8)
}

// MARK: - Luna (Meeus Cap.47, serie completa principal)
// Precisión ~10" en longitud, ~4" en latitud

func moonPosition(T: Double) -> (lambda: Double, beta: Double, distKm: Double) {
    // Argumentos fundamentales (grados)
    let Lp = norm360(218.3164477 + 481267.88123421*T - 0.0015786*T*T + T*T*T/538841 - T*T*T*T/65194000)
    let D  = norm360(297.8501921 + 445267.1114034*T - 0.0018819*T*T + T*T*T/545868 - T*T*T*T/113065000)
    let M  = norm360(357.5291092 + 35999.0502909*T  - 0.0001536*T*T + T*T*T/24490000)
    let Mp = norm360(134.9633964 + 477198.8675055*T + 0.0087414*T*T + T*T*T/69699 - T*T*T*T/14712000)
    let F  = norm360(93.2720950  + 483202.0175233*T - 0.0036539*T*T - T*T*T/3526000 + T*T*T*T/863310000)
    let A1 = norm360(119.75 + 131.849*T)
    let A2 = norm360(53.09  + 479264.290*T)
    let A3 = norm360(313.45 + 481266.484*T)
    let E  = 1.0 - 0.002516*T - 0.0000074*T*T

    // Tabla Meeus 47.A — términos principales de longitud y distancia
    typealias LRTerm = (Int,Int,Int,Int,Double,Double)
    let lrTerms: [LRTerm] = [
        (0,0,1,0,6288774,-20905355),(2,0,-1,0,1274027,-3699111),
        (2,0,0,0,658314,-2955968),(0,0,2,0,213618,-569925),
        (0,1,0,0,-185116,48888),(0,0,0,2,-114332,-3149),
        (2,0,-2,0,58793,246158),(2,-1,-1,0,57066,-152138),
        (2,0,1,0,53322,-170733),(2,-1,0,0,45758,-204586),
        (0,1,-1,0,-40923,-129620),(1,0,0,0,-34720,108743),
        (0,1,1,0,-30383,104755),(2,0,0,-2,15327,10321),
        (0,0,1,2,-12528,0),(0,0,1,-2,10980,79661),
        (4,0,-1,0,10675,-34782),(0,0,3,0,10034,-23210),
        (4,0,-2,0,8548,-21636),(2,1,-1,0,-7888,24208),
        (2,1,0,0,-6766,30824),(1,0,-1,0,-5163,-8379),
        (1,1,0,0,4987,-16675),(2,-1,1,0,4036,-12831),
        (2,0,2,0,3994,-10445),(4,0,0,0,3861,-11650),
        (2,0,-3,0,3665,14403),(0,1,-2,0,-2689,-7003),
        (2,0,-1,2,-2602,0),(2,-1,-2,0,2390,10056),
        (1,0,1,0,-2348,6322),(2,-2,0,0,2236,-9884),
        (0,1,2,0,-2120,5751),(0,2,0,0,-2069,0),
        (2,-2,-1,0,2048,-4950),(2,0,1,-2,-1773,4130),
        (2,0,0,2,-1595,0),(4,-1,-1,0,1215,-3958),
        (0,0,2,2,-1110,0),(3,0,-1,0,-892,3258),
        (2,1,1,0,-810,2616),(4,-1,-2,0,759,-1897),
        (0,2,-1,0,-713,-2117),(2,2,-1,0,-700,2354),
        (2,1,-2,0,691,0),(2,-1,0,-2,596,0),
        (4,0,1,0,549,-1423),(0,0,4,0,537,-1117),
        (4,-1,0,0,520,-1571),(1,0,-2,0,-487,-1739),
        (2,1,0,-2,-399,0),(0,0,2,-2,-381,-4421),
        (1,1,1,0,351,0),(3,0,-2,0,-340,0),
        (4,0,-3,0,330,0),(2,-1,2,0,327,0),
        (0,2,1,0,-323,1165),(1,1,-1,0,299,0),
        (2,0,3,0,294,0),(2,0,-1,-2,0,8752)
    ]

    var sumL = 0.0, sumR = 0.0
    for t in lrTerms {
        let arg = toRad(Double(t.0)*D + Double(t.1)*M + Double(t.2)*Mp + Double(t.3)*F)
        var eCorr = 1.0
        if abs(t.1) == 1 { eCorr = E }
        else if abs(t.1) == 2 { eCorr = E * E }
        sumL += t.4 * eCorr * sin(arg)
        sumR += t.5 * eCorr * cos(arg)
    }

    // Tabla 47.B — latitud
    typealias BTermStruct = (Int,Int,Int,Int,Double)
    let bTerms: [BTermStruct] = [
        (0,0,0,1,5128122),(0,0,1,1,280602),(0,0,1,-1,277693),
        (2,0,0,-1,173237),(2,0,-1,1,55413),(2,0,-1,-1,46271),
        (2,0,0,1,32573),(0,0,2,1,17198),(2,0,1,-1,9266),
        (0,0,2,-1,8822),(2,-1,0,-1,8216),(2,0,-2,-1,4324),
        (2,0,1,1,4200),(2,1,0,-1,-3359),(2,-1,-1,1,2463),
        (2,-1,0,1,2211),(2,-1,-1,-1,2065),(0,1,-1,-1,-1870),
        (4,0,-1,-1,1828),(0,1,0,1,-1794),(0,0,0,3,-1749),
        (0,1,-1,1,-1565),(1,0,0,1,-1491),(0,1,1,1,-1475),
        (0,1,1,-1,-1410),(0,1,0,-1,-1344),(1,0,0,-1,-1335),
        (0,0,3,1,1107),(4,0,0,-1,1021),(4,0,-1,1,833),
        (0,0,1,-3,777),(4,0,-2,1,671),(2,0,0,-3,607),
        (2,0,2,-1,596),(2,-1,1,-1,491),(2,0,-2,1,-451),
        (0,0,3,-1,439),(2,0,2,1,422),(2,0,-3,-1,421),
        (2,1,-1,1,-366),(2,1,0,1,-351),(4,0,0,1,331),
        (2,-1,1,1,315),(2,-2,0,-1,302),(0,0,1,3,-283),
        (2,1,1,-1,-229),(1,1,0,-1,223),(1,1,0,1,223),
        (0,1,-2,-1,-220),(2,1,-1,-1,-220),(1,0,1,1,-185),
        (2,-1,-2,-1,181),(0,1,2,1,-177),(4,0,-2,-1,176),
        (4,-1,-1,-1,166),(1,0,1,-1,-164),(4,0,1,-1,132),
        (1,0,-1,-1,-119),(4,-1,0,-1,115),(2,-2,0,1,107)
    ]

    var sumB = 0.0
    for t in bTerms {
        let arg = toRad(Double(t.0)*D + Double(t.1)*M + Double(t.2)*Mp + Double(t.3)*F)
        var eCorr = 1.0
        if abs(t.1) == 1 { eCorr = E }
        else if abs(t.1) == 2 { eCorr = E * E }
        sumB += t.4 * eCorr * sin(arg)
    }

    // Correcciones adicionales
    sumL += 3958*sin(toRad(A1)) + 1962*sin(toRad(Lp-F)) + 318*sin(toRad(A2))
    sumB += -2235*sin(toRad(Lp)) + 382*sin(toRad(A3)) + 175*sin(toRad(A1-F))
          + 175*sin(toRad(A1+F)) + 127*sin(toRad(Lp-Mp)) - 115*sin(toRad(Lp+Mp))

    let lambda  = norm360(Lp + sumL / 1000000.0)
    let beta    = sumB / 1000000.0
    let distKm  = 385000.56 + sumR / 1000.0

    return (lambda, beta, distKm)
}

// MARK: - Nutación y Oblicuidad

struct NutObl { let dPsi, dEps, epsilon: Double }

func nutObl(_ T: Double) -> NutObl {
    let D  = norm360(297.85036 + 445267.111480*T - 0.0019142*T*T + T*T*T/189474)
    let M  = norm360(357.52772 + 35999.050340*T  - 0.0001603*T*T - T*T*T/300000)
    let Mm = norm360(134.96298 + 477198.867398*T + 0.0086972*T*T + T*T*T/56250)
    let F  = norm360(93.27191  + 483202.017538*T - 0.0036825*T*T + T*T*T/327270)
    let Om = norm360(125.04452 - 1934.136261*T   + 0.0020708*T*T + T*T*T/450000)
    typealias NT = (Int,Int,Int,Int,Int,Double,Double,Double,Double)
    let nt: [NT] = [
        (0,0,0,0,1,-171996,-174.2,92025,8.9),(-2,0,0,2,2,-13187,-1.6,5736,-3.1),
        (0,0,0,2,2,-2274,-0.2,977,-0.5),(0,0,0,0,2,2062,0.2,-895,0.5),
        (0,1,0,0,0,1426,-3.4,54,-0.1),(0,0,1,0,0,712,0.1,-7,0),
        (-2,1,0,2,2,-517,1.2,224,-0.6),(0,0,0,2,1,-386,-0.4,200,0),
        (0,0,1,2,2,-301,0,129,-0.1),(-2,-1,0,2,2,217,-0.5,-95,0.3),
        (-2,0,1,0,0,-158,0,0,0),(-2,0,0,2,1,129,0.1,-70,0),
        (0,0,-1,2,2,123,0,-53,0),(2,0,0,0,0,63,0,0,0),
        (0,0,1,0,1,63,0.1,-33,0),(2,0,-1,2,2,-59,0,26,0),
        (0,0,-1,0,1,-58,-0.1,32,0)
    ]
    let args = [D,M,Mm,F,Om].map { toRad($0) }
    var dPsi = 0.0, dEps = 0.0
    for t in nt {
        let ang = Double(t.0)*args[0]+Double(t.1)*args[1]+Double(t.2)*args[2]+Double(t.3)*args[3]+Double(t.4)*args[4]
        dPsi += (t.5 + t.6*T)*sin(ang); dEps += (t.7 + t.8*T)*cos(ang)
    }
    dPsi /= 10000; dEps /= 10000
    let eps0 = 23 + 26.0/60 + 21.448/3600
               - (4680.93/3600)*T - (1.55/3600)*T*T + (1999.25/3600)*T*T*T
               - (51.38/3600)*T*T*T*T - (249.67/3600)*pow(T,5)
    return NutObl(dPsi: dPsi, dEps: dEps, epsilon: eps0 + dEps/3600)
}

// MARK: - Eclíptica → Ecuatorial

func geoEcl(_ p: HelioPos, _ e: HelioPos) -> (lam: Double, bet: Double, dist: Double) {
    let X = p.R*cos(p.B)*cos(p.L) - e.R*cos(e.B)*cos(e.L)
    let Y = p.R*cos(p.B)*sin(p.L) - e.R*cos(e.B)*sin(e.L)
    let Z = p.R*sin(p.B) - e.R*sin(e.B)
    let dist = sqrt(X*X+Y*Y+Z*Z)
    var lam = toDeg(atan2(Y,X)); if lam < 0 { lam += 360 }
    let bet = toDeg(asin(Z/dist))
    return (lam, bet, dist)
}

func ecl2equ(lam: Double, bet: Double, eps: Double) -> (ra: Double, dec: Double) {
    let l=toRad(lam), b=toRad(bet), e=toRad(eps)
    let ra  = toDeg(atan2(sin(l)*cos(e) - tan(b)*sin(e), cos(l)))
    let dec = toDeg(asin(sin(b)*cos(e) + cos(b)*sin(e)*sin(l)))
    return (norm360(ra), dec)
}

// MARK: - Zodíaco

let zodiacNames = ["Aries ♈","Tauro ♉","Géminis ♊","Cáncer ♋",
                   "Leo ♌","Virgo ♍","Libra ♎","Escorpio ♏",
                   "Sagitario ♐","Capricornio ♑","Acuario ♒","Piscis ♓"]

func zodiac(_ lon: Double) -> (sign: String, deg: Double) {
    (zodiacNames[Int(lon/30) % 12], lon.truncatingRemainder(dividingBy: 30))
}

// MARK: - Formatos

func dmsStr(_ deg: Double) -> String {
    let tot = abs(deg)*3600
    let d = Int(tot/3600), m = Int((tot.truncatingRemainder(dividingBy:3600))/60)
    let s = tot.truncatingRemainder(dividingBy: 60)
    return String(format:"%@%d°%02d'%05.2f\"", deg<0 ? "-":"", d, m, s)
}
func lonStr(_ lon: Double) -> String {
    let z = zodiac(lon); let d = Int(z.deg); let m = Int((z.deg-Double(d))*60)
    let s = ((z.deg-Double(d))*60-Double(m))*60
    return String(format:"%d°%02d'%04.1f\" %@", d, m, s, z.sign)
}
func raStr(_ deg: Double) -> String {
    let h=deg/15, hh=Int(h), mm=Int((h-Double(hh))*60)
    let ss=((h-Double(hh))*60-Double(mm))*60
    return String(format:"%02dh %02dm %05.2fs", hh, mm, ss)
}

// MARK: - Día Juliano

func julianDay(y: Int, mo: Int, d: Int, h: Double, mi: Double, s: Double) -> Double {
    var Y=y, M=mo
    let D = Double(d)+(h+mi/60+s/3600)/24
    if M <= 2 { Y -= 1; M += 12 }
    let A = Int(Double(Y)/100), B = 2-A+A/4
    return Double(Int(365.25*Double(Y+4716)))+Double(Int(30.6001*Double(M+1)))+D+Double(B)-1524.5
}

func jdFromDate(_ date: Date) -> Double {
    let unixEpochJD = 2440587.5
    return unixEpochJD + date.timeIntervalSince1970 / 86400.0
}

func dateFromJD(_ jd: Double) -> Date {
    let unixEpochJD = 2440587.5
    return Date(timeIntervalSince1970: (jd - unixEpochJD) * 86400.0)
}

// MARK: - Modo de vista

enum ViewMode: String, CaseIterable {
    case geocentric  = "Geocéntrico"
    case heliocentric = "Heliocéntrico"
}

// MARK: - Cálculo Principal

func calcPlanets(jd JD: Double, mode: ViewMode = .geocentric) -> [PlanetPosition] {
    let T   = (JD - 2451545.0)/36525.0
    let tau = T/10.0
    let nut = nutObl(T)
    let earthH = HelioPos(L: normRad(vsop87(earL, tau: tau) * 1e-8),
                          B: vsop87(earB, tau: tau) * 1e-8,
                          R: vsop87(earR, tau: tau) * 1e-8)

    // Sol geocéntrico aparente
    let sunGeoLon = norm360(
        toDeg(earthH.L) + 180
        + nut.dPsi/3600
        - 20.4898/3600/earthH.R
        - 0.00569
        - 0.00478*sin(toRad(125.04 - 1934.136*T))
    )
    let (sunRA, sunDec) = ecl2equ(lam: sunGeoLon, bet: 0, eps: nut.epsilon)
    let sunZ = zodiac(sunGeoLon)

    var out: [PlanetPosition] = []

    // ── SOL ──
    if mode == .geocentric {
        out.append(PlanetPosition(
            planet:.sun, eclipticLongitude:sunGeoLon, eclipticLatitude:0,
            helioLongitude:norm360(toDeg(earthH.L)+180), helioLatitude:-toDeg(earthH.B),
            helioRadius:earthH.R, geocentricDistance:earthH.R,
            rightAscension:sunRA, declination:sunDec,
            zodiacSign:sunZ.sign, zodiacDegree:sunZ.deg, retrograde:false, elongation:0))
    }

    // ── LUNA (solo modo geocéntrico) ──
    if mode == .geocentric {
        let (moonLam, moonBet, moonDist) = moonPosition(T: T)
        // Aplicar nutación
        let moonLamNut = norm360(moonLam + nut.dPsi/3600)
        let (moonRA, moonDec) = ecl2equ(lam: moonLamNut, bet: moonBet, eps: nut.epsilon)
        let moonZ = zodiac(moonLamNut)
        // Fase (elongación de la Luna respecto al Sol)
        var moonElong = abs(angleDiff(moonLamNut, sunGeoLon))
        if moonElong > 180 { moonElong = 360 - moonElong }
        // Retrógrado: Luna no tiene retrogradación real, pero calculamos movimiento
        let T2 = ((JD-1)-2451545)/36525
        let (moonLam2,_,_) = moonPosition(T: T2)
        let moonRetro = angleDiff(moonLamNut, norm360(moonLam2 + nutObl(T2).dPsi/3600)) < 0
        out.append(PlanetPosition(
            planet:.moon, eclipticLongitude:moonLamNut, eclipticLatitude:moonBet,
            helioLongitude:moonLamNut, helioLatitude:moonBet,
            helioRadius:moonDist/149597870.7, geocentricDistance:moonDist/149597870.7,
            rightAscension:moonRA, declination:moonDec,
            zodiacSign:moonZ.sign, zodiacDegree:moonZ.deg, retrograde:moonRetro, elongation:moonElong))
    }

    // ── PLANETAS ──
    for pl in [Planet.mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune] {
        let h0 = helioPos(pl, tau: tau)

        if mode == .heliocentric {
            // Posición heliocéntrica directa de VSOP87
            let helioLon = norm360(toDeg(h0.L))
            let helioLat = toDeg(h0.B)
            let z = zodiac(helioLon)
            let (ra, dec) = ecl2equ(lam: helioLon, bet: helioLat, eps: nut.epsilon)
            out.append(PlanetPosition(
                planet: pl,
                eclipticLongitude: helioLon,
                eclipticLatitude: helioLat,
                helioLongitude: helioLon,
                helioLatitude: helioLat,
                helioRadius: h0.R,
                geocentricDistance: h0.R,
                rightAscension: ra,
                declination: dec,
                zodiacSign: z.sign,
                zodiacDegree: z.deg,
                retrograde: false,
                elongation: 0))
        } else {
            // Geocéntrico con correcciones
            let g0 = geoEcl(h0, earthH)
            let tauLT = tau - g0.dist*0.0057755183/(36525*10)
            let hLT = helioPos(pl, tau: tauLT)
            var (lam, bet, dist) = geoEcl(hLT, earthH)
            let lpP = norm360(lam - 1.397*T - 0.00031*T*T)
            lam += -0.09033/3600 + 0.03916/3600*(cos(toRad(lpP))-sin(toRad(lpP)))*tan(toRad(bet))
            bet +=  0.03916/3600*(cos(toRad(lpP))+sin(toRad(lpP)))
            lam += nut.dPsi/3600
            lam -= 20.4898/3600/dist * cos(toRad(sunGeoLon-lam)) / max(cos(toRad(bet)),0.001)
            lam = norm360(lam)
            let (ra,dec) = ecl2equ(lam: lam, bet: bet, eps: nut.epsilon)
            let z = zodiac(lam)
            // Retrógrado
            let T2 = ((JD-1)-2451545)/36525; let tau2 = T2/10
            let eH2 = HelioPos(L: normRad(vsop87(earL,tau:tau2)*1e-8),
                               B: vsop87(earB,tau:tau2)*1e-8,
                               R: vsop87(earR,tau:tau2)*1e-8)
            let hLT2 = helioPos(pl, tau: tau2 - geoEcl(helioPos(pl,tau:tau2),eH2).dist*0.0057755183/(36525*10))
            let g2 = geoEcl(hLT2,eH2)
            let lam2 = norm360(g2.lam+nutObl(T2).dPsi/3600)
            var diff = lam-lam2; if diff>180{diff-=360}; if diff < (-180){diff+=360}
            let retro = diff<0
            var elong = abs(norm360(lam-sunGeoLon)); if elong>180{elong=360-elong}
            out.append(PlanetPosition(
                planet:pl, eclipticLongitude:lam, eclipticLatitude:bet,
                helioLongitude:norm360(toDeg(h0.L)), helioLatitude:toDeg(h0.B),
                helioRadius:h0.R, geocentricDistance:dist,
                rightAscension:ra, declination:dec,
                zodiacSign:z.sign, zodiacDegree:z.deg, retrograde:retro, elongation:elong))
        }
    }

    // En modo heliocéntrico agregar la Tierra
    if mode == .heliocentric {
        let earthLon = norm360(toDeg(earthH.L))
        let z = zodiac(earthLon)
        let (ra,dec) = ecl2equ(lam: earthLon, bet: toDeg(earthH.B), eps: nut.epsilon)
        out.insert(PlanetPosition(
            planet:.sun, eclipticLongitude:earthLon, eclipticLatitude:toDeg(earthH.B),
            helioLongitude:earthLon, helioLatitude:toDeg(earthH.B),
            helioRadius:earthH.R, geocentricDistance:0,
            rightAscension:ra, declination:dec,
            zodiacSign:z.sign, zodiacDegree:z.deg, retrograde:false, elongation:0), at:0)
    }

    return out
}

func calcPlanets(year: Int, month: Int, day: Int,
                 hour: Double, minute: Double, second: Double,
                 timezone: Double, mode: ViewMode = .geocentric) -> [PlanetPosition] {
    let JD = julianDay(y: year, mo: month, d: day, h: hour-timezone, mi: minute, s: second)
    return calcPlanets(jd: JD, mode: mode)
}

// MARK: - Grados recorridos

struct TravelResult {
    let planet: Planet; let lonStart, lonEnd, totalTravel, directTravel, retroTravel: Double
    let stationCount: Int
}

func degreesTraversed(planet: Planet, jdStart: Double, jdEnd: Double, steps: Int = 1440) -> TravelResult {
    let step = (jdEnd - jdStart) / Double(steps)
    var positions: [(Double, Double)] = []
    var jd = jdStart
    for _ in 0...steps {
        let pos = calcPlanets(jd: jd).first { $0.planet == planet }?.eclipticLongitude ?? 0
        positions.append((jd, pos)); jd += step
    }
    let lonStart = positions.first!.1, lonEnd = positions.last!.1
    var total = 0.0, direct = 0.0, retroTotal = 0.0, stations = 0
    var prevRetro = false
    for i in 1..<positions.count {
        var d = positions[i].1 - positions[i-1].1
        if d > 180 { d -= 360 }; if d < (-180) { d += 360 }
        let isRetro = d < 0
        if i > 1 && isRetro != prevRetro { stations += 1 }
        prevRetro = isRetro; total += d
        if isRetro { retroTotal += d } else { direct += d }
    }
    return TravelResult(planet:planet, lonStart:lonStart, lonEnd:lonEnd,
                        totalTravel:total, directTravel:direct, retroTravel:retroTotal, stationCount:stations)
}

// MARK: - Ángulos

struct AnglePair {
    let p1, p2: Planet; let angle, signedAngle: Double; let aspect: String
}

func aspectName(_ angle: Double) -> String {
    let a = abs(angle)
    if a < 8   { return "Conjunción (0°)" }
    if abs(a-30)  < 3 { return "Semisextil (30°)" }
    if abs(a-45)  < 3 { return "Semicuadratura (45°)" }
    if abs(a-60)  < 6 { return "Sextil (60°)" }
    if abs(a-90)  < 8 { return "Cuadratura (90°)" }
    if abs(a-120) < 8 { return "Trígono (120°)" }
    if abs(a-135) < 3 { return "Sesquicuadratura (135°)" }
    if abs(a-150) < 3 { return "Quincuncio (150°)" }
    if a > 172        { return "Oposición (180°)" }
    return ""
}

func calcAngles(positions: [PlanetPosition]) -> [AnglePair] {
    var pairs: [AnglePair] = []
    for i in 0..<positions.count {
        for j in (i+1)..<positions.count {
            let d = angleDiff(positions[i].eclipticLongitude, positions[j].eclipticLongitude)
            pairs.append(AnglePair(p1:positions[i].planet, p2:positions[j].planet,
                                   angle:abs(d), signedAngle:d, aspect:aspectName(d)))
        }
    }
    return pairs
}

// MARK: - Búsqueda

struct SearchResult {
    let jd: Double; let date: Date; let longitude: Double; let planet: Planet; let retrograde: Bool
}

func searchPlanetAtDegree(planet: Planet, targetLon: Double,
                          jdStart: Double, jdEnd: Double,
                          tolerance: Double = 0.05) -> [SearchResult] {
    var results: [SearchResult] = []
    let stepCoarse = 1.0/24.0
    var jd = jdStart
    while jd <= jdEnd {
        let lon = calcPlanets(jd: jd).first { $0.planet == planet }?.eclipticLongitude ?? 0
        var diff = lon - targetLon; if diff>180{diff-=360}; if diff < (-180){diff+=360}
        if abs(diff) < tolerance {
            if let r = refineSearch(planet:planet, targetLon:targetLon, jd1:jd-stepCoarse, jd2:jd+stepCoarse, iterations:14) {
                if results.isEmpty || abs(r.jd-(results.last?.jd ?? 0)) > 0.5 { results.append(r) }
            }
        }
        jd += stepCoarse
    }
    return results
}

func refineSearch(planet: Planet, targetLon: Double, jd1: Double, jd2: Double, iterations: Int) -> SearchResult? {
    var lo = jd1, hi = jd2
    for _ in 0..<iterations {
        let mid = (lo+hi)/2
        let lon = calcPlanets(jd: mid).first { $0.planet == planet }?.eclipticLongitude ?? 0
        var diff = lon-targetLon; if diff>180{diff-=360}; if diff < (-180){diff+=360}
        if diff < 0 { lo = mid } else { hi = mid }
    }
    let jdFinal = (lo+hi)/2
    let pos = calcPlanets(jd: jdFinal).first { $0.planet == planet }
    return SearchResult(jd:jdFinal, date:dateFromJD(jdFinal),
                        longitude:pos?.eclipticLongitude ?? targetLon,
                        planet:planet, retrograde:pos?.retrograde ?? false)
}

func searchPlanetsAtAngle(p1: Planet, p2: Planet, targetAngle: Double,
                          jdStart: Double, jdEnd: Double,
                          tolerance: Double = 0.5) -> [SearchResult] {
    var results: [SearchResult] = []
    let step = 1.0/24.0; var jd = jdStart
    while jd <= jdEnd {
        let pos = calcPlanets(jd: jd)
        if let pos1 = pos.first(where:{$0.planet==p1}), let pos2 = pos.first(where:{$0.planet==p2}) {
            var ang = abs(angleDiff(pos1.eclipticLongitude, pos2.eclipticLongitude))
            if ang > 180 { ang = 360-ang }
            if abs(ang-targetAngle) < tolerance {
                let r = SearchResult(jd:jd, date:dateFromJD(jd), longitude:ang, planet:p1, retrograde:false)
                if results.isEmpty || abs(jd-(results.last?.jd ?? 0)) > 0.5 { results.append(r) }
            }
        }
        jd += step
    }
    return results
}

// MARK: - Formatters

let dateFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm"; f.locale = Locale(identifier:"es_MX"); return f
}()
let fullDateFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm:ss"; f.locale = Locale(identifier:"es_MX"); return f
}()
