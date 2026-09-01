import Foundation
import HealthKit

/// Thin wrapper around HealthKit for reading/writing "Mindful Minutes".
///
/// Everything degrades gracefully: if Health is unavailable or the user denies
/// permission, the calls simply do nothing (or return empty) and the app keeps
/// working with its own local database.
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    private var mindfulType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .mindfulSession)
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Prompts the user for permission to read and write mindful sessions.
    /// Safe to call every launch — the system only shows the prompt once.
    func requestAuthorization() async {
        guard isAvailable, let mindfulType else { return }
        do {
            try await store.requestAuthorization(toShare: [mindfulType], read: [mindfulType])
        } catch {
            print("HealthKit authorization failed: \(error)")
        }
    }

    /// Writes a mindful session to Apple Health. No-ops if unavailable or
    /// unauthorized.
    func saveMindfulSession(start: Date, minutes: Int) async {
        guard isAvailable, let mindfulType else { return }
        let end = start.addingTimeInterval(Double(minutes) * 60)
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )
        do {
            try await store.save(sample)
        } catch {
            print("HealthKit save failed: \(error)")
        }
    }

    /// Reads mindful sessions from Apple Health, **excluding** ones this app
    /// wrote itself (those are already counted from our local database, so
    /// including them would double-count). This is how sessions from the Apple
    /// Watch, Calm, Headspace, etc. flow into the stats.
    func readExternalMindfulSessions() async -> [MindfulEntry] {
        guard isAvailable, let mindfulType else { return [] }

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: mindfulType)],
            sortDescriptors: []
        )

        do {
            let samples = try await descriptor.result(for: store)
            let ownBundleID = Bundle.main.bundleIdentifier
            return samples.compactMap { sample in
                // Skip samples this app authored — our DB is the source of truth for those.
                if sample.sourceRevision.source.bundleIdentifier == ownBundleID { return nil }
                let seconds = sample.endDate.timeIntervalSince(sample.startDate)
                let minutes = max(1, Int((seconds / 60).rounded()))
                return MindfulEntry(date: sample.startDate, minutes: minutes)
            }
        } catch {
            print("HealthKit read failed: \(error)")
            return []
        }
    }
}
