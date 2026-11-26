# TierList

A World of Warcraft: Forever addon for your own S/A/B/C gear lists per slot. You keep one list per build or character. It shows where each item comes from, marks items in tooltips, and tells you when a drop is worth a Need roll.

## Install

### With WowUp-CF (recommended, gives you an Update button)

The CurseForge app does not support WoW Forever. [WowUp-CF](https://github.com/WowUp/WowUp.CF) does.

1. Open WowUp-CF and pick **World of Warcraft: Forever** at the top.
2. Go to **Get Addons**, then **Install from URL**.
3. Paste `https://github.com/adminmh-git/TierList` and install.

New versions then appear under **My Addons** like any other addon. Click **Update** to install them.

### Manually

1. Download `TierList-<version>-forever.zip` from the [latest release](https://github.com/adminmh-git/TierList/releases/latest).
2. Extract it into `World of Warcraft\_forever_\Interface\AddOns\`. You should end up with `AddOns\TierList\TierList.toc`.
3. Type `/reload` in game, or restart the game.

## Using it

- `/tl` or the minimap button opens the window. Each gear slot lists its items by tier.
- **Which lists count for a character.** In the **List** menu, tick the box next to a list to use it for the character you are playing: its items then show up in tooltips, loot alerts and the dungeon pop-up. Click a list's name to just look at it, and hover it for details. The **Use for ...** box at the bottom of the window does the same for the list that is shown. List names are in their class colour, so you can tell a Druid list (orange) from a Paladin list (pink) at a glance.
- **Tooltips** show an item's tier on the lists you use and where it comes from: boss and dungeon, quest, vendor and cost, crafting, or Auction House for BoE items.
- **Loot alerts.** When an item from your list drops in a group, a banner tells you to roll Need. Offspec lists say "Greed" instead.
- **Main spec and offspec.** Each list can be tied to a talent tree. Edit the list to set this, and use `/tl spec` to check what the addon detected.
- **Fill.** Adds GearQuest's ranked level-60 picks per slot to a list. You can filter them by source and quality.
- **Import and export.** Lists can be shared as text. `/tl import` also reads wowsims gear and Sixty Upgrades sets.
- `/tl version` shows your version. TierList users in the same group or guild tell each other their versions, so an old copy prints once that a newer one is out.
- `/tl help` lists all commands.

The look follows EllesmereUI if you use it, and falls back to a plain flat style if you don't.

## Included lists

A character with no list yet gets one ready-made list of its class. All other lists are in the **List** menu: tick one to use it.

| List | Class / spec | Source |
| --- | --- | --- |
| Shockadin (Grayston pre-raid) | Paladin, Holy (Shockadin) | Grayston's "WoW Forever 2H Shockadin Phase 1 Pre-BiS Guide" |
| Shockadin (Alacor pre-raid) | Paladin, Holy (Shockadin) | Alacor's Shockadin pre-raid BiS video (YouTube) |
| Shockadin | Paladin, Holy (Shockadin) | wowsims example set |
| Prot Tank (Jurdi pre-raid) | Paladin, Protection | Jurdi's Prot Paladin pre-raid video (YouTube) |
| Holy Healer (Wowhead pre-raid) | Paladin, Holy | Wowhead "Holy Paladin Healer Best in Slot Gear" by Harreks |
| Balance (ConquestCapped pre-raid) | Druid, Balance | ConquestCapped "WoW Forever Balance Druid Pre-Raid BiS" by Kir |
| Discipline (Wowhead pre-raid) | Priest, Discipline | Wowhead "Discipline Priest Healer Best in Slot Gear" by Voulk |

Tiers follow each guide's own ranking. The item notes in tooltips quote the guide.

## Credits

Item sources and rankings come from these addons and projects. Thanks to their authors.

- **GearQuestForever** by Henrik8210. Item facts and the ranked picks used by Fill.
- **Wishwell** by Squirt.
- **wowsims** (WoW Forever sim). Item data and example sets.
- **QuestieDB / Questie**. Quest, vendor and drop data, used under GPLv3.
- **ForeverDungeonJournal** by Exehn. Dungeon loot and quest rewards.
- The bundled libraries are LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0. Their licenses are in `TierList/Libs/THIRD_PARTY_NOTICES.txt`.

## License

TierList's own code and data are licensed under [GPL-3.0](LICENSE). The bundled libraries keep their own licenses.

TierList is a fan project. It is not affiliated with or endorsed by Blizzard Entertainment.
