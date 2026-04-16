# `selfie-transform` edge function

Runs a user-captured selfie through a diffusion model to produce the AI
"Capture the Moment" image for a given game scenario.

## Environment

| Variable                     | Required | Purpose                                   |
| ---------------------------- | -------- | ----------------------------------------- |
| `REPLICATE_API_TOKEN`        | yes      | Replicate API token for inference         |
| `SELFIE_MODEL_VERSION`       | no       | Overrides the default Flux Kontext Pro version |
| `SELFIE_MAX_LATENCY_MS`      | no       | Sync-mode wait ceiling (default 30000 ms) |

Set them with:

```bash
supabase secrets set REPLICATE_API_TOKEN=r8_... SELFIE_MODEL_VERSION=...
```

## Deploy

```bash
supabase functions deploy selfie-transform --no-verify-jwt=false
```

JWT verification is left on — the function reads the caller's identity from
the Authorization header (`Bearer <access_token>`).

## Endpoints

### `POST /functions/v1/selfie-transform`

Kick off a transform.

```json
{
  "promptKey": "third_eye",
  "image": "data:image/jpeg;base64,...",
  "sessionId": "uuid-or-null",
  "roundId":   "uuid-or-null",
  "mode": "sync"
}
```

- `sync` (default) waits up to `SELFIE_MAX_LATENCY_MS` and returns the output URL.
- `async` returns `{ jobId, status: 'processing' }` immediately — poll with GET.

### `GET /functions/v1/selfie-transform?jobId=<id>`

Returns the current job state. `outputUrl` is a 24h signed URL on success.

## Model rationale

Default: **Flux Kontext Pro** (`black-forest-labs/flux-kontext-pro`).

| Criterion           | Why it wins                                     |
| ------------------- | ----------------------------------------------- |
| Identity preservation | Trained for photo editing, keeps the subject recognizable |
| Latency             | 2–6 s per image on A100 — acceptable for a "processing" screen in a mobile game |
| Prompt steerability | Text-only prompts handle all 10 scenarios without masks |
| Cost                | ~$0.04 / image at current Replicate pricing     |

Alternatives evaluated:

- **SDXL + IP-Adapter** — better style range but needs masks for face edits and
  averages 10–14 s. Reserved for future style modes.
- **InstantID** — strong identity lock but stylistic output only (no zombie /
  3rd-eye photorealism). Keep as a fallback for "cartoon" variants.
- **Modal.com custom endpoint** — lower ongoing cost at scale but pushes us to
  manage GPU autoscaling. Re-evaluate once DAU > 20k.

To switch models, change `DEFAULT_MODEL` / `DEFAULT_MODEL_VERSION` in
`index.ts` or set `SELFIE_MODEL_VERSION` to a pinned Replicate version id.

## Prompt templates

See `prompts.ts`. Add a new scenario by extending the `PromptKey` union and
adding an entry to `PROMPT_TEMPLATES`. Keep prompts identity-preserving —
phrase them as *modifications* of the selfie, not regenerations.
