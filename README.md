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
| On quest | A quest in your log needs the item. |

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
item in chat. Bag Bloat never deletes anything itself.

The window groups items by the zone of their quest, with your current zone
first. Items no quest in your log uses, and items safe to delete, get their own
groups at the end. While the bank is open, Bank on a group's header moves its
items to the bank and Take moves them back to your bags. The By zone box
switches back to one list. The window uses the Expressway font when EllesmereUI
or SharedMedia has it.

## Releasing

Pushing a tag publishes: GitHub Actions runs the BigWigs packager, which uploads
to CurseForge once the TOC has `## X-Curse-Project-ID` and the repository has a
`CF_API_KEY` secret.

```
git tag v0.1.0
git push origin v0.1.0
```
