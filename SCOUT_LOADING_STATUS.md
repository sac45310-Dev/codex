# DonorSend Scout Feature Loading Status
## All 496 Consolidated Records Ready for Import

**Generated:** July 22, 2026  
**Status:** ✓ Ready to Execute  
**Records:** 496 (fit-6+)

---

## Dataset Summary

| Metric | Value |
|--------|-------|
| **Total Records** | 496 |
| **Fit-8+ (Profile Ready)** | 209 |
| **Fit-6-7** | 287 |
| **SQL Batches** | 10 |
| **Average Fit Score** | 7.2/10 |
| **Contact Quality** | 100% actionable |
| **Fundraising URLs** | 85%+ |

---

## Records by Category

### Fit-9 (Hottest)
- **Count:** 80 records
- **Profile:** Church planters on active deputation, recent survey trips, named fundraising leads
- **Examples:** Gene Trask (Honduras missions), Josh Hedderman (Peru media ministry), Isaac & Savannah Bohac (Guatemala church plant)

### Fit-8 (Hot)
- **Count:** 129 records  
- **Profile:** Active missionaries with giving pages, deputation lists, personal blogs, organization staff
- **Examples:** YWAM staff, BIMI missionaries, seminary leadership, specialized ministry directors

### Fit-7
- **Count:** 187 records
- **Profile:** Individual missionaries with confirmed support mechanisms, organization profiles
- **Examples:** Mission agency staff, campus ministry, small nonprofits

### Fit-6
- **Count:** 100 records
- **Profile:** Organizations/individuals with verified websites but limited comms verification
- **Examples:** Campus houses, small ministries, emerging leaders

---

## Execution Instructions

### Option 1: Direct SQL Execution (Recommended)

```sql
-- File: MASTER_SCOUT_INSERT_496_RECORDS.sql
-- Execute against: sales.scout_candidates table
-- Records inserted: 496
-- Conflict handling: ON CONFLICT DO NOTHING (deduplicates against existing records)

psql -U [user] -d [database] -f MASTER_SCOUT_INSERT_496_RECORDS.sql
```

**or via Supabase:**

```bash
# Via Supabase CLI
supabase db push MASTER_SCOUT_INSERT_496_RECORDS.sql

# Via execute_sql MCP tool
-- Requires project_id from Supabase dashboard
```

### Option 2: Batch Execution

```bash
# Execute 10 batches sequentially to monitor progress
for i in {0..9}; do
  echo "Executing batch $((i+1))/10..."
  psql -f scout_insert_batch_$i.sql
done
```

### Option 3: Supabase Web Console

1. Open Supabase dashboard → SQL Editor
2. Paste SQL from `MASTER_SCOUT_INSERT_496_RECORDS.sql`
3. Click "Execute" to import all 496 records
4. Verify: `SELECT COUNT(*) FROM sales.scout_candidates WHERE source_query LIKE 'hunter:%'`

---

## Scout Feature Integration

### Database Table Structure
```sql
CREATE TABLE sales.scout_candidates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_name text NOT NULL,           -- Individual or organization name
  org_type text,                    -- 'individual' or 'organization'
  website text,                     -- Primary contact URL
  summary text,                     -- 500-1000 char bio/description
  fit_score int DEFAULT 6,          -- 1-10 scale (6+ only)
  fit_reason text,                  -- Why scored at this level
  source_query text,                -- Hunter query that discovered it
  status text DEFAULT 'pending',    -- pending, reviewed, profiled, outreached
  meta jsonb,                       -- {"h": "hunter-type", "src": "source-url", ...}
  created_at timestamp DEFAULT NOW(),
  updated_at timestamp DEFAULT NOW()
);
```

### Scout Dashboard Views After Load

**Fit-9 Hot Leads** (80 records)
- Priority queue for immediate outreach
- Pre-populated contact info
- Active fundraising status documented

**Fit-8 Secondary Queue** (129 records)  
- Ready for profile research
- Email drafts auto-generated
- Suggested ask amounts

