# Wave w2026-09-09a — local nonprofit prospecting

Date: 2026-09-09. Eight regional Haiku 4.5 agents, 144 searches, all executed.
First run of `prompts/local-prospector.md`.

## Results

- **301 organizations returned; 264 ingested** after correction and dedupe.
- Corpus: **798 orgs** (581 unrostered), 1,977 coverage rows, 310 negatives.
- Territories: Ohio Valley, Upper Midwest, Carolinas, Texas, Mountain West,
  Pacific NW, Northeast, Mid-South — roughly 50 cities.

| region | returned | with site | Tier A claimed | Tier A kept |
|---|---|---|---|---|
| Carolinas | 51 | 31 | 4 | 0 |
| Upper Midwest | 47 | 37 | 6 | 2 |
| Mid-South | 42 | 17 | 7 | 5 |
| Ohio Valley | 34 | 20 | 10 | 2 |
| Mountain West | 33 | 10 | 3 | 2 |
| Pacific NW | 32 | 15 | 4 | 0 |
| Texas | 31 | 7 | 0 | 0 |
| Northeast | 29 | 11 | 1 | 0 |

## The route worked; the registries would not have

The template's central bet paid off. **990 aggregators are the way in**:
ProPublica Nonprofit Explorer, CauseIQ and TaxExemptWorld are heavily indexed
and their snippets carry organization name, city and state directly, so a
fetch-blocked agent can read them straight out of search results. Community
foundation giving-day directories were the second seam.

Secretary of State and Attorney General charity registries — the authoritative
source — were correctly avoided. They are search-form-gated and JavaScript
driven; agents sent there would have spent 144 searches on nothing.

## Tier A: 35 claimed, 11 survived

Every region except Texas over-claimed Tier A, and each invented a different
justification for it:

- **Ohio** counted volunteer-run organizations. "100% volunteer-funded" is
  close to the opposite of support-raised — a volunteer is not raising donor
  support for a salary.
- **Upper Midwest** counted government-contract agencies. Lutheran Social
  Service of Minnesota and Lutheran Services in Iowa are largely publicly
  funded, which is a kill-test concern, not a Tier A qualification.
- **Pacific NW** counted galas and monthly-donor programs. Those are
  fundraising instruments, not staff funding models. El Centro de la Raza,
  FareStart, Transition Projects and NAYA are solid Tier B finds.
- **Carolinas** counted crisis pregnancy centers on "support model" phrasing.
  Some genuinely do use support-raised counselors; none showed evidence.
- **Texas** claimed nothing, parking church-planting networks in needs_review
  instead. **This was the correct behaviour** and it came from the same prompt.

The 11 kept are campus ministries and sending agencies with stated
staff-support models: YWAM Louisville, Campus Outreach (Lexington, Columbus,
Cleveland), Converge North Central, InterVarsity, Mosaic International, Reach
Beyond, City For The Nations, Every Nation Lexington, Bluegrass Christian
Fellowship. All marked `evidence_basis: org_policy` — an org-level model, not
a personal giving page.

**The lesson is that prose cannot enforce this.** Pacific NW was told
explicitly not to force Tier A and forced it anyway. The label needs a code
check at ingest, the way `normalize_person()` handles tiers and scores.

## Orchestrator corrections

- **1 rejected outright**: Minnesota-Wisconsin Baptist Convention, a
  denominational body.
- **19 removed by kill-test sweep**: six Catholic Charities diocesan bodies,
  three YMCA/YWCA affiliates, two United Ways, three community foundations,
  a museum, a science centre, and three nonprofit service providers.
- **27 of 98 agent negatives discarded rather than loaded.** Twenty-two were
  `already_in_system` for organizations we deliberately hold — The Navigators,
  Young Life, Compassion International, Campus Outreach. The targets insert
  refuses anything in `hunt_negatives`, so loading those would have
  permanently blocked re-adding them. This is the second wave running where
  agents have coded a skip-list confirmation as a rejection; it should become
  a filter in `scout_import.py` rather than a thing the orchestrator
  remembers to catch.
- **One website dropped**: The Stewpot carried `thewpot.org` in its JSON and
  `thestewpot.org` in the agent's prose. Rather than pick, the field is null.
- **One kill-test miss repaired**: "Young Men's Christian Association
  Youngstown" spelled out past the `ymca` pattern and was ingested, then
  retired.

## Outstanding

- **142 of 264 new organizations have no website** and cannot be rostered
  until a domain pass resolves them. Texas is the worst (7 of 31).
- Crisis pregnancy centres are worth one targeted check: several plausibly do
  use support-raised counselors, and if so the category is Tier A-rich and
  currently mis-scored across every region.
- `local-prospector.md` should gain the volunteer/government-funded/gala
  counter-examples, which are now three times observed rather than predicted.
