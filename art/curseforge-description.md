Bag Bloat checks every quest item in your bags and bank on WoW Forever and tells you whether you still need it.

## Labels

Each quest item gets one label. It shows in the item's tooltip, so it works with any bag addon, and in the Bag Bloat window.

- **Quest done.** The item starts a quest you already completed. Safe to delete.
- **Gray quest.** The item starts a quest that is gray for your level. Safe to delete.
- **No quest in log.** A quest item that no quest in your log uses, often left over from a quest you finished or dropped. Check before deleting.
- **Starts a quest.** The item starts a quest you have not done that is still worth experience.
- **Hidden quest.** The item starts a quest that has no name, which is how the game hides a quest. Keep it.
- **Secret quest.** The item belongs to a known secret quest chain, such as the Dawn Waker chain the Skyborne ring starts, the Stone Key, the Bloody Map, the Coldflame Saber, Lyn the Ignored, Ta'shkal or the Malignant Root. Bag Bloat always keeps these, whatever the game reports.
- **Kept by you.** You chose Keep for the item in the window. It stays kept unless a quest in your log needs it.
- **On quest.** A quest in your log needs the item. That includes an item the quest handed you to deliver.

An item you hide from the window is labeled Hidden by you. It gets no tooltip line and no bag icon.

## Bag icons

Each quest item also gets an icon in the corner of its slot. This works in the game's own bags and bank and in EllesmereUI Bags and its bank.

- **Green check.** You have the quest or already completed it (On quest, Quest done).
- **Red X.** The quest is gray for your level, or no quest in your log uses the item (Gray quest, No quest in log).
- **Question mark.** It starts a quest you have not picked up, or belongs to a hidden quest (Starts a quest, Hidden quest, Secret quest).

## Quest details

Hold Alt while hovering a quest item to see the quest ID, whether the quest is completed, in your log or not started, your progress on each objective, and the item ID. Use the IDs to look the quest up on a database site.

## The window

Type `/bloat` or `/bagbloat`, or click Bag Bloat in the addon compartment by the minimap. The window lists your quest items and shows how many are safe to delete.

- Items are grouped in this order: Ready to turn in, your current zone, other zones A to Z, Not in your quest log, Safe to delete, and Hidden by you.
- Ready to turn in holds items for quests in your log that you can turn in now.
- Items are grouped by the zone of their quest. Not in your quest log holds items no quest in your log uses.
- An item that starts a quest you have not picked up is listed under the zone where that quest is turned in, for 160 classic quests. That table is built from pfQuest data (MIT). Other quest-starting items stay under Not in your quest log.
- Click a group's header to fold or unfold it. Hidden by you starts folded. The window remembers which groups you folded.
- Type in the search box at the top right to filter by item name, quest title or zone. While it has text, every match shows. Escape clears the text, then closes the window.
- Bank items stay listed from your last bank visit, marked (bank), so you can see them away from the bank.
- When you enter a zone that has quest items for it in your bank, Bag Bloat prints one chat line about it.
- While the bank is open, Bank on a group's header moves its items to the bank and Take moves them back to your bags.
- Click a row to pick the item up, then click outside your bags. The game asks you to confirm the delete.
- Shift-click a row to link the item in chat.
- Right-click a row to keep the item, hide it, or delete it. Delete shows only for items marked safe to delete that are in your bags. Keep and hide choices are saved per character.
- Hover a row for the full item tooltip.
- The By zone box switches back to one list.
- Drag the bottom-right corner to resize the window. It remembers its size.
- The window uses the Expressway font when EllesmereUI or SharedMedia has it.

Bag Bloat deletes an item only when you click Delete, one item per click, and only items marked safe to delete. Delete is on the Safe to delete group. The first click changes it to Sure?, and each click after that deletes the next item in the group. It disarms 10 seconds after your last click or when you close the window.

When your bags fill up and some quest items in them are safe to delete, Bag Bloat prints one chat line saying how many, at most every two minutes.

## Settings

Bag Bloat has a page in the game's settings, under AddOns. `/bloat options` opens it.

- **Open with the bank.** On by default. Opens the window when you open your bank and closes it when you leave.
- **Open with your bags.** Off by default. Opens the window when you open your bags and closes it with them. Works with the game's bags and EllesmereUI Bags.
- **Group by zone.** The same switch as the By zone box in the window.
- **Chat line for banked items** and **Chat line when bags fill up.** Turn either chat line off.

The window does not open by itself in combat. If you close a window that opened by itself, it stays closed until you next open the bank or your bags. A window you opened yourself is never closed for you.

## Why an item has its label

`/bloat why` opens a box with what the game reports for one item and how each rule decided its label and zone. Type it while hovering an item in your bags or in the window, or add an item link or item ID after `why`. Press Ctrl+C to copy the text, for example into a bug report. It does not work in combat.

## How it decides

Quest-starting items are checked against your completed quests, your quest log and the quest's level. Items that a quest asks you to collect are matched by name against the objectives of the quests in your log. A quest item that matches nothing in your log is marked No quest in log. Items from known secret quest chains are always kept. Bag Bloat scans your bags only when they or your quest log change. In combat it only shows what it already knows and checks again once combat ends.
