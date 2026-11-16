Bag Bloat checks every quest item in your bags on WoW Forever and tells you whether you still need it.

## Labels

Each quest item gets one label. It shows in the item's tooltip, so it works with any bag addon, and in the Bag Bloat window.

- **Quest done.** The item starts a quest you already completed. Safe to delete.
- **Gray quest.** The item starts a quest that is gray for your level. Safe to delete.
- **No quest in log.** No quest in your log uses the item. It may be left over from a finished quest, or it may be for a quest you have not picked up yet. Check before deleting.
- **Starts a quest.** The item starts a quest you have not done that is still worth experience.
- **On quest.** A quest in your log needs the item.

## Bag icons

Each quest item also gets an icon in the corner of its bag slot. This works in the game's own bags and in EllesmereUI Bags.

- **Green check.** Safe to delete (Quest done or Gray quest).
- **Question mark.** No quest in log. Check before deleting.
- **Red X.** Keep it (On quest or Starts a quest).

## Quest details

Hold Alt while hovering a quest item to see the quest ID, whether the quest is completed, in your log or not started, your progress on each objective, and the item ID. Use the IDs to look the quest up on a database site.

## The window

Type `/bloat` or `/bagbloat`, or click Bag Bloat in the addon compartment by the minimap. The window lists your quest items with the ones you can delete at the top, and shows how many are safe to delete.

- Click a row to pick the item up, then click outside your bags. The game asks you to confirm the delete.
- Shift-click a row to link the item in chat.
- Hover a row for the full item tooltip.

Bag Bloat never deletes anything itself.

## How it decides

Quest-starting items are checked against your completed quests, your quest log and the quest's level. Items that a quest asks you to collect are matched by name against the objectives of the quests in your log. Bag Bloat scans your bags only when they or your quest log change, and has no settings. In combat it only shows what it already knows and checks again once combat ends.
