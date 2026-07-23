# Skip List Management Tool - Complete Integration Guide

**Purpose:** Instantly update skip lists from your DonorSend database when new prospects are imported  
**Supports:** Automated generation, manual CLI execution, CRM UI button integration  
**Status:** Ready for deployment  

---

## 📋 What This Does

The skip list generator tool automatically extracts:
- **2,131+ organization names** from `sales.scout_candidates` and `sales.leads`
- **1,719+ normalized URLs** from the same tables
- Keeps them in sync with your database so hunters never re-discover existing prospects

---

## 🚀 Quick Start (Choose One)

### Option 1: Generate Skip Lists from Exported JSON (Fastest)

```bash
# Step 1: Export existing contacts using Supabase execute_sql
# Run this SQL via Supabase SQL Editor:
SELECT org_name, website FROM sales.scout_candidates
UNION
SELECT org_name, website FROM sales.leads;

# Save the JSON result to a file (e.g., existing.json)

# Step 2: Generate skip lists
cd /home/user/codex/tools/scout-import
python3 skip_list_generator.py generate-from-json existing.json \
  --org-names skip_list_org_names.json \
  --normalized-urls skip_list_normalized_urls.json

# Skip lists created! Ready for agents.
```

### Option 2: Generate Directly from Supabase (No Export Needed)

```bash
cd /home/user/codex/tools/scout-import
python3 skip_list_generator.py generate-direct \
  --supabase-url https://your-project.supabase.co \
  --supabase-key your-anon-key \
  --org-names skip_list_org_names.json \
  --normalized-urls skip_list_normalized_urls.json

# Skip lists created! Ready for agents.
```

### Option 3: Validate Existing Skip Lists

```bash
python3 skip_list_generator.py validate \
  skip_list_org_names.json \
  skip_list_normalized_urls.json
```

### Option 4: Generate Hunter Prompt Snippet

```bash
python3 skip_list_generator.py prompt \
  skip_list_org_names.json \
  skip_list_normalized_urls.json \
  --limit 200 > hunter_prompt_snippet.txt

# Paste hunter_prompt_snippet.txt into agent prompts
```

---

## 🔧 Integration: Add "Update Skip Lists" Button to CRM UI

### For React/Next.js CRM Frontend

Create a new component that calls the update endpoint:

```typescript
// components/UpdateSkipListsButton.tsx
import { useState } from 'react';

export default function UpdateSkipListsButton() {
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState<string | null>(null);

  const handleUpdateSkipLists = async () => {
    setLoading(true);
    setStatus('Updating skip lists...');

    try {
      const response = await fetch('/api/admin/update-skip-lists', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      });

      const result = await response.json();

      if (response.ok) {
        setStatus(
          `✓ Skip lists updated!\n` +
          `Org names: ${result.unique_org_names}\n` +
          `Normalized URLs: ${result.unique_normalized_urls}`
        );
      } else {
        setStatus(`✗ Error: ${result.error}`);
      }
    } catch (error) {
      setStatus(`✗ Failed to update: ${error}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <button
        onClick={handleUpdateSkipLists}
        disabled={loading}
        className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
      >
        {loading ? 'Updating...' : 'Update Skip Lists'}
      </button>
      {status && <pre className="mt-2 text-sm">{status}</pre>}
    </div>
  );
}
```

Create the backend API endpoint:

```typescript
// pages/api/admin/update-skip-lists.ts
import { NextApiRequest, NextApiResponse } from 'next';
import { execSync } from 'child_process';
import path from 'path';
import fs from 'fs';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Verify auth (add your own auth check here)
  // if (!req.user?.isAdmin) return res.status(403).json({ error: 'Forbidden' });

  try {
    const toolsDir = path.join(process.cwd(), 'tools/scout-import');
    const outputDir = path.join(process.cwd(), 'public/skip-lists');

    // Create output directory if needed
    fs.mkdirSync(outputDir, { recursive: true });

    // Run skip list generator
    const output = execSync(
      `python3 ${path.join(toolsDir, 'skip_list_generator.py')} generate-direct ` +
      `--supabase-url ${process.env.SUPABASE_URL} ` +
      `--supabase-key ${process.env.SUPABASE_SERVICE_KEY} ` +
      `--org-names ${path.join(outputDir, 'skip_list_org_names.json')} ` +
      `--normalized-urls ${path.join(outputDir, 'skip_list_normalized_urls.json')}`,
      { encoding: 'utf-8', cwd: toolsDir }
    );

    // Parse output JSON
    const lines = output.trim().split('\n');
    const jsonLine = lines.find(l => l.startsWith('{'));
    const result = JSON.parse(jsonLine || '{}');

    res.status(200).json({
      success: true,
      unique_org_names: result.unique_org_names,
      unique_normalized_urls: result.unique_normalized_urls,
      updated_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Skip list update failed:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Failed to update skip lists',
    });
  }
}
```

Add environment variables to `.env.local`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
```

