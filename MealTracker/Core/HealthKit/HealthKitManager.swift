import Foundation
import HealthKit
import Observation

/// Wraps HKHealthStore behind a single @Observable, @MainActor manager so the rest of the app
/// never touches HealthKit types directly. HealthKit deliberately never reveals whether a given
/// read type was actually granted (only whether the request round-tripped) — `isAuthorized` here
/// just tracks "the user has completed the request flow", not per-type grant status. Every
/// read/write method tolerates a denied or partially-denied state by returning nil/false rather
/// than throwing, the same way the rest of the app treats HealthKit as an optional enhancement
/// (e.g. camera/Apple Intelligence unavailability).
@Observable
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()

    static var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private(set) var isAuthorized: Bool {
        didSet { UserDefaults.standard.set(isAuthorized, forKey: Self.authorizedDefaultsKey) }
    }

    private let store = HKHealthStore()
    private static let authorizedDefaultsKey = "HealthKitManager.isAuthorized"

    private init() {
        isAuthorized = UserDefaults.standard.bool(forKey: Self.authorizedDefaultsKey)
    }

    private static let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    private static let heightType = HKQuantityType.quantityType(forIdentifier: .height)!
    private static let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    private static let dietaryEnergyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
    private static let dietaryProteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein)!
    private static let dietaryCarbType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)!
    private static let dietaryFatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal)!
    private static let foodCorrelationType = HKCorrelationType.correlationType(forIdentifier: .food)!
    private static let dateOfBirthType = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!
    private static let biologicalSexType = HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!

    // Only the types the app actually reads/writes — HealthKit authorization is a one-shot
    // prompt, so asking for anything unused just widens the permission surface for no benefit.
    private static let readTypes: Set<HKObjectType> = [
        bodyMassType, heightType, activeEnergyType, dateOfBirthType, biologicalSexType
    ]
    private static let writeTypes: Set<HKSampleType> = [
        bodyMassType, dietaryEnergyType, dietaryProteinType, dietaryCarbType, dietaryFatType, foodCorrelationType
    ]

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard Self.isHealthDataAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: Self.writeTypes, read: Self.readTypes)
            isAuthorized = true
            return true
        } catch {
            return false
        }
    }

    // MARK: Reads

    func activeEnergyBurnedToday() async -> Double? {
        guard isAuthorized else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: Date().startOfDay, end: Date().endOfDay, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: Self.activeEnergyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()))
            }
            store.execute(query)
        }
    }

    /// Most recent body-mass sample in HealthKit (e.g. logged via a scale app or the Health app
    /// directly), used to offer a one-way import when it's newer than our own latest entry.
    func latestBodyMass() async -> (weightKG: Double, date: Date)? {
        guard let sample = await latestQuantitySample(type: Self.bodyMassType) else { return nil }
        return (sample.quantity.doubleValue(for: .gramUnit(with: .kilo)), sample.startDate)
    }

    private func latestQuantitySample(type: HKQuantityType) async -> HKQuantitySample? {
        guard isAuthorized else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            store.execute(query)
        }
    }

    struct StartingProfileData {
        var sex: BiologicalSex?
        var birthDate: Date?
        var heightCM: Double?
        var weightKG: Double?
    }

    /// Best-effort pull of onboarding basics from HealthKit, so a new user with existing Health
    /// data doesn't have to retype what the Health app already knows. Each field is independently
    /// optional — a device with only some of this data populated still prefills what it can.
    func fetchStartingProfileData() async -> StartingProfileData {
        guard isAuthorized else { return StartingProfileData() }
        var data = StartingProfileData()

        if let components = try? store.dateOfBirthComponents(), let date = Calendar.current.date(from: components) {
            data.birthDate = date
        }
        if let sex = try? store.biologicalSex() {
            switch sex.biologicalSex {
            case .male: data.sex = .male
            case .female: data.sex = .female
            default: break
            }
        }
        if let heightSample = await latestQuantitySample(type: Self.heightType) {
            data.heightCM = heightSample.quantity.doubleValue(for: .meterUnit(with: .centi))
        }
        data.weightKG = await latestBodyMass()?.weightKG

        return data
    }

    // MARK: Writes

    @discardableResult
    func saveBodyMass(kg: Double, date: Date) async -> Bool {
        guard isAuthorized else { return false }
        let sample = HKQuantitySample(
            type: Self.bodyMassType,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
            start: date,
            end: date
        )
        do {
            try await store.save(sample)
            return true
        } catch {
            return false
        }
    }

    /// Saves a logged entry's energy/macros as a correlated "food" entry, mirroring how the
    /// Health app itself groups nutrition samples, and returns the correlation's UUID so the
    /// caller can store it on the `LoggedEntry` for later update/delete instead of duplicating.
    func saveDietaryEntry(
        name: String,
        calories: Double,
        proteinGrams: Double,
        carbGrams: Double,
        fatGrams: Double,
        date: Date
    ) async -> String? {
        guard isAuthorized else { return nil }
        let objects: Set<HKSample> = [
            HKQuantitySample(type: Self.dietaryEnergyType, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories), start: date, end: date),
            HKQuantitySample(type: Self.dietaryProteinType, quantity: HKQuantity(unit: .gram(), doubleValue: proteinGrams), start: date, end: date),
            HKQuantitySample(type: Self.dietaryCarbType, quantity: HKQuantity(unit: .gram(), doubleValue: carbGrams), start: date, end: date),
            HKQuantitySample(type: Self.dietaryFatType, quantity: HKQuantity(unit: .gram(), doubleValue: fatGrams), start: date, end: date)
        ]
        let correlation = HKCorrelation(
            type: Self.foodCorrelationType,
            start: date,
            end: date,
            objects: objects,
            metadata: [HKMetadataKeyFoodType: name]
        )
        do {
            try await store.save(correlation)
            return correlation.uuid.uuidString
        } catch {
            return nil
        }
    }

    /// Deletes a previously-saved food correlation *and* the individual quantity samples it
    /// contains — HealthKit doesn't cascade-delete those automatically, so leaving them out here
    /// would silently orphan energy/macro samples every time an entry is edited or removed.
    func deleteDietaryEntry(uuid: String) async {
        guard isAuthorized, let objectUUID = UUID(uuidString: uuid) else { return }
        let predicate = HKQuery.predicateForObject(with: objectUUID)
        let correlation: HKCorrelation? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: Self.foodCorrelationType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKCorrelation)
            }
            store.execute(query)
        }
        guard let correlation else { return }
        try? await store.delete([correlation] + Array(correlation.objects))
    }
}
