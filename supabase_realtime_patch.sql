-- Enable Realtime for critical tables required for broadcast and chat features
BEGIN;

-- Add checking mechanism to see if publication exists, and add tables to it.
-- Supabase by default has a 'supabase_realtime' publication.
-- We must add our tables to it to enable real-time streaming in the app.

-- Enable realtime for Pickups (Broadcasts & Tracking)
ALTER PUBLICATION supabase_realtime ADD TABLE public.pickups;

-- Enable realtime for Messages (Live Chat)
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- Enable realtime for Notifications (Live Alerts)
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

COMMIT;
