# Wave w2026-09-10k — untouched agencies

Four agents, 18 searches each (72), plus 7 orchestrator verification searches.

## Why untouched ground

Every domain worked so far is at or below the retirement line: Ethnos360 2.7,
CMML 1.1 (search-capped), Campus Outreach 1.0, RUF 0.75 (closed), Avant 0.67,
CCO 0.53 (closed). Verify-then-dispatch on a NEW agency is the only thing that
has opened a 3–5/query seam — CCO 5.0 and FMC 3.7 on first contact.

Six candidate agencies had zero query coverage. Seven searches verified them.

## Confirmed

| target | pattern | scale |
|---|---|---|
| **FOCUS** (Fellowship of Catholic University Students) | `focus.org/missionaries/<first-last>` — verified samuel-sproule, jacob-siciliano, hannah-hames | ~900 missionaries, all raise 100% of their own support |
| **Saint Paul's Outreach** | `spo.org/support-<first-last>` — verified support-alli-michaels, support-lola-martin, support-kaitlyn-richmond; index at `spo.org/find-a-missionary` | mid-size Catholic campus ministry |
| **Baptist Mid-Missions** | `bmm.org/families/<slug>` — verified `families/i-bethany`; indexes at `partner/view-all-missionaries` and `partner/find-a-missionary` | large Baptist sending agency |

**FOCUS is the best target found since CCO.** Full first-and-last name in the
slug, ~900 support-raised missionaries, and not one query has ever been spent
on the domain.

## Rejected

- **NET Ministries** — no per-person page; giving runs through a single
  campaign page. Its missionaries are also 9-month young-adult team members
  raising a one-off $7,000, which is a weaker fit than career support-raising.
- **ABWE** — two searches found only `abwe.org/give` and
  `give.abwe.org/projects/...`. No per-missionary slug surfaced.
- **Chi Alpha** — org-level giving only on chialpha.com. It is federated, so
  any per-person pages live on individual campus sites, which is a different
  and much larger search problem.
- **FCA** — already in `hunt_negatives` (already_in_crm, denomination).

## Baptist Mid-Missions needs unusual care

The one BMM profile that surfaced is **"Bethany I."** — surname withheld, slug
`i-bethany`. BMM runs a "Creative Access Nations" programme and its own
find-a-missionary page says some workers cannot be listed for security
reasons. **A withheld surname is the anonymization signal**: those go to
`needs_review`, never to `people[]`, even where the full name could be
inferred elsewhere. Expect a high proportion of them here.

## Assignments

| agent | target | slice |
|---|---|---|
| `focus-a` | FOCUS | missionaries A–M |
| `focus-n` | FOCUS | missionaries N–Z |
| `spo` | Saint Paul's Outreach | `support-<name>` pages and the missionary index |
| `bmm` | Baptist Mid-Missions | `families/` profiles and the missionary indexes |

## Tiering

FOCUS missionaries, SPO missionaries and BMM career missionaries all raise
their own full support: **Tier A**. Do not downgrade for job function or
location — that error cost 210 records in w2026-09-10f.

Do not emit students. FOCUS and SPO both work with student leaders alongside
paid missionaries; if a page does not distinguish them, grade `medium` and say
so.

## Standing rules that have caught real defects

- `source_url` must be a page about the person, never a search-results URL.
- Never cite a page that belongs to someone else.
- Full names only. First-name-only or withheld-surname records go to
  `needs_review`.
- The slug shape decides confidence: name in slug + name in title = `high`;
  an index or campus page that merely names them = `medium` /
  `staff_directory`.
