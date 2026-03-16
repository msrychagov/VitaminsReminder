CREATE TABLE IF NOT EXISTS analytics_events (
    event_id UUID PRIMARY KEY,
    occurred_at TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id BIGINT NULL,
    anonymous_id UUID NULL,
    session_id UUID NOT NULL,
    event_name TEXT NOT NULL,
    properties JSONB NOT NULL DEFAULT '{}'::jsonb,
    request_id TEXT NULL,
    app_version TEXT NULL,
    platform TEXT NULL
);

CREATE INDEX IF NOT EXISTS analytics_events_event_name_occurred_at_idx
    ON analytics_events (event_name, occurred_at DESC);

CREATE INDEX IF NOT EXISTS analytics_events_user_id_occurred_at_idx
    ON analytics_events (user_id, occurred_at DESC)
    WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS analytics_events_anonymous_id_occurred_at_idx
    ON analytics_events (anonymous_id, occurred_at DESC)
    WHERE anonymous_id IS NOT NULL;

COMMENT ON TABLE analytics_events IS 'Client analytics event store for ingest endpoint /api/v1/analytics/events';
COMMENT ON COLUMN analytics_events.event_id IS 'Unique event id used for idempotent deduplication';
COMMENT ON COLUMN analytics_events.occurred_at IS 'Timestamp when the event happened on the device';
COMMENT ON COLUMN analytics_events.received_at IS 'Timestamp set by the server on ingest';

-- Optional retention example:
-- DELETE FROM analytics_events
-- WHERE occurred_at < NOW() - INTERVAL '12 months';
