## What

<!-- What does this change? Reference REQUIREMENTS.md sections/decisions (§x.y). -->

## How to test

<!-- Steps, screens, or test names. -->

## Checklist

- [ ] Unit tests added/updated; UI test for any new flow or gesture
- [ ] Bug fix? A failing test reproduced it first
- [ ] Both suites pass (`ios/SETUP.md` → Tests) and `swiftlint --strict` is clean
- [ ] Project regenerated after adding files (`xcodegen generate`)
- [ ] UI text via `LocalizedStringKey` / String Catalog; data via `Text(verbatim:)`
- [ ] VoiceOver labels and Dynamic Type checked for new UI
- [ ] Nothing from the never-decode list (§7.16); no secrets
- [ ] REQUIREMENTS.md updated if behaviour or a decision changed
