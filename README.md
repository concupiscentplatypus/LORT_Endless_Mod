# LORT Endless Mode

An endless survival mode for [LORT](https://store.steampowered.com/app/2956680/). It adds one extra entry,
**Endless Mode**, to the quest board in the camp. If you don't pick it, the game plays exactly as normal.

- Waves of enemies that get bigger and tougher every wave.
- A boss every 5th wave. Two bosses from wave 20, three from wave 35.
- Every 15 kills you earn an Attribute (Strength, Agility or Intelligence) and a Power-up.
- The days never run out, so the game never forces you to the next map. It ends when you die.
- Works solo and in co-op. In co-op **only the host needs the mod**.

> This is a fan-made mod. It is not made or supported by the developers of LORT.
> It was built for LORT v0.8.2 (September 2026). A game update can break it. If the game stops starting after
> an update, follow "How to remove the mod" below and the game will work again.

---

## How to install

Everything you need is in this download. There is nothing else to get.

### Step 1: Download

1. On this page, click the green **Code** button near the top.
2. Click **Download ZIP**.
3. Find the ZIP in your Downloads folder, right-click it and choose **Extract All**, then **Extract**.

You now have a folder called `LORT_Endless_Mod-main`. Open it, then open the folder inside it called
**`copy_into_Win64`**. You should see a file called `dwmapi.dll` and a folder called `ue4ss`. Leave this open.

### Step 2: Open the game's folder

1. Open **Steam** and go to your **Library**.
2. **Right-click LORT** in the list on the left.
3. Click **Manage**, then **Browse local files**. A folder opens.
4. In that folder, open **BW**, then **Binaries**, then **Win64**.

You are in the right place if you can see a file called `LortGame-Win64-Shipping`.

### Step 3: Copy the two things across

Copy `dwmapi.dll` and the `ue4ss` folder from Step 1 into the `Win64` folder from Step 2.

When you are done, the game's `Win64` folder looks like this:

```
Win64
├── LortGame-Win64-Shipping.exe      (was already there)
├── dwmapi.dll                       (new)
└── ue4ss                            (new)
```

That's it. Start LORT from Steam as usual.

If you already had UE4SS installed for other LORT mods, copy only the `LORT_Endless` folder (it is in
`copy_into_Win64`, then `ue4ss`, then `Mods`) into your own `Mods` folder instead.

---

## How to play

1. In the camp, walk to the **quest board** and open it.
2. Click the quest whose map you want to play on.
3. Click **Endless Mode** at the bottom of the list. It turns gold. (Click it again to un-pick it.)
4. Click **Select**, then get in the van.

Endless mode starts by itself when the map loads.

Good to know:

- **Enemies appear where the host is looking.** If a wave is not filling up, look at the ground for a moment.
- The top-right of the screen shows the wave, how many enemies are left, and how many kills until the next reward.
- **Solo:** when you earn a reward the game pauses and you choose an Attribute, then a Power-up.
- **Co-op:** rewards drop when the wave is cleared. Crystals shatter next to you and every player gets their own
  pickups. Walk up to yours and press the interact key to choose. You have 20 seconds before the next wave.
- Each boss you kill puts a weapon in the **host's** backpack. The weapons get better the further you go.
- In co-op, only the host sees the wave counter. Other players see wave messages in the chat.
- The Endless Mode entry on the board only works with a mouse click, not with a controller.

Please only use this in co-op with friends who know you are playing modded.

---

## How to remove the mod

1. Open **Steam**, **right-click LORT**, click **Manage**, then **Browse local files**.
2. Open **BW**, then **Binaries**, then **Win64**.
3. Delete the file `dwmapi.dll` and the folder `ue4ss`.

That's it. The game is back to normal and your saves are not touched.

To turn off only this mod and keep the mod loader: open `ue4ss`, then `Mods`, and delete the `LORT_Endless` folder.

---

## If something goes wrong

| Problem | What to do |
| --- | --- |
| The game crashes right when it starts | The game was probably updated and the mod loader no longer matches it. Remove the mod (see above) and check this page for a new version. |
| There is no "Endless Mode" on the quest board | Check that `dwmapi.dll` and the `ue4ss` folder are directly inside `Win64`, not inside another folder. Then fully close the game and start it again. |
| A wave is stuck with enemies left | The host should look at the ground for a few seconds. Leftover enemies are also brought to you, or skipped, after a short wait. |
| Something else | Open an Issue on this page and say what you were doing when it happened. |

---

## For the curious

The mod itself is one script file: `copy_into_Win64/ue4ss/Mods/LORT_Endless/Scripts/main.lua`. It only uses
functions and menus that are already in the game, adds no new art or sounds, and changes none of the game's own
files.

Everything else in `copy_into_Win64` is [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (experimental build
`v3.0.1-1152`), the open-source tool that lets Unreal Engine games load script mods. It is included unchanged
under its MIT licence (`ue4ss/LICENSE`), with three settings files adjusted for LORT: `MemberVariableLayout.ini`
(LORT's engine differs from what UE4SS expects, and the game crashes on start without it), `UE4SS-settings.ini`
(console windows off) and `Mods/mods.txt` (UE4SS's own sample mods switched off).
