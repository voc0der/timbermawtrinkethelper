# Timbermaw Trinket Helper

** AI Generated **

**Timbermaw Trinket Helper** is a tiny WoW addon that helps you manage  
**Defender of the Timbermaw** and **Drake Fang Talisman** around real boss pull timers.

It listens to **Deadly Boss Mods / BigWigs** pull announcements (or similar),
schedules logic at **6 seconds** and **3 seconds** before the pull, and will:

- Detect whether **Defender of the Timbermaw** is equipped (in either trinket slot).
- Check if Defender has already been **used** (on cooldown).
- Swap to **Drake Fang Talisman** out of combat (or prompt you to do it).
- Always respect combat restrictions and never do protected actions in combat.
- Optionally integrate with **ItemRack** if you prefer using a set.

No WeakAuras hacks, no ItemRack event editor — just a small, focused addon.

---

## Features

- ✅ Detects pull timers from **raid warnings / raid chat** (DBM / BigWigs, etc.).
- ✅ Schedules callbacks **6s** and **3s** before the pull.
- ✅ Finds **Defender of the Timbermaw** in **either** trinket slot (13 or 14).
- ✅ Swaps to **Drake Fang Talisman** in that **same slot** (top/bottom preserved).
- ✅ Only performs swaps **out of combat** (`InCombatLockdown()` safe).
- ✅ Optional **ItemRack** integration (equip a set like `DrakeFang_Prepull`).
- ✅ Uses **personal chat messages** only; never spams raid.

---

## Requirements

- WoW client that supports basic addon loading (Classic/SoD/ERA/etc.).
- A boss pull addon such as:
  - **Deadly Boss Mods (DBM)**, **BigWigs**, or anything that prints  
    messages like `Pull in 10 sec` to raid warning / raid chat.
- (Optional) **ItemRack** if you want to drive swaps via an ItemRack set.

---

## Installation

1. Create a folder in your AddOns directory:

   ```text
   Interface/AddOns/TimbermawTrinketHelper/
````

2. Inside that folder, create these two files:

   * `TimbermawTrinketHelper.toc`
   * `TimbermawTrinketHelper.lua`

3. Paste the provided `.toc` and `.lua` contents into those files.

4. Restart the game client or do a full `/reload`.

5. On the character select screen, enable:

   * **Timbermaw Trinket Helper** in the AddOns list.

---

## How it works

### Pull detection

The addon does **not** read `/pull 10` directly.

Instead, it listens for **pull messages** from your boss mod:

* `CHAT_MSG_RAID_WARNING`, `CHAT_MSG_RAID`, and `CHAT_MSG_PARTY`
* Lines like:

  * `Pull in 10`
  * `Pull in 10 sec`
  * `Pull in 10 seconds`

When it sees such a message, it:

1. Extracts the duration (e.g. `10` seconds).
2. Records the **absolute pull time** using `GetTime()`.
3. Schedules timers for:

   * `pullTime - 6` seconds.
   * `pullTime - 3` seconds.

It also listens to some addon messages for **BigWigs** via `CHAT_MSG_ADDON`
to catch prefixed messages like `BigWigs: Pull 10` when available.

If it sees messages like `Pull cancelled` or `Pull timer cancelled`, the
active pull is cleared so no 6s/3s logic will fire.

---

### Trinket detection

At each callback (6s and 3s), the addon:

1. Checks **both trinket slots**:

   * Top trinket: slot `13`.
   * Bottom trinket: slot `14`.
2. Looks for **Defender of the Timbermaw** by item name.
3. If found, records **which slot** it was in (top or bottom).

This allows you to move Defender between slots without changing anything in the addon.

---

### 6-second logic

At **6 seconds before pull**:

* If **Defender of the Timbermaw** is equipped **and** its trinket cooldown
  is active (i.e. you’ve already used it pre-pull):

  * If **auto-swap is enabled** (default):

    * The addon will attempt to equip **Drake Fang Talisman** in that **same slot**.
    * A personal chat message is printed:

      * `Defender of the Timbermaw used – equipping Drake Fang Talisman.`
  * If **auto-swap is disabled**:

    * It does **not** equip anything automatically.
    * It prints:

      * `Defender of the Timbermaw used – press your Drake Fang Talisman macro / ItemRack set now.`

* If Defender is equipped but **not** on cooldown, it does nothing but may
  print debug info if debug is enabled.

---

### 3-second logic

At **3 seconds before pull**:

* If you are already in combat (early pull):

  * It prints:

    * `3s to pull but already in combat – cannot swap trinkets.`
  * No equip actions are attempted.

* If **Defender of the Timbermaw is still equipped** in either trinket slot:

  * If **auto-swap is enabled**:

    * It equips **Drake Fang Talisman** into that same slot (out of combat).
    * It prints a strong message like:

      * `Equipping Drake Fang Talisman (Defender still equipped at 3s).`
  * If **auto-swap is disabled**:

    * It prints:

      * `3 seconds to pull – Defender of the Timbermaw still equipped, swap to Drake Fang Talisman now.`

* If **Drake Fang Talisman** is already equipped in one of the trinket slots:

  * The addon quietly confirms via debug log (if enabled) and does nothing.

---

## ItemRack integration (optional)

If you prefer to manage trinkets via **ItemRack sets**, the addon can
delegate swaps to ItemRack instead of direct `EquipItemByName`.

1. Create an ItemRack set, for example:

   * **Name:** `DrakeFang_Prepull`
   * Exactly your normal raid set, but:

     * Replace Defender of the Timbermaw with **Drake Fang Talisman** in your preferred slot.

2. In-game, configure the addon:

   ```text
   /ttmw itemrack on
   /ttmw set DrakeFang_Prepull
   ```

When it decides to swap to Drake, it will call:

```lua
ItemRack.EquipSet("DrakeFang_Prepull")
```

instead of `EquipItemByName`.

---

## Slash commands

The addon exposes two slash commands:

* `/timbertrinket`
* `/ttmw`

Usage:

```text
/ttmw auto
    Enable auto-swapping Drake out of combat at 6s/3s (DEFAULT).

