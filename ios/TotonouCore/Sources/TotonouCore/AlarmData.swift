#if canImport(AlarmKit)
import AlarmKit

/// What a quest alarm carries. It lives in TotonouCore because the app schedules
/// the alarm and the widget extension draws its snooze countdown, and both
/// must agree on the exact type.
@available(iOS 26.0, *)
public struct QuestAlarmData: AlarmMetadata {
    public var title: String

    public init(title: String) {
        self.title = title
    }
}
#endif
