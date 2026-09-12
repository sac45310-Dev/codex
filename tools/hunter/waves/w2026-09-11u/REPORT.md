# Wave w2026-09-11u — Wycliffe, second pass

**Dispatched:** 4 agents, 72 searches on axes wave t never touched.
**Loaded: 25.** Yield **0.35 new people per query** — a quarter of the
1.3–1.4 retirement line, and a twelfth of wave t's 4.2.

**Wycliffe is now retired from search.** Target id 3 set to `exhausted`.

## My wave-t recommendation was wrong

I closed wave t by saying Wycliffe was "not a decay bet — the constraint is
query coverage, not roster depth", and that a second wave was the
highest-value dispatch available. This wave tested that and it did not hold.

What actually happens: **the search index returns the same well-indexed subset
of `/partner/` pages no matter what qualifier you attach.** New qualifier axes
do not reach new pages. The directory really does paginate past `?page=127`,
but those pages are not in the index, so no amount of query variety reaches
them. "Roster is deep" and "search can see the roster" are different claims,
and I conflated them.

The u-asia agent put it precisely: *"Most queries returned the same held
surnames repeatedly — the roster is heavily indexed, which compressed my
discovery window."*

| slice | searches | records | genuinely new |
|---|---|---|---|
| u-roles2 (unworked role words) | 18 | 35 | ~21 |
| u-africa2 (unworked countries) | 18 | 5 | 1 |
| u-langs (language/people-group names) | 18 | 4 | 2 |
| u-asia (unworked countries) | 18 | 1 | 1 |

**The axis I predicted would be richest was the worst.** Language and
people-group names — Gbari, Balantak, Supyire, Jarawara and a dozen more —
returned four records, of which two were already held and two were people I
had deliberately withheld. Countries produced almost nothing.

**Only the role axis still paid**, and specifically one cluster wave t had
missed: Wycliffe's *technical and publishing* staff — typesetting, composition,
software development, font and keyboard work, sociolinguistics, procurement
and logistics. Those 21 people are the real yield of this wave, and they are
the reason it wasn't a total loss.

## Three things the agents got wrong that the ingest caught

1. **Exclusion lists were not applied.** The brief listed all 149 held
   surnames. Agents re-emitted **Winters, Frank, Clark, Kreutz, Hahn,
   Wakefield, Johnson, Huggins, Wood** — all on that list. 15 of 45 records
   were already held.
2. **Withheld people were re-emitted.** Bob and Marilyn Busenitz and Debbie
   Hatfield were pulled in wave t as likely retired (closed date ranges,
   "Indonesia Balantak 1980-2010", "1990-2019 service"). Two agents surfaced
   them again and graded them normally. Held out again.
3. **First-name-only records were emitted as people.** `"Kent"` and `"Kim"`
   from `/partner/kentkimkids`. Both rejected at ingest.

None of these are exotic — they are the three rules the template states most
explicitly. An exclusion list in a brief is evidently not enough to make an
agent apply it; the ingest guard is what actually caught all three.

## Conclusion

The generalisable lesson, and it now has evidence on both sides: **a
continuation is worth running only when the first pass was cut short by
budget, not when it was cut short by the index.** Wave t stopped because 72
searches ran out; wave u proves it had in fact already reached everything
search could see. Every continuation this project has run has decayed —
Cadence 0.69/query, and now Wycliffe 0.35 — while every verified *fresh*
agency has returned 1.8–4.8. Prefer a fresh confirmed surface over a rich
known one.