/ttmw manual
    Disable auto-swaps. The addon will only print personal alerts.

/ttmw itemrack on
    Use ItemRack set when swapping to Drake (requires ItemRack).

/ttmw itemrack off
    Disable ItemRack integration and use direct item equips instead.

/ttmw set <ItemRackSetName>
    Set the ItemRack set name to use (default: DrakeFang_Prepull).

/ttmw debug on
    Turn on debug logging to chat (prefix: DEBUG).

/ttmw debug off
    Turn off debug logging.

/ttmw
    Show a short help summary.
```

---

## Example workflow

1. Equip your normal raid gear with **Defender of the Timbermaw** in one of
   your trinket slots.

2. Pre-pull, use Defender as normal (proc or on-use).

3. Raid leader calls a pull timer:

   * e.g. `/dbm pull 10` or `/pull 10`.

4. DBM / BigWigs sends a message like:

   * `Pull in 10 sec` (raid warning).

5. **6 seconds before pull**:

   * Addon sees Defender in a trinket slot.
   * If Defender is on cooldown (already used), it swaps to **Drake Fang Talisman** in that slot (or tells you to swap, if in manual mode).

6. **3 seconds before pull**:

   * If Defender is still equipped and you’re out of combat:

     * It swaps to Drake and alerts you.
   * If Drake is already equipped:

     * It silently confirms (debug).

7. If someone **facepulls** early:

   * You enter combat before 3s.
   * The addon prints a warning and **does nothing** (no protected actions in combat).

---

## Limitations / notes

* The addon currently detects pull timers by **parsing text** from raid/party warnings and some addon messages.
  If your boss mod is configured to *not* show “Pull in X” in chat/raid warnings, the addon won’t see the timer.
* Item names are used (`"Defender of the Timbermaw"`, `"Drake Fang Talisman"`).
  If you’re on a non-English client, you may want to change these to localised names or item IDs in the Lua file.
* This is intentionally small and focused — it does not manage any other trinkets or gear.

---

## Troubleshooting

**Addon doesn’t seem to do anything**

* Verify it’s enabled in the AddOns list.
* Run `/ttmw debug on` and watch your chat during a pull timer:

  * You should see messages like `Detected pull: 10s from CHAT_MSG_RAID_WARNING`.
* Ensure your boss mod is configured to show “Pull in X” in raid warnings / raid chat.

**It never sees Defender**

* Make sure you actually have **Defender of the Timbermaw** equipped in one of the trinket slots.
* Check that the item name in `TimbermawTrinketHelper.lua` matches exactly (case-sensitive).

**It says “Already in combat, cannot swap”**

* This is expected if someone pulls early and you enter combat before the 6s or 3s logic runs.
  WoW’s secure API blocks equipment changes from addons in combat.

**ItemRack doesn’t seem to fire**

* Confirm that **ItemRack** is installed and enabled.
* Check your set name:

  * Use `/itemrack` to open the UI and verify the exact set name.
  * Set it in the addon with `/ttmw set <ExactSetName>`.
* Confirm `ItemRack.EquipSet("<name>")` works via a macro first.

---

## License

Do whatever you want with it. Copy, fork, tweak, rename, ship a guild version, etc.
Just don’t blame the Timbermaw if you pull with the wrong trinket equipped. 🐻
