# Changelog

## 0.9.4

- Cheaper enchants. Where a guide names a cheaper option for a slot, it is shown next to the best enchant, with a coin icon and "cheaper:", for example "Subtlety  cheaper: Greater Resistance". It works like the best enchant: hover for details, click to search the Auction House, shift-click to link it. For weapons, the cheaper option matches the weapon type (one-hander or staff).
- The Discipline Priest list now takes its enchants from ConquestCapped's Discipline Priest enchant guide, which names a best and a cheaper enchant for every slot. Before, they came from Wowhead's gear sets. The cheaper head and legs option is Lesser Arcanum of Voracity (Intellect or Spirit).
- Cheaper options come from ConquestCapped's guides (Balance Druid and Discipline Priest). The other guides name only one enchant per slot.

## 0.9.3

- Enchants. Each ready-made list shows the best enchant for each slot next to the slot name, for example "Arcanum of Focus" on Head and Legs. The enchants come from the same guide as the list: Grayston's sheet, Alacor's and Jurdi's videos, the Wowhead guides, ConquestCapped's Balance Druid enchant guide and the wowsims set.
- Hover an enchant to see what it does, the guide's own words, and other options the guide names, such as a cheaper enchant or the staff enchant.
- Click an enchant to search the Auction House for it. For an Arcanum it searches the Libram as well, and for an enchanting formula it searches the formula. If the Auction House is closed, the search starts when you open it. It uses Auctionator if you have it, otherwise Blizzard's search box. Shift-click links the enchant in chat.
- The **List** button keeps long list names inside the button (cut off with "..."). Hover it to see the full name and the list's details.

## 0.9.2

- New list "Holy Healer (Wowhead pre-raid)" for Paladins, from Wowhead's Holy Paladin BiS guide by Harreks. It has 62 items. Its notes give vendor prices in gold or Tarnished Undermine Real, and mark the two-hand weapons; the guide's BiS set uses a one-hander and an off hand.
- The new list is not ticked for any character. Tick it in the **List** menu to use it.
- List names are shown in their class colour everywhere: the List menu, the window, tooltips, loot banners, chat and the minimap menu. For example, Druid lists are orange and Paladin lists are pink. Class and character names in the List menu and the Edit dialog are coloured too. Lists for any class stay white.
- In the List menu, the list shown in the window has a tinted background instead of a coloured name.
- The List menu is shorter: each row shows only the list name and its item count. Hover a name to see the class, spec (main spec or offspec), who uses it and where it comes from.
- Item tooltips only show the lists that are ticked for the character you play. The option "Other characters' lists in tooltips" and `/tl others` are gone.
- More space between check boxes and their text, in the List menu and in all dialogs.
- A new list takes the class its name mentions ("Resto Druid" becomes a Druid list), unless you pick a class yourself. Before, it always got the class of the character you were playing.
- One-time fix at your next login: your own lists whose name mentions a different class than the one they were saved with get that class. The chat says which ones.

## 0.9.1

- Opening a list no longer makes it count for your character. Before, every list you looked at showed up in your tooltips and loot alerts.
- The List menu has a box next to each list. Tick it to use the list for your current character (tooltips, NEED banner, dungeon pop-up); click the name to just show the list. Lists of another class say so, for example "Druid list".
- New "Use for <character>" box at the bottom of the window, for the list that is shown.
- One-time clean-up at your next login: lists of another class that only got tied to a character because it opened them are taken off that character. The chat says which ones.
- Lists you import as a new list count for you right away if they are for your class.

## 0.9.0

- First public release on GitHub. Install and update with WowUp-CF (**Get Addons > Install from URL**), or download the zip.
- Version check. TierList users in the same group or guild tell each other their versions, and an older copy prints once that a newer one is out, with the download link.
- New command `/tl version`.

## 0.8.2

- New list "Discipline (Wowhead pre-raid)" for Priests, from Wowhead's Discipline Priest BiS guide by Voulk. It has 62 items. Its notes say which items are in the guide's Spendy and Budget sets.

## 0.8.1

- New list "Balance (ConquestCapped pre-raid)" for Druids, from ConquestCapped's Balance Druid pre-raid BiS guide. It has 72 items, with the BiS set as S and the realistic set as A.

## 0.8.0

- Better item sources, now also from ForeverDungeonJournal and QuestieDB. This adds quest chains, quest zones, combined items and vendor drops. Almost no items are "unknown" any more.
- BoE items are marked "(BoE, AH)", and the Auctionator price is shown when Auctionator is installed.
- Vendor prices in gold, currencies, honor or marks are recorded when you open a vendor window, and then shown in tooltips.

## 0.7.0 - 0.7.1

- Main spec and offspec per list, read from your talent tree. Offspec drops get a blue "Offspec - Greed" banner, with no Need prompt and no sound.
- New command `/tl spec`, plus a spec choice in the Edit dialog.
- New list "Prot Tank (Jurdi pre-raid)" for Paladins. It is offspec unless you are specced Protection.
- Ready-made lists can now receive later items once.

## 0.6.0 - 0.6.1

- New list "Shockadin (Grayston pre-raid)" from Grayston's 2H Shockadin pre-raid guide. It is the active list for Paladins.
- New list "Shockadin (Alacor pre-raid)" from Alacor's video.

## 0.5.0

- Fill dialog, with filters for source (dungeons, quests, vendors, crafting, PvP), quality and place.
- Full GearQuest ranking. PvP items are marked.

## 0.4.0

- EllesmereUI look when EllesmereUI is installed, otherwise a flat style.

## 0.3.0

- Minimap button.

## 0.2.0

- Fill, with `/tl fill` and `/tl unfill`: adds GearQuest's level-60 picks per slot.
- Sixty Upgrades set import.

## 0.1.0

- First version: S/A/B/C lists per slot and per character, drop sources, tooltips, the Need banner, the dungeon pop-up, and wowsims import.
