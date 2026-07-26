-- Additive only: no drops, no destructive changes.

-- 1) shared updated_at trigger, namespaced to sales so nothing public is clobbered
CREATE OR REPLACE FUNCTION sales.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 2) extend sales.contacts so enrichment can attach to scout_candidates, not just leads
ALTER TABLE sales.contacts
  ALTER COLUMN lead_id DROP NOT NULL;

ALTER TABLE sales.contacts
  ADD COLUMN IF NOT EXISTS scout_candidate_id uuid
    REFERENCES sales.scout_candidates(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS email_kind      text,
  ADD COLUMN IF NOT EXISTS phone_kind      text,
  ADD COLUMN IF NOT EXISTS org_email       text,
  ADD COLUMN IF NOT EXISTS org_phone       text,
  ADD COLUMN IF NOT EXISTS linkedin_url    text,
  ADD COLUMN IF NOT EXISTS address_line1   text,
  ADD COLUMN IF NOT EXISTS address_line2   text,
  ADD COLUMN IF NOT EXISTS city            text,
  ADD COLUMN IF NOT EXISTS state           text,
  ADD COLUMN IF NOT EXISTS postal_code     text,
  ADD COLUMN IF NOT EXISTS country         text,
  ADD COLUMN IF NOT EXISTS confidence      smallint,
  ADD COLUMN IF NOT EXISTS source_url      text,
  ADD COLUMN IF NOT EXISTS verified        boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS verified_at     timestamptz,
  ADD COLUMN IF NOT EXISTS enriched_at     timestamptz,
  ADD COLUMN IF NOT EXISTS notes           text,
  ADD COLUMN IF NOT EXISTS meta            jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS updated_at      timestamptz NOT NULL DEFAULT now();

-- exactly one parent: a contact belongs to a lead OR a scout candidate, never both/neither
ALTER TABLE sales.contacts
  DROP CONSTRAINT IF EXISTS contacts_one_parent_chk;
ALTER TABLE sales.contacts
  ADD CONSTRAINT contacts_one_parent_chk
  CHECK (num_nonnulls(lead_id, scout_candidate_id) = 1);

ALTER TABLE sales.contacts
  DROP CONSTRAINT IF EXISTS contacts_email_kind_chk;
ALTER TABLE sales.contacts
  ADD CONSTRAINT contacts_email_kind_chk
  CHECK (email_kind IS NULL OR email_kind IN ('direct','role','org'));

ALTER TABLE sales.contacts
  DROP CONSTRAINT IF EXISTS contacts_phone_kind_chk;
ALTER TABLE sales.contacts
  ADD CONSTRAINT contacts_phone_kind_chk
  CHECK (phone_kind IS NULL OR phone_kind IN ('direct','extension','org'));

ALTER TABLE sales.contacts
  DROP CONSTRAINT IF EXISTS contacts_confidence_chk;
ALTER TABLE sales.contacts
  ADD CONSTRAINT contacts_confidence_chk
  CHECK (confidence IS NULL OR confidence BETWEEN 1 AND 10);

CREATE INDEX IF NOT EXISTS contacts_scout_candidate_id_idx
  ON sales.contacts (scout_candidate_id);
CREATE INDEX IF NOT EXISTS contacts_lead_id_idx
  ON sales.contacts (lead_id);
CREATE INDEX IF NOT EXISTS contacts_email_lower_idx
  ON sales.contacts (lower(email)) WHERE email IS NOT NULL;

-- idempotency for the enrichment agent: one contact per person per parent
CREATE UNIQUE INDEX IF NOT EXISTS contacts_scout_person_uniq
  ON sales.contacts (scout_candidate_id, lower(trim(name)))
  WHERE scout_candidate_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS contacts_lead_person_uniq
  ON sales.contacts (lead_id, lower(trim(name)))
  WHERE lead_id IS NOT NULL;

DROP TRIGGER IF EXISTS contacts_set_updated_at ON sales.contacts;
CREATE TRIGGER contacts_set_updated_at
  BEFORE UPDATE ON sales.contacts
  FOR EACH ROW EXECUTE FUNCTION sales.set_updated_at();

COMMENT ON COLUMN sales.contacts.email_kind IS
  'direct = personal mailbox; role = shared role box (info@, giving@); org = main org address';
COMMENT ON COLUMN sales.contacts.confidence IS
  '1-10 confidence this contact reaches this person. Outreach layer sets its own threshold.';

-- 3) URL scour registry: per-URL granularity so a person page can be excluded
--    without blocking the directory it came from.
CREATE TABLE IF NOT EXISTS sales.urls_scoured (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  url             text NOT NULL UNIQUE,
  domain          text NOT NULL,
  url_type        text NOT NULL DEFAULT 'unknown',
  scour_status    text NOT NULL DEFAULT 'to_retry',
  prospects_found integer NOT NULL DEFAULT 0,
  contacts_found  integer NOT NULL DEFAULT 0,
  exclude         boolean NOT NULL DEFAULT false,
  exclude_reason  text,
  http_status     integer,
  last_scoured_at timestamptz,
  notes           text,
  meta            jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT urls_scoured_type_chk CHECK (
    url_type IN ('directory','listing','org_page','person_page','staff_index','unknown')),
  CONSTRAINT urls_scoured_status_chk CHECK (
    scour_status IN ('fully_mined','partial','blocked','to_retry','failed'))
);

CREATE INDEX IF NOT EXISTS urls_scoured_domain_idx ON sales.urls_scoured (domain);
CREATE INDEX IF NOT EXISTS urls_scoured_open_idx
  ON sales.urls_scoured (domain, url_type)
  WHERE exclude = false AND scour_status <> 'fully_mined';

DROP TRIGGER IF EXISTS urls_scoured_set_updated_at ON sales.urls_scoured;
CREATE TRIGGER urls_scoured_set_updated_at
  BEFORE UPDATE ON sales.urls_scoured
  FOR EACH ROW EXECUTE FUNCTION sales.set_updated_at();

-- match the locked-down posture of every other sales table:
-- RLS on, no policies => service_role only. This table will hold PII-adjacent data.
ALTER TABLE sales.urls_scoured ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE sales.urls_scoured IS
  'Registry of URLs visited by mining agents. Per-URL exclusion so a specific person page can be skipped while its parent directory stays open for further mining.';