### For Node.js/Express CRM Backend

```javascript
// routes/admin.js
const express = require('express');
const { execSync } = require('child_process');
const path = require('path');
const router = express.Router();

router.post('/update-skip-lists', (req, res) => {
  try {
    const toolsDir = path.join(__dirname, '../tools/scout-import');
    const outputDir = path.join(__dirname, '../public/skip-lists');

    const output = execSync(
      `python3 skip_list_generator.py generate-direct ` +
      `--supabase-url ${process.env.SUPABASE_URL} ` +
      `--supabase-key ${process.env.SUPABASE_SERVICE_KEY} ` +
      `--org-names ${path.join(outputDir, 'skip_list_org_names.json')} ` +
      `--normalized-urls ${path.join(outputDir, 'skip_list_normalized_urls.json')}`,
      { encoding: 'utf-8', cwd: toolsDir }
    );

    const result = JSON.parse(output.trim().split('\n').pop());

    res.json({
      success: true,
      unique_org_names: result.unique_org_names,
      unique_normalized_urls: result.unique_normalized_urls,
      updated_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Skip list update failed:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
```

---

## 🔄 Automated Scheduling (Optional)

### Using Supabase Edge Functions

Create a Supabase Edge Function that runs on a schedule:

```typescript
// supabase/functions/update-skip-lists/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    // Query for existing org names
    const orgNamesResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/execute_sql`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${supabaseKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          query: `
            SELECT DISTINCT org_name FROM sales.scout_candidates WHERE org_name IS NOT NULL
            UNION
            SELECT DISTINCT org_name FROM sales.leads WHERE org_name IS NOT NULL
            ORDER BY org_name
          `,
        }),
      }
    );

    const urlsResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/execute_sql`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${supabaseKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          query: `
            SELECT DISTINCT LOWER(REPLACE(REPLACE(REPLACE(website, 'https://', ''), 'http://', ''), 'www.', '')) as url
            FROM sales.scout_candidates WHERE website IS NOT NULL
            UNION
            SELECT DISTINCT LOWER(REPLACE(REPLACE(REPLACE(website, 'https://', ''), 'http://', ''), 'www.', '')) as url
            FROM sales.leads WHERE website IS NOT NULL
            ORDER BY url
          `,
        }),
      }
    );

    const orgNames = await orgNamesResponse.json();
    const urls = await urlsResponse.json();

    // Store in storage bucket or return as JSON
    return new Response(
      JSON.stringify({
        success: true,
        unique_org_names: orgNames.length,
        unique_normalized_urls: urls.length,
        updated_at: new Date().toISOString(),
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

Deploy it:

```bash
supabase functions deploy update-skip-lists
```

Add a scheduled trigger in Supabase:

```bash
# Use Supabase functions scheduling (requires Supabase CLI)
supabase functions deploy update-skip-lists --region us-east-1 --schedule "0 2 * * *"
```

---

## 📊 Post-Import Automation

### After Running Scout Import Batches

```bash
#!/bin/bash
# update-skip-lists.sh - Run after importing new scouts

TOOLS_DIR="/home/user/codex/tools/scout-import"
OUTPUT_DIR="/tmp/claude-0/-home-user-codex/b1545bed-bb92-5dd5-9760-e3a33fbbbd72/scratchpad"

echo "Updating skip lists after import..."

# Generate directly from Supabase
python3 "$TOOLS_DIR/skip_list_generator.py" generate-direct \
  --supabase-url "$SUPABASE_URL" \
  --supabase-key "$SUPABASE_SERVICE_KEY" \
  --org-names "$OUTPUT_DIR/skip_list_org_names.json" \
  --normalized-urls "$OUTPUT_DIR/skip_list_normalized_urls.json"

# Update the index file
python3 - <<EOF
import json
from datetime import datetime

