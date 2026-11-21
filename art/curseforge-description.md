Bag Bloat checks every quest item in your bags and bank on WoW Forever and tells you whether you still need it.

## Labels

Each quest item gets one label. It shows in the item's tooltip, so it works with any bag addon, and in the Bag Bloat window.

- **Quest done.** The item starts a quest you already completed. Safe to delete.
- **Gray quest.** The item starts a quest that is gray for your level. Safe to delete.
- **No quest in log.** A quest item that no quest in your log uses, often left over from a quest you finished or dropped. Check before deleting.
- **Starts a quest.** The item starts a quest you have not done that is still worth experience.
- **Hidden quest.** The item starts a quest that has no name, which is how the game hides a quest. Keep it.
- **Secret quest.** The item belongs to a known secret quest chain, such as the Dawn Waker chain the Skyborne ring starts, the Stone Key, the Bloody Map, the Coldflame Saber, Lyn the Ignored, Ta'shkal or the Malignant Root. Bag Bloat always keeps these, whatever the game reports.
- **On quest.** A quest in your log needs the item.

## Bag icons

Each quest item also gets an icon in the corner of its slot. This works in the game's own bags and bank and in EllesmereUI Bags and its bank.

- **Green check.** You have the quest or already completed it (On quest, Quest done).
- **Red X.** The quest is gray for your level, or no quest in your log uses the item (Gray quest, No quest in log).
- **Question mark.** It starts a quest you have not picked up, or belongs to a hidden quest (Starts a quest, Hidden quest, Secret quest).

## Quest details

Hold Alt while hovering a quest item to see the quest ID, whether the quest is completed, in your log or not started, your progress on each objective, and the item ID. Use the IDs to look the quest up on a database site.

## The window

Type `/bloat` or `/bagbloat`, or click Bag Bloat in the addon compartment by the minimap. The window lists your quest items with the ones you can delete at the top, and shows how many are safe to delete. While the bank is open it lists your bank's quest items too.

- Click a row to pick the item up, then click outside your bags. The game asks you to confirm the delete.
- Shift-click a row to link the item in chat.
- Hover a row for the full item tooltip.
- Items are grouped by the zone of their quest, with your current zone first. Items no quest in your log uses, and items safe to delete, get their own groups at the end.
- While the bank is open, Bank on a group's header moves its items to the bank and Take moves them back to your bags.
- The By zone box switches back to one list.
- The window uses the Expressway font when EllesmereUI or SharedMedia has it.

Bag Bloat never deletes anything itself.

## How it decides

Quest-starting items are checked against your completed quests, your quest log and the quest's level. Items that a quest asks you to collect are matched by name against the objectives of the quests in your log. A quest item that matches nothing in your log is marked No quest in log. Items from known secret quest chains are always kept. Bag Bloat scans your bags only when they or your quest log change, and has no settings. In combat it only shows what it already knows and checks again once combat ends.
