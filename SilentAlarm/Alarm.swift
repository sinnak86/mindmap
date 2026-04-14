import Foundation

// MARK: - Weekday

enum Weekday: Int, CaseIterable, Codable, Hashable {
    case sun = 1, mon, tue, wed, thu, fri, sat

    var shortName: String {
        switch self {
        case .sun: return "일"
        case .mon: return "월"
        case .tue: return "화"
        case .wed: return "수"
        case .thu: return "목"
        case .fri: return "금"
        case .sat: return "토"
        }
    }
}

// MARK: - AlarmSound

enum AlarmSound: String, CaseIterable, Codable {
    case gentle
    case classic
    case digital
    case chime
    case nature
    case pulse

    var displayName: String {
        switch self {
        case .gentle:  return "부드러운 울림"
        case .classic: return "클래식 비프"
        case .digital: return "디지털 알람"
        case .chime:   return "차임벨"
        case .nature:  return "자연의 소리"
        case .pulse:   return "맥박음"
        }
    }
}

// MARK: - Alarm

struct Alarm: Codable, Identifiable, Equatable {
    var id: UUID
    var label: String
    var hour: Int
    var minute: Int
    var days: Set<Weekday>
    var soundID: AlarmSound
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        label: String = "알람",
        hour: Int,
        minute: Int,
        days: Set<Weekday> = Set(Weekday.allCases),
        soundID: AlarmSound = .gentle,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.label = label
        self.hour = hour
        self.minute = minute
        self.days = days
        self.soundID = soundID
        self.isEnabled = isEnabled
    }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var daysString: String {
        if days.count == 7 {
            return "매일"
        }
        let ordered = Weekday.allCases.filter { days.contains($0) }
        return ordered.map { $0.shortName }.joined()
    }

    static func == (lhs: Alarm, rhs: Alarm) -> Bool {
        lhs.id == rhs.id
    }
}
