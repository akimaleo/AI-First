# AI Capture the Moment — integration spec

This document is the contract between the Flutter client and the
`selfie-transform` edge function. It is the source of truth for how the
"Capture the Moment" feature calls the AI service.

## Flow

```
 ┌───────────────────┐        ┌───────────────────┐        ┌──────────────┐
 │ CaptureMoment UI  │──────▶│ selfie-transform  │──────▶│  Replicate   │
 │ (Flutter)         │        │ (Supabase edge)   │        │ (Flux Kontext)│
 └───────────────────┘        └───────────────────┘        └──────────────┘
         │                             │                           │
         │                             ├─ upload input to         ─┘
         │                             │   storage/selfies/…
         │                             │
         │   signed output URL         │
         ▼                             ▼
   Display modified selfie       ai_selfies row
   (hero screen, share sheet)   (job + latency audit trail)
```

## Client contract

Entry points in `lib/`:

| Layer    | File / symbol                                                      |
| -------- | ------------------------------------------------------------------ |
| Model    | `lib/shared/models/ai_selfie.dart` — `AiSelfieJob`, `AiSelfieStatus`, `AiSelfiePromptKeys` |
| Service  | `lib/shared/services/ai_selfie_service.dart` — raw edge-function client |
| Pipeline | `lib/shared/services/replicate_selfie_pipeline_service.dart` — implements `SelfiePipelineService` from GUSAA-10 |
| Provider | `lib/providers/ai_selfie_provider.dart` — `selfiePipelineServiceProvider`, `aiSelfieTransformProvider` |

Camera flow (GUSAA-10) consumes `selfiePipelineServiceProvider`. It gets back
a `SelfiePipelineResult { modifiedImagePath, originalImagePath, prompt, usedFallback }`.

The session-aware surface `transformSelfieInSession` adds `sessionId` and
`roundId` so multiplayer games can show the modified selfie to the other
player and persist it for the results screen.

## Prompt keys

Scenarios are enumerated in both `supabase/functions/selfie-transform/prompts.ts`
and `lib/shared/models/ai_selfie.dart`. Keep the two in sync when adding a new
scenario.

Available keys: `third_eye`, `zombie`, `robot`, `alien_skin`, `vampire`,
`cartoon`, `werewolf`, `cyberpunk`, `angel`, `devil`.

The server rejects unknown keys; free-form prompts are **not** accepted for
safety and consistency.

## Edge function API

### `POST /functions/v1/selfie-transform`

Headers: `Authorization: Bearer <supabase access token>` (JWT verified).

```json
{
  "promptKey": "third_eye",
  "image": "data:image/jpeg;base64,...",
  "sessionId": "uuid-or-null",
  "roundId":   "uuid-or-null",
  "mode": "sync"
}
```

- `mode: "sync"` waits up to `SELFIE_MAX_LATENCY_MS` (default 30 s) and returns the final output URL.
- `mode: "async"` returns `{ jobId, status: "processing" }` immediately — client polls via `GET`.
- `image` may also be an `https://` URL (e.g. a signed Supabase storage URL).

Response (success):

```json
{
  "jobId": "…",
  "status": "succeeded",
  "outputUrl": "https://…selfies/<user>/<job>/output.jpg?token=…",
  "latencyMs": 3821
}
```

`outputUrl` is a 24h signed URL to the bucket `selfies`. Display it directly
in an `Image.network(...)` widget, or download and cache it for sharing.

### `GET /functions/v1/selfie-transform?jobId=<id>`

Returns the current state of a job. Used by the client when `mode=async` or
when the sync mode times out with `status: "processing"`.

## Error handling

| Case                           | Client behavior                                          |
| ------------------------------ | -------------------------------------------------------- |
| Unknown `promptKey`            | Shows generic "couldn't generate" toast (shouldn't happen — client enforces enum) |
| `Replicate error` / 502        | `stubOnFailure=true` → returns original photo with `usedFallback: true` |
| Sync timeout (server)          | Client auto-polls via `waitForJob`                       |
| Auth expired                   | Client refreshes session and retries once                |

`ReplicateSelfiePipelineService` defaults to `stubOnFailure: true` so the
gameplay continues even if the AI service is degraded. Set `false` in flows
where a failure should surface an error UI instead of a pass-through image.

## Storage layout

Bucket: `selfies` (private)

```
selfies/
  <user-uuid>/
    <job-uuid>/
      input.jpg         # original capture
      output.jpg        # generated image
```

RLS: users can read and upload files only under their own user folder. The
edge function uses the service-role key to read/write across folders.

## Audit trail

Every job writes a row to `public.ai_selfies` with:

- `prompt_key`, `prompt_text`, `model`, `provider_job_id`
- `input_path`, `output_url`
- `status`, `error_message`, `latency_ms`
- `session_id`, `round_id` (nullable)

Use this table to power post-game replays, user history, and abuse
investigations.

## Model selection

Default model: **Flux Kontext Pro** (`black-forest-labs/flux-kontext-pro`).

Why:
- Identity-preserving text-guided image editing — subject stays recognizable.
- 2–6 s per image on A100 (acceptable under a "processing" screen).
- Prompt-only — no need for inpainting masks per scenario.
- ~$0.04/image at current Replicate pricing.

Alternatives and when to use them:
- **SDXL + IP-Adapter** for stylized modes that don't need identity lock
  (slower, 10–14 s, needs masks for face edits).
- **InstantID** as a cartoon/anime fallback.
- **Modal custom endpoint** when DAU > 20 k and Replicate unit economics
  no longer pencil out.

To swap the default, set `SELFIE_MODEL_VERSION` or edit
`supabase/functions/selfie-transform/index.ts`.

## Latency targets

| P50   | P95   | Hard timeout |
| ----- | ----- | ------------ |
| ~4 s  | ~9 s  | 30 s (sync)  |

If p95 regresses above 12 s for a week, fall back to async mode in the
client and show an in-flight progress UI instead of a blocking spinner.

## Secrets

Set via `supabase secrets set`:

- `REPLICATE_API_TOKEN` (required)
- `SELFIE_MODEL_VERSION` (optional)
- `SELFIE_MAX_LATENCY_MS` (optional)

These are consumed by the edge function at invocation time — never
shipped to the client.

## Related tickets

- [GUSAA-10](/GUSAA/issues/GUSAA-10) — camera capture, permissions, Capture the Moment UI
- [GUSAA-11](/GUSAA/issues/GUSAA-11) — this pipeline (AI Capture the Moment)
- [GUSAA-12](/GUSAA/issues/GUSAA-12) — end-to-end in-game integration
