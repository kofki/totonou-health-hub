import Foundation

/// The norms the Coach compares you with, for men aged 20 to 29. Points are the
/// 10th, 25th, 50th, 75th, 90th and 99th percentile. Researched 2026-11-25;
/// where a study gave only a median and spread, the rest was fitted and the
/// norm is marked estimated. Bryan Johnson's values are his own published ones.
public enum NormCatalog {
    public static let all: [Norm] = [
        Norm(id: "vo2Max", title: "VO2 max", unit: "ml/kg/min", group: .fitness, stat: .vitality,
             points: [32.1, 40.1, 48.0, 55.2, 61.8, 75],
             athletes: [66, 70, 75, 80, 84, 90], athleteGroup: "endurance athletes",
             worldClass: 96.7, worldClassBy: "Svendsen, 2012", bryanJohnson: 58.7,
             source: "FRIEND registry, Kaminsky 2015", estimated: true),
        Norm(id: "steps", title: "Steps a day", unit: "steps", group: .fitness, stat: .vitality,
             points: [4000, 5800, 7800, 10200, 13000, 20000],
             // A very active lifestyle rather than training: farming Amish men walk ~18,400 a day.
             athletes: [12000, 15000, 18400, 21800, 24800, 30000], athleteGroup: "very active men (Amish farmers)",
             source: "Garmin 2024 report, Althoff 2017", estimated: true),
        Norm(id: "restingHeartRate", title: "Resting heart rate", unit: "bpm", group: .heart, stat: .vitality,
             higherIsBetter: false, points: [72, 67, 62, 57, 52, 45],
             athletes: [56, 52, 47, 42, 39, 33], athleteGroup: "endurance athletes",
             worldClass: 29, worldClassBy: "Froome, reported", bryanJohnson: 42,
             source: "Quer 2020, 92k Fitbit users", estimated: true),
        // Garmin reports overnight RMSSD; Bryan Johnson's 51 ms is WHOOP RMSSD.
        Norm(id: "hrvRMSSD", title: "HRV, overnight", unit: "ms", group: .heart, stat: .vitality,
             points: [31, 40, 52, 68, 87, 130],
             athletes: [42, 55, 68, 83, 97, 125], athleteGroup: "young skiers, small study", bryanJohnson: 51,
             source: "Ultrahuman, 189k men", estimated: true),
        // Apple Health reports SDNN, a different measure with its own norms.
        Norm(id: "hrvSDNN", title: "HRV (SDNN)", unit: "ms", group: .heart, stat: .vitality,
             points: [23, 36, 50, 64, 77, 100],
             athletes: [45, 60, 78, 98, 118, 160], athleteGroup: "endurance athletes (ECG)",
             source: "KORA S4 cohort, Voss 2015", estimated: true),
        // More sleep is not always better: past about 9 hours the ranking stops meaning much.
        Norm(id: "sleepHours", title: "Sleep", unit: "h", group: .recovery, stat: .vitality,
             points: [5.75, 6.17, 6.64, 7.10, 7.52, 8.25],
             athletes: [5.7, 6.2, 6.7, 7.2, 7.7, 8.6], athleteGroup: "elite athletes",
             source: "Fitbit, 163k users, 2022", estimated: true),
        Norm(id: "sleepScore", title: "Garmin sleep score", unit: "", group: .recovery, stat: .vitality,
             points: [58, 64, 71, 78, 84, 93], bryanJohnson: 100,
             source: "Garmin 2024 report (mean 71)", estimated: true),
        // Among people who log their lifts, so stricter than the whole population.
        Norm(id: "bench", title: "Bench press", unit: "x body weight", group: .strength, stat: .strength,
             points: [0.75, 1.05, 1.25, 1.45, 1.75, 2.4],
             athletes: [1.13, 1.31, 1.51, 1.71, 1.90, 2.21], athleteGroup: "raw powerlifters, 83 kg",
             worldClass: 2.64, worldClassBy: "Borenstein, 219 kg", source: "StrengthLevel, OpenPowerlifting", estimated: true),
        Norm(id: "squat", title: "Back squat", unit: "x body weight", group: .strength, stat: .strength,
             points: [1.0, 1.35, 1.75, 2.15, 2.5, 3.2],
             athletes: [1.66, 1.93, 2.23, 2.53, 2.80, 3.27], athleteGroup: "raw powerlifters, 83 kg",
             worldClass: 4.07, worldClassBy: "Orhii, 338 kg", source: "StrengthLevel, OpenPowerlifting", estimated: true),
        Norm(id: "deadlift", title: "Deadlift", unit: "x body weight", group: .strength, stat: .strength,
             points: [1.25, 1.6, 2.0, 2.4, 2.9, 3.75],
             athletes: [2.05, 2.32, 2.62, 2.92, 3.19, 3.66], athleteGroup: "raw powerlifters, 83 kg",
             worldClass: 4.62, worldClassBy: "Omisakin, 383.5 kg", source: "StrengthLevel, OpenPowerlifting", estimated: true),
        Norm(id: "pushUps", title: "Push-ups", unit: "reps", group: .strength, stat: .strength,
             points: [17, 22, 25, 29, 36, 50],
             // Soldiers do hand-release push-ups in 2 minutes: harder than one ordinary set.
             athletes: [20, 28, 37, 46, 53, 65], athleteGroup: "soldiers (hand-release, 2 min)",
             worldClass: 61, worldClassBy: "US Army top score, ages 22-26", source: "CSEP norms, US Army 2025", estimated: true),
        // No published percentile table exists; averages run from 2.8 to 7 hours a day.
        Norm(id: "screenMinutes", title: "Locked apps a day", unit: "min", group: .habits, stat: .willpower,
             higherIsBetter: false, points: [480, 360, 250, 165, 110, 45],
             source: "estimated from usage studies", estimated: true),
    ]

    public static func norm(_ id: String) -> Norm? { all.first { $0.id == id } }
}