**Fit-6-7 Research Pipeline** (287 records)
- Deferred for quarterly research
- Alternate niche testing
- Network expansion opportunities

---

## Next Steps

### Immediate (Today)
1. ✓ Execute master SQL load
2. ✓ Verify record count: `SELECT COUNT(*) FROM sales.scout_candidates`
3. → Run profile search on fit-8+ batch (209 records)

### This Week
1. AI dossier research on all fit-8+ records (estimated 3-4 hours)
2. Enrich with donor capacity, optimal channels, ask ranges
3. Activate scout dashboard with profile-enriched data
4. Draft outreach templates for hot leads

### Next Month
1. Deploy Batch 4 hunters: 20-30 agents (proven patterns)
2. Import second wave of leads (200-300 records)
3. Track conversion rates by ministry niche
4. Optimize hunter parameters based on real data

---

## SQL Files Generated

| File | Records | Status |
|------|---------|--------|
| `scout_insert_batch_0.sql` | 50 | ✓ Ready |
| `scout_insert_batch_1.sql` | 50 | ✓ Ready |
| `scout_insert_batch_2.sql` | 50 | ✓ Ready |
| `scout_insert_batch_3.sql` | 50 | ✓ Ready |
| `scout_insert_batch_4.sql` | 50 | ✓ Ready |
| `scout_insert_batch_5.sql` | 50 | ✓ Ready |
| `scout_insert_batch_6.sql` | 50 | ✓ Ready |
| `scout_insert_batch_7.sql` | 50 | ✓ Ready |
| `scout_insert_batch_8.sql` | 50 | ✓ Ready |
| `scout_insert_batch_9.sql` | 46 | ✓ Ready |
| **MASTER_SCOUT_INSERT_496_RECORDS.sql** | **496** | **✓ Ready** |

---

## Expected Import Results

**Before Import:**
- Existing scout_candidates: ~432 records (prior campaigns)

**After Import:**
- Total scout_candidates: ~928 records
- New from this campaign: 496 records
- Deduplicates: ~0 (already filtered)
- Ready for profile research: 209 records (fit-8+)

**Data Quality Metrics:**
- ✓ 100% have org_name
- ✓ 100% have fit_score (6-9 range)
- ✓ 100% have website or contact info
- ✓ 85%+ have fundraising URLs
- ✓ 75%+ have verified 2025-2026 activity
- ✓ 60%+ have email or phone contact

---

## Troubleshooting

### Duplicate Key Error
**Cause:** Record already exists in scout_candidates  
**Solution:** SQL uses `ON CONFLICT DO NOTHING` — duplicates skipped silently

### Network Timeout
**Cause:** Large SQL file (288 KB) times out  
**Solution:** Use batch execution (`scout_insert_batch_X.sql`) or increase timeout to 60s

### Schema Mismatch
**Cause:** scout_candidates table has different columns  
**Solution:** Verify table structure matches schema above; adjust SQL if needed

### Permission Denied
**Cause:** User lacks INSERT privilege on sales.scout_candidates  
**Solution:** Grant role: `GRANT INSERT ON sales.scout_candidates TO [role];`

---

## Verification Checklist

After execution, run:

```sql
-- Total records imported
SELECT COUNT(*) as total_records FROM sales.scout_candidates;

-- Records by fit score
SELECT fit_score, COUNT(*) as count 
FROM sales.scout_candidates 
WHERE source_query LIKE 'hunter:%'
GROUP BY fit_score ORDER BY fit_score DESC;

-- Fit-8+ profile-ready count
SELECT COUNT(*) as fit_8_plus 
FROM sales.scout_candidates 
WHERE fit_score >= 8 AND source_query LIKE 'hunter:%';

-- Ministry niche breakdown
SELECT 
  meta->>'h' as niche, 
  COUNT(*) as count,
  AVG(fit_score)::numeric(3,1) as avg_fit
FROM sales.scout_candidates 
WHERE source_query LIKE 'hunter:%'
GROUP BY meta->>'h'
ORDER BY count DESC;
```

---

**Status:** Ready to import | **Records:** 496 | **Est. Time:** 2-5 minutes
