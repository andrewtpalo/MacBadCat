# Mac: Bad Cat — native iOS game (Swift + SpriteKit)

A full, **native** iPhone game. No HTML, no web view — this is Swift using Apple's SpriteKit game engine and SwiftUI app lifecycle. Mac sneaks chaos past a human across five rooms; spend the coins you earn on costumes and upgrades.

> **Important — you need a Mac to build this.** Apple only allows iOS apps to be compiled and signed with **Xcode, which runs only on macOS**. There is no way to build *any* iPhone app on Windows. This project is written and ready; it just has to be opened on a Mac (a borrowed one, a Mac mini, or a cloud Mac such as the free macOS runners in GitHub Actions, or MacinCloud) to run on a simulator or a real iPhone.
>
> I wrote this without an Xcode compiler available, so if the first build flags a small issue, it'll be a quick fix — the structure and logic are complete.

## What's in it
- **5 rooms**, each themed, unlocked with coins: Living Room, Kitchen, Bedroom, Bathroom, Home Office.
- **5–7 days (levels) per room** with rising mischief goals, longer odds, and a nosier human. 29 levels total.
- **Things to break** (6 per room, 30+ total) and **things to collect** (coins + rare gems that spawn during play).
- **A shop** with two tabs:
  - *Looks*: Bandit Mask, Tiny Bowtie, Cool Shades, Tiny Crown (cosmetic, change Mac's appearance).
  - *Upgrades*: Soft Paws, Big Belly, Power Nap, Pure Charm, Show Off (each leveled, they change the math of the game).
- **The core loop**: wreck things while the human is *distracted* or *away*; sit/eat/nap in view to drop **suspicion**; nap in the moving **sunbeam**, eat, and drink to refill **energy**. Get caught while watched and it's time-out.
- Persistent save (coins, unlocks, stars, upgrades, equipped skin), per-level star ratings, sound toggle.

## Build & run

### Option A — generate the Xcode project with XcodeGen (recommended)
On the Mac:
```bash
brew install xcodegen        # one time
cd MacBadCat
xcodegen generate            # creates MacBadCat.xcodeproj from project.yml
open MacBadCat.xcodeproj
```
Then in Xcode: pick a simulator (or your iPhone), set your Team under *Signing & Capabilities* if running on a device, and press ▶.

### Option B — no XcodeGen
1. Xcode → **File ▸ New ▸ Project ▸ iOS ▸ App** (Interface: SwiftUI, Language: Swift). Name it `MacBadCat`.
2. Delete the template's `ContentView.swift` and the generated `App` file.
3. Drag everything in **`App/Sources/`** into the project (check *Copy items if needed*).
4. Replace the project's Info.plist with **`App/Info.plist`**, or copy its keys (portrait-only, status bar hidden).
5. Press ▶.

## Project layout
```
MacBadCat/
├─ project.yml                 # XcodeGen spec
├─ App/
│  ├─ Info.plist
│  └─ Sources/
│     ├─ App.swift             # @main app, SpriteView host, BaseScene, SFX
│     ├─ Theme.swift           # palette, rounded fonts, Button/Bar/Panel nodes
│     ├─ GameData.swift        # Codable save: coins, unlocks, upgrades, stars
│     ├─ Content.swift         # rooms, breakables, shop items, per-day difficulty
│     ├─ Actors.swift          # CatNode (Mac, with skins/poses) + HumanNode (gaze AI)
│     ├─ MenuScenes.swift      # Menu, Room Select, Level Select, Shop
│     └─ GameScene.swift       # the gameplay + results screen
└─ README.md
```

## Notes / next steps
- No image assets are required — Mac, the human, and the room are drawn from vector nodes; breakables/collectibles use system emoji so it looks consistent with zero art pipeline. Swap in custom art later by replacing the node builders in `Actors.swift` / `GameScene.swift`.
- There's no app icon set yet (the app runs with the default icon). Add one in Xcode via **Assets.xcassets ▸ AppIcon** when you want.
- Tuning knobs (suspicion rates, energy, day goals) live in `GameScene.swift` and `Content.swift`.
- If you ever want to *preview on Windows* again, the earlier web build is the only thing that runs without a Mac — but it is not this native project.