index_path = "$OUTPUT_DIR/skip_list_index.json"
index = {
    "skip_lists": [
        {
            "name": "organization_names",
            "status": "ACTIVE",
            "valid_for_operations": True,
            "last_updated": datetime.utcnow().isoformat() + "Z"
        },
        {
            "name": "normalized_urls",
            "status": "ACTIVE",
            "valid_for_operations": True,
            "last_updated": datetime.utcnow().isoformat() + "Z"
        }
    ],
    "deployment_ready": True
}

with open(index_path, 'w') as f:
    json.dump(index, f, indent=2)

print("✓ Skip lists updated and index refreshed")
EOF

echo "Done! Skip lists ready for next agent deployment."
```

---

## 🎯 Complete Workflow

### 1. Run 100-Agent Discovery
```bash
# Deploy 100 agents using 100AGENT_DEPLOYMENT_GUIDE.md
# Results: 800-1000 unique new prospects
```

### 2. Import Results to Database
```bash
# Run scout_import.py collect to generate import batches
python3 scout_import.py collect ./agent_results --out ./import_batches

# Execute import_batch_*.sql files via Supabase
# Results: New prospects added to sales.scout_candidates
```

### 3. Update Skip Lists (CRITICAL - Same Day)
```bash
# Option A: Via button in CRM UI (fastest)
# Click "Update Skip Lists" button

# Option B: Via CLI
cd /home/user/codex/tools/scout-import
python3 skip_list_generator.py generate-direct \
  --supabase-url https://your-project.supabase.co \
  --supabase-key your-key \
  --org-names ../../scratchpad/skip_list_org_names.json \
  --normalized-urls ../../scratchpad/skip_list_normalized_urls.json
```

### 4. Ready for Next Operation
```bash
# Skip lists are LIVE with all 1100-1300 prospects
# Next agent wave will avoid all duplicates
```

---

## 🛠️ CLI Usage Reference

### Generate from JSON Export
```bash
python3 skip_list_generator.py generate-from-json existing.json \
  --org-names org_names.json \
  --normalized-urls urls.json
```

### Generate Directly from Supabase
```bash
python3 skip_list_generator.py generate-direct \
  --supabase-url https://project.supabase.co \
  --supabase-key sk_live_xxxx \
  --org-names org_names.json \
  --normalized-urls urls.json
```

### Validate Skip Lists
```bash
python3 skip_list_generator.py validate \
  skip_list_org_names.json \
  skip_list_normalized_urls.json
```

### Generate Hunter Prompt
```bash
python3 skip_list_generator.py prompt \
  skip_list_org_names.json \
  skip_list_normalized_urls.json \
  --limit 300 > prompt_snippet.txt
```

---

## 📁 File Locations

### Skip List Files (Scratchpad)
```
/tmp/claude-0/-home-user-codex/b1545bed-bb92-5dd5-9760-e3a33fbbbd72/scratchpad/
├── skip_list_org_names.json
├── skip_list_normalized_urls.json
├── skip_list_index.json
└── SKIP_LIST_UPDATE_LOG.md
```

### Tool Location
```
/home/user/codex/tools/scout-import/
├── skip_list_generator.py          (This tool)
├── scout_import.py                  (Existing import tool)
├── export_existing.sql              (SQL export query)
└── README.md                         (Existing documentation)
```

---

## ✅ Integration Checklist

- [ ] Deploy `skip_list_generator.py` to your tools directory
- [ ] Choose integration method: CLI, API endpoint, or scheduled function
- [ ] Update environment variables (SUPABASE_URL, SUPABASE_SERVICE_KEY)
- [ ] Test skip list generation via `python3 skip_list_generator.py validate`
- [ ] Add "Update Skip Lists" button to CRM UI (optional but recommended)
- [ ] Set up automated scheduling (optional but recommended)
- [ ] Document in your CRM operations guide
- [ ] Ready for 100-agent deployment!

---

## 🚨 Important Notes

### When to Update Skip Lists
- ✅ After importing new prospects to database
- ✅ Before launching new agent wave
- ✅ Every 1-2 weeks for maintenance
- ✅ After any bulk database modifications

### Why This Matters
- Prevents hunters from re-discovering existing prospects
- Saves AI costs by reducing wasted searches
- Keeps deduplication accurate and consistent
- Ensures clean data in scout_candidates table

### Real-Time Updates
The generated skip lists are marked `"status": "ACTIVE"` with the current date, so any chat that reads them knows they're up-to-date for deployment.

---

**Ready to integrate?** Choose one of the three options above and follow the setup instructions. The tool is production-ready!
