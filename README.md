# Bag Bloat

Bag Bloat checks the quest items in your bags and bank on WoW Forever and tells you which
ones you can delete.

Every quest item gets one of these labels, in its tooltip and in the Bag Bloat
window:

| Label | Meaning |
| --- | --- |
| Quest done | The item starts a quest you already completed. Safe to delete. |
| Gray quest | The item starts a quest that is gray for your level. Safe to delete. |
| No quest in log | A quest item that no quest in your log uses, often left over from a quest you finished or dropped. Check before deleting. |
| Starts a quest | The item starts a quest you have not done and that still gives experience. |
| Hidden quest | The item starts a quest that has no name, which is how the game hides a quest. Keep it. |
| Secret quest | The item belongs to a known secret quest chain, such as the Dawn Waker chain the Skyborne ring starts, the Stone Key, the Bloody Map, the Coldflame Saber, Lyn the Ignored, Ta'shkal or the Malignant Root. Always kept. |
| Kept by you | You chose Keep for the item in the window. It stays kept unless a quest in your log needs it. |
| On quest | A quest in your log needs the item. That includes an item the quest handed you to deliver. |

An item you hide from the window is labeled Hidden by you. It gets no tooltip line and no bag icon.

In your bags, each quest item also gets a corner icon: a green check when you
have the quest or already completed it, a red X when the quest is gray or no quest in your log uses the item, and a
question mark when it starts a quest you have not picked up or belongs to a hidden
or secret quest. This works in the game's own bags and bank and in EllesmereUI
Bags and its bank.

Hold Alt while hovering a quest item for the quest ID, its status, your
objective progress and the item ID.

Open the window with `/bloat`, `/bagbloat` or the addon compartment button next
to the minimap. Click a row to pick the item up, then click outside your bags to
delete it through the game's own confirmation. Shift-click a row to link the
item in chat. Right-click a row to keep the item, hide it, or delete it. Bag
Bloat deletes an item only when you click Delete, one item per click, and only
items marked safe to delete.

The window groups items as follows, in this order:

- Ready to turn in: items for quests in your log that you can turn in now.
- Your current zone, then the other zones A to Z, by the zone of each item's quest.
- Not in your quest log: items no quest in your log uses.
- Safe to delete.
- Hidden by you. This group starts folded.

An item that starts a quest you have not picked up is listed under the zone
where that quest is turned in, for the 160 classic quests the bundled table
knows. The table is built from pfQuest data (MIT, see THIRD-PARTY.md) by
`tools/gen_quest_zones.py`. Other quest-starting items stay under Not in your
quest log.

Click a group's header to fold or unfold it; it remembers which groups you
folded. The search box at the top right filters the list by item name, quest
title or zone, and shows every match while it has text. Escape clears the text,
then closes the window.

Bank items stay in the window from your last bank visit, marked (bank), so you
can see them away from the bank. When you enter a zone that has quest items for
it in your bank, Bag Bloat prints one chat line about it. While the bank is
open, Bank on a group's header moves its items to the bank and Take moves them
back to your bags.

The Delete button on the Safe to delete group asks twice. The first click
changes it to Sure?, and each click after that deletes the next item in the
group, one per click. It disarms 10 seconds after your last click or when you
close the window. The By zone box switches back to one list. Drag the
bottom-right corner to resize the window; it remembers its size. The window
uses the Expressway font when EllesmereUI or SharedMedia has it.

When your bags fill up and some quest items in them are safe to delete, Bag
Bloat prints one chat line saying how many, at most every two minutes.

Keep and hide choices are saved per character.

## Why an item has its label

`/bloat why` opens a box with what the game reports for one item and how each
rule decided its label and zone. Type `/bloat why` while hovering an item in
your bags or in the window, or add an item link or item ID after `why`. Press
Ctrl+C to copy the text, for example into a bug report. It does not work in
combat.

## Releasing

Pushing a tag publishes: GitHub Actions runs the BigWigs packager, which uploads
to CurseForge once the TOC has `## X-Curse-Project-ID` and the repository has a
`CF_API_KEY` secret.

```
git tag v0.1.0
git push origin v0.1.0
```
