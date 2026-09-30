# See Your Disk

**See where your Mac's storage went — as a clean map of blocks.**

[![Download on the Mac App Store](https://img.shields.io/badge/Mac_App_Store-Download-0D96F6?style=for-the-badge&logo=apple&logoColor=white)](https://apps.apple.com/us/app/clean-systemdata-seeyourdisk/id6817565741)

Every block is a folder; the bigger the block, the more space it takes. Click to inspect, double-click to zoom in, and clean caches, logs and leftovers safely.

<!-- Add screenshots to docs/screenshots and link them here:
![Map](docs/screenshots/map.png) -->

## Features

- Treemap of your Home folder, Applications and system areas, in the spirit of a chip die: blocks inside blocks
- Finds caches, logs, Xcode / simulator leftovers, package caches (npm, Gradle…), AI model caches and large files
- **Auto clean** removes only what is safe; or pick exactly what to remove per block
- Safe items (regenerable caches, logs) are deleted; everything else goes to the Trash first
- Private by design: no accounts, no analytics, your files never leave your Mac
- Scan-time mini game (Tetris) with the app's look
- English and Russian, native localization (String Catalog)

## Editions and branches

| Branch | What it is |
|---|---|
| `main` | The **Mac App Store edition**: App Sandbox, you choose your Home folder once, StoreKit purchases (first cleaning free, then monthly or lifetime). |
| `development` | Day-to-day work; merges into `main`. |
| `open-source` | The **open-source edition**: no purchases, no App Sandbox, uses **Full Disk Access** for a complete scan. Free to build and use. |

## Build

Requirements: Xcode 26 or newer, macOS 14+ deployment target.

```bash
git clone git@github.com:bikmeev/see-your-disk.git
cd see-your-disk
open SeeYourDisk.xcodeproj
```

Select the `SeeYourDisk` scheme and press ⌘R. In the App Store edition the run scheme uses `Products.storekit`, so purchases are simulated locally.

To use your own signing, change the Team and Bundle Identifier in *Signing & Capabilities*.

## Contributing

**Contributors are welcome!** Bug reports, ideas, translations, new cleanup rules and pull requests are all appreciated.

- Read [CONTRIBUTING.md](CONTRIBUTING.md) for how to build, what to work on and how to open a pull request.
- Not sure where to start? Open an issue and describe what you would like to do.
- Questions or anything else: [lopol3000@gmail.com](mailto:lopol3000@gmail.com)

## Privacy

The app reads file names and sizes locally and never uploads anything. See [docs/privacy-policy.md](docs/privacy-policy.md) and [docs/terms-of-use.md](docs/terms-of-use.md).

## Project layout

```
SeeYourDisk/Core     scanner, cleanup rules, treemap, store, models
SeeYourDisk/Views    map, inspector, onboarding, paywall, scan screen + Tetris
docs/                privacy policy, terms, App Store listing texts
```

## Contact

[lopol3000@gmail.com](mailto:lopol3000@gmail.com)

## License

[MIT](LICENSE)

---

### По-русски

**See Your Disk** показывает, куда ушло место на диске Mac, в виде карты блоков. Каждый блок — папка. Приложение находит кэши, логи и остатки разработки и безопасно их чистит: «Автоочистка» в один клик или выборочно. Всё работает локально, данные никуда не отправляются. Версия из App Store (`main`) работает в песочнице и платная после первой очистки; ветка `open-source` — бесплатная, с полным доступом к диску.
