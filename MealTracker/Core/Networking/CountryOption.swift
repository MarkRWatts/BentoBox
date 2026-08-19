import Foundation

/// One selectable country for the "constrain food search results" Settings preference. Built on
/// demand from `Locale.Region.isoRegions` rather than a hardcoded table — not stored/persisted
/// itself, `UserProfile.foodSearchCountryCode` stores only the ISO code.
struct CountryOption: Identifiable, Hashable {
    /// ISO region code, e.g. "GB".
    let code: String
    /// English display name, e.g. "United Kingdom" — matches the format Open Food Facts expects
    /// for its `countries_tags_en` search filter.
    let englishName: String

    var id: String { code }

    /// Every ISO region Apple knows an English name for, sorted alphabetically. Computed once on
    /// first access — cheap enough (a few hundred entries) that persisting it isn't worthwhile.
    static let all: [CountryOption] = {
        let englishLocale = Locale(identifier: "en_US")
        return Locale.Region.isoRegions
            .compactMap { region -> CountryOption? in
                guard let name = englishLocale.localizedString(forRegionCode: region.identifier) else { return nil }
                return CountryOption(code: region.identifier, englishName: name)
            }
            .sorted { $0.englishName < $1.englishName }
    }()
}
