-- 1. Enable permissions for Extensions
-- Run these locally first to ensure your user has permissions
-- NOTE: If you are on Supabase free tier, these extensions are usually allowed by default.

CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Clear any existing keep-alive job to avoid duplicates
SELECT cron.unschedule('render-heartbeat');

-- 3. Schedule the 10-minute heartbeat
-- This will call the /health endpoint of your Render server.
-- Render free tier sleeps after 15 minutes, so 10 minutes is the safe spot.

SELECT cron.schedule(
  'render-heartbeat',     -- Job name
  '*/10 * * * *',         -- Cron: Every 10 minutes
  $$
  SELECT net.http_get(
    'https://zdorovya.onrender.com/health'
  );
  $$
);

-- 💡 HOW TO VERIFY:
-- You can check if the job is running by executing this:
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 5;
