# App Store listing — texts to paste

## Basics
- **Name:** See Your Disk  (up to 30 chars)
- **Subtitle (EN):** See what fills your Mac
- **Subtitle (RU):** Увидьте, что занимает место
- **Category:** Utilities (secondary: Productivity)
- **Price:** Free (with in-app purchases)
- **Age rating:** 4+ (answer "None"/"No" to everything)
- **Copyright:** © 2026 <your name or company>
- **Support URL:** a page with your contact (can be the same page as the privacy policy) — mailto is not accepted, it must be https
- **Privacy Policy URL:** hosted docs/privacy-policy.md
- **App Privacy:** "Data Not Collected"
- **Export compliance:** already set in the build (no non-exempt encryption)

## Description (EN)
See Your Disk shows where your storage went — as a clean, colourful map of blocks. Every block is a folder; the bigger the block, the more space it takes. Click to inspect, double-click to zoom in.

• Instant map of your Home folder, Applications and system areas
• Finds caches, logs, Xcode and developer leftovers, package caches and large files
• One-tap Auto clean removes only what is safe. Or choose exactly what to remove
• Anything not clearly safe goes to the Trash first
• Private by design: no accounts, no tracking, your files never leave your Mac
• Available in English and Russian

Cleaning is free to try once. Continue with a monthly subscription or a one-time lifetime purchase.

## Description (RU)
See Your Disk показывает, куда ушло место на диске: в виде наглядной цветной карты блоков. Каждый блок — папка, чем он больше, тем больше места она занимает. Нажмите, чтобы посмотреть, двойной клик — чтобы приблизить.

• Мгновенная карта домашней папки, приложений и системных областей
• Находит кэши, логи, остатки Xcode и разработки, кэши пакетов и крупные файлы
• «Автоочистка» в один клик удаляет только безопасное. Или выберите, что именно убрать
• Всё, что не точно безопасно, сначала попадает в Корзину
• Приватность: без аккаунтов и слежки, ваши файлы не покидают Mac
• Русский и английский языки

Очистку можно попробовать бесплатно один раз. Дальше — ежемесячная подписка или разовая покупка навсегда.

## Keywords (EN, max 100 chars, comma-separated, no spaces)
disk,storage,cleaner,clean,cache,space,mac,system data,large files,xcode,junk,analyzer

## Keywords (RU)
диск,память,очистка,кэш,место,системные данные,большие файлы,мусор,хранилище,анализ

## Promotional text (optional)
See what fills your Mac and clean it safely.

## In-App Purchases (App Store Connect)
| Type | Reference name | Product ID | Price | Duration |
|---|---|---|---|---|
| Auto-renewable subscription (group "SeeYourDisk Pro") | Monthly | SeeYourDisk.monthly | $4.99 | 1 month |
| Non-consumable | Lifetime | SeeYourDisk.lifetime | $19.99 | — |

Display names / descriptions:
- Monthly — EN: "Monthly" / "Unlimited cleaning, billed monthly" — RU: "Ежемесячно" / "Безлимитная очистка, оплата раз в месяц"
- Lifetime — EN: "Lifetime" / "Unlimited cleaning, pay once" — RU: "Навсегда" / "Безлимитная очистка, один платёж"

Review screenshot for both: a screenshot of the purchase window (Settings gear → Buy license…).

## App Review notes (paste into "Notes")
See Your Disk is a disk-usage visualizer and cleaner. No sign-in is needed.

How to test:
1. On first launch there is a short introduction, then the app asks the user to choose their Home folder in the standard macOS Open panel. Please choose your Home folder. The access is kept with a security-scoped bookmark.
2. The app scans and shows a map of blocks. Click a block to see what can be cleaned in it; the toolbar button "Auto clean" removes only safe items (caches, logs, build leftovers).
3. The first cleaning is free. On the second cleaning attempt the purchase window appears (monthly subscription or lifetime). Purchases use StoreKit; "Restore purchases" is in the purchase window and in the gear menu.

Entitlements: the app is sandboxed. It uses com.apple.security.files.user-selected.read-write and app-scope bookmarks for the Home folder the user selects. It also uses read-only temporary exceptions for /System, /Library, /private, /usr, /bin, /sbin and /opt. They are used only to measure how much space macOS, system libraries and caches occupy, so the map can show the whole disk. The app never writes outside the folder the user selected. Network client is used only by StoreKit.

Deletion always requires the user's confirmation. Items that are not clearly safe are moved to the Trash.
