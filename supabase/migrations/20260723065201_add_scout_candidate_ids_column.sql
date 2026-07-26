
-- Add column to store consolidated scout_candidate_ids
ALTER TABLE sales.contacts 
ADD COLUMN scout_candidate_ids uuid[] DEFAULT ARRAY[]::uuid[];

-- Add comment
COMMENT ON COLUMN sales.contacts.scout_candidate_ids IS 'Array of all scout_candidate_ids for consolidated duplicates';
