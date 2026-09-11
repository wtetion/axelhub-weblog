RARITY WEB LOG FIX

The Web Log rarity resolver no longer assumes Common by default.
It checks, in order:
1) direct rarity fields on the live egg record (including nested Attributes),
2) the live Assets catalog by multiple egg identifiers,
3) RarityData by numeric rarity id/number,
4) Unknown only if none of the above resolve.

Inventory entries remain grouped by egg name + rarity + mutation, so different egg rarities are kept separate in the dashboard.
