BEGIN;

-- Drop the old overly restrictive policy
DROP POLICY IF EXISTS "Participant Update Pickups" ON public.pickups;

-- Create the new policy that allows a collector to update a pickup if it's currently unassigned.
CREATE POLICY "Participant Update Pickups" ON public.pickups FOR UPDATE USING (
    auth.uid() = user_id OR auth.uid() = collector_id OR collector_id IS NULL
);

COMMIT;
