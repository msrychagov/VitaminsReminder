# Analytics Backend Contract

## Ingest

- Method: `POST /api/v1/analytics/events`
- Request: JSON batch with `batch_id`, `sent_at`, `events`
- Batch size: client prefers `20...100`, but background flush may send a smaller tail batch
- Idempotency: `event_id` is globally unique and deduplicated in PostgreSQL
- Retry policy: client retries on network failures and `5xx`

Example response:

```json
{
  "accepted": 95,
  "deduplicated": 5
}
```

## Export

- Method: `GET /api/v1/admin/analytics/export?from=...&to=...&event=...&format=csv|jsonl`
- Access: admin token or admin role
- Formats:
  - `csv`
  - `jsonl`

## Event naming

- Format: `domain.action`
- Examples:
  - `auth.login_success`
  - `vitamins.reminder_created`
  - `notification.clicked`

## Recommended properties

- `screen`, `flow`, `step`, `duration_ms`
- `catalog_id`, `form`, `condition`, `dose`
- `times_count`, `days_count`
- `error_code`, `http_status`, `endpoint`
- `is_guest`, `has_note`, `has_overrides`
