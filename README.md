# Bag Bloat

Bag Bloat checks the quest items in your bags on WoW Forever and tells you which
ones you can delete.

Every quest item gets one of these labels, in its tooltip and in the Bag Bloat
window:

| Label | Meaning |
| --- | --- |
| Quest done | The item starts a quest you already completed. Safe to delete. |
| Gray quest | The item starts a quest that is gray for your level. Safe to delete. |
| No quest in log | No quest in your log uses the item. It may be left over from a finished quest, or you may need it for a quest you have not picked up yet. Check before deleting. |
| Starts a quest | The item starts a quest you have not done and that still gives experience. |
| On quest | A quest in your log needs the item. |

Open the window with `/bloat`, `/bagbloat` or the addon compartment button next
to the minimap. Click a row to pick the item up, then click outside your bags to
delete it through the game's own confirmation. Shift-click a row to link the
item in chat. Bag Bloat never deletes anything itself.

## Releasing

Pushing a tag publishes: GitHub Actions runs the BigWigs packager, which uploads
to CurseForge once the TOC has `## X-Curse-Project-ID` and the repository has a
`CF_API_KEY` secret.

```
git tag v0.1.0
git push origin v0.1.0
```
