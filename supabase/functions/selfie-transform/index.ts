// Supabase Edge Function: selfie-transform
//
// Accepts a user-captured selfie plus a game prompt key, runs it through
// Replicate's image-to-image diffusion model, stores input + output in the
// 'selfies' bucket, and records a job row in `ai_selfies`.
//
// Request (POST JSON):
//   { "promptKey": "third_eye",
//     "image": "data:image/jpeg;base64,..."  | "<https url>",
//     "sessionId": "uuid" | null,
//     "roundId":   "uuid" | null,
//     "mode": "sync" | "async"      (default "sync")
//   }
//
// Response:
//   sync  -> { jobId, status, outputUrl, latencyMs }
//   async -> { jobId, status: 'processing' }    (client polls GET /:jobId)
//
// Env:
//   REPLICATE_API_TOKEN          required
//   SELFIE_MODEL_VERSION         optional, overrides default model version
//   SELFIE_MAX_LATENCY_MS        optional, sync-mode timeout (default 30000)

// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { getPrompt, PROMPT_KEYS } from './prompts.ts';

// Default: Flux Kontext Pro — identity-preserving text-guided image editing.
// Great fit for "modify the person in this photo" and runs in 2–6s on an A100.
const DEFAULT_MODEL = 'black-forest-labs/flux-kontext-pro';
const DEFAULT_MODEL_VERSION =
  Deno.env.get('SELFIE_MODEL_VERSION') ??
  '0f1178f5a27e9aa2d2d39c8a43c87be0a3bed2053acc6e53cff9244ddfce4b67';
const SYNC_TIMEOUT_MS = Number(
  Deno.env.get('SELFIE_MAX_LATENCY_MS') ?? 30000,
);
const REPLICATE_BASE = 'https://api.replicate.com/v1';

interface TransformRequest {
  promptKey: string;
  image: string;
  sessionId?: string | null;
  roundId?: string | null;
  mode?: 'sync' | 'async';
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function adminClient(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) throw new Error('Supabase env missing');
  return createClient(url, key, { auth: { persistSession: false } });
}

async function resolveUser(
  client: SupabaseClient,
  authHeader: string | null,
): Promise<string> {
  if (!authHeader?.startsWith('Bearer ')) {
    throw new Response('Missing bearer token', { status: 401 });
  }
  const token = authHeader.slice('Bearer '.length);
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) {
    throw new Response('Invalid token', { status: 401 });
  }
  return data.user.id;
}

async function decodeImage(image: string): Promise<{
  bytes: Uint8Array;
  mime: string;
}> {
  if (image.startsWith('data:')) {
    const match = image.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/);
    if (!match) throw new Error('Invalid data URL');
    const mime = match[1];
    const b64 = match[2];
    const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    return { bytes, mime };
  }
  if (image.startsWith('https://')) {
    const res = await fetch(image);
    if (!res.ok) throw new Error(`Failed to fetch image: ${res.status}`);
    const mime = res.headers.get('content-type') ?? 'image/jpeg';
    const bytes = new Uint8Array(await res.arrayBuffer());
    return { bytes, mime };
  }
  throw new Error('Image must be data URL or https URL');
}

function extFor(mime: string): string {
  if (mime === 'image/png') return 'png';
  if (mime === 'image/webp') return 'webp';
  return 'jpg';
}

async function uploadInput(
  client: SupabaseClient,
  userId: string,
  jobId: string,
  bytes: Uint8Array,
  mime: string,
): Promise<string> {
  const path = `${userId}/${jobId}/input.${extFor(mime)}`;
  const { error } = await client.storage
    .from('selfies')
    .upload(path, bytes, { contentType: mime, upsert: true });
  if (error) throw new Error(`Upload failed: ${error.message}`);
  return path;
}

async function signedUrl(
  client: SupabaseClient,
  path: string,
  ttlSeconds = 600,
): Promise<string> {
  const { data, error } = await client.storage
    .from('selfies')
    .createSignedUrl(path, ttlSeconds);
  if (error || !data) throw new Error(`Signed URL failed: ${error?.message}`);
  return data.signedUrl;
}

async function startReplicate(params: {
  prompt: string;
  negativePrompt?: string;
  guidance: number;
  inputImageUrl: string;
}): Promise<{ id: string; status: string; output?: string | string[] }> {
  const token = Deno.env.get('REPLICATE_API_TOKEN');
  if (!token) throw new Error('REPLICATE_API_TOKEN not set');

  const res = await fetch(`${REPLICATE_BASE}/predictions`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      prefer: 'wait=5',
    },
    body: JSON.stringify({
      version: DEFAULT_MODEL_VERSION,
      input: {
        prompt: params.prompt,
        negative_prompt: params.negativePrompt,
        input_image: params.inputImageUrl,
        guidance_scale: params.guidance,
        output_format: 'jpg',
        safety_tolerance: 2,
      },
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Replicate error ${res.status}: ${body}`);
  }
  return await res.json();
}

async function pollReplicate(id: string): Promise<{
  status: string;
  output?: string | string[];
  error?: string;
}> {
  const token = Deno.env.get('REPLICATE_API_TOKEN');
  const res = await fetch(`${REPLICATE_BASE}/predictions/${id}`, {
    headers: { authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error(`Poll failed ${res.status}`);
  return await res.json();
}

async function waitForCompletion(
  id: string,
  timeoutMs: number,
): Promise<{ status: string; output?: string | string[]; error?: string }> {
  const start = Date.now();
  let delay = 600;
  while (Date.now() - start < timeoutMs) {
    const result = await pollReplicate(id);
    if (['succeeded', 'failed', 'canceled'].includes(result.status)) {
      return result;
    }
    await new Promise((r) => setTimeout(r, delay));
    delay = Math.min(delay * 1.4, 3000);
  }
  return { status: 'processing' };
}

async function persistOutput(
  client: SupabaseClient,
  userId: string,
  jobId: string,
  outputUrl: string,
): Promise<string> {
  const res = await fetch(outputUrl);
  if (!res.ok) throw new Error(`Fetch output failed: ${res.status}`);
  const mime = res.headers.get('content-type') ?? 'image/jpeg';
  const bytes = new Uint8Array(await res.arrayBuffer());
  const path = `${userId}/${jobId}/output.${extFor(mime)}`;
  const { error } = await client.storage
    .from('selfies')
    .upload(path, bytes, { contentType: mime, upsert: true });
  if (error) throw new Error(`Upload output failed: ${error.message}`);
  return path;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'access-control-allow-origin': '*',
        'access-control-allow-headers': 'authorization, content-type',
        'access-control-allow-methods': 'POST, GET, OPTIONS',
      },
    });
  }

  try {
    const admin = adminClient();
    const userId = await resolveUser(admin, req.headers.get('authorization'));
    const url = new URL(req.url);

    // GET /jobId — poll status.
    if (req.method === 'GET') {
      const jobId = url.searchParams.get('jobId');
      if (!jobId) return jsonResponse({ error: 'jobId required' }, 400);
      const { data, error } = await admin
        .from('ai_selfies')
        .select('*')
        .eq('id', jobId)
        .eq('user_id', userId)
        .maybeSingle();
      if (error || !data) return jsonResponse({ error: 'not found' }, 404);
      return jsonResponse({
        jobId: data.id,
        status: data.status,
        outputUrl: data.output_url,
        latencyMs: data.latency_ms,
        error: data.error_message,
      });
    }

    if (req.method !== 'POST') {
      return jsonResponse({ error: 'method not allowed' }, 405);
    }

    const body = (await req.json()) as TransformRequest;
    if (!body.promptKey || !body.image) {
      return jsonResponse(
        { error: 'promptKey and image are required' },
        400,
      );
    }
    if (!PROMPT_KEYS.includes(body.promptKey as any)) {
      return jsonResponse(
        { error: `unknown promptKey '${body.promptKey}'`, valid: PROMPT_KEYS },
        400,
      );
    }

    const template = getPrompt(body.promptKey);
    const mode = body.mode ?? 'sync';

    const { bytes, mime } = await decodeImage(body.image);
    const { data: jobInsert, error: insertErr } = await admin
      .from('ai_selfies')
      .insert({
        user_id: userId,
        session_id: body.sessionId ?? null,
        round_id: body.roundId ?? null,
        prompt_key: template.key,
        prompt_text: template.prompt,
        model: DEFAULT_MODEL,
        input_path: 'pending',
        status: 'pending',
      })
      .select('id')
      .single();
    if (insertErr || !jobInsert) {
      return jsonResponse({ error: insertErr?.message ?? 'insert failed' }, 500);
    }
    const jobId = jobInsert.id as string;

    const inputPath = await uploadInput(admin, userId, jobId, bytes, mime);
    const inputUrl = await signedUrl(admin, inputPath);

    await admin
      .from('ai_selfies')
      .update({ input_path: inputPath, status: 'processing' })
      .eq('id', jobId);

    const started = Date.now();
    const prediction = await startReplicate({
      prompt: template.prompt,
      negativePrompt: template.negativePrompt,
      guidance: template.guidance,
      inputImageUrl: inputUrl,
    });

    await admin
      .from('ai_selfies')
      .update({ provider_job_id: prediction.id })
      .eq('id', jobId);

    if (mode === 'async') {
      return jsonResponse({ jobId, status: 'processing' }, 202);
    }

    const result = await waitForCompletion(prediction.id, SYNC_TIMEOUT_MS);
    const latencyMs = Date.now() - started;

    if (result.status === 'succeeded') {
      const rawOutput = Array.isArray(result.output)
        ? result.output[0]
        : result.output;
      if (!rawOutput) throw new Error('Replicate returned no output');
      const outputPath = await persistOutput(admin, userId, jobId, rawOutput);
      const finalUrl = await signedUrl(admin, outputPath, 24 * 3600);
      await admin
        .from('ai_selfies')
        .update({
          status: 'succeeded',
          output_url: finalUrl,
          latency_ms: latencyMs,
          completed_at: new Date().toISOString(),
        })
        .eq('id', jobId);
      return jsonResponse({
        jobId,
        status: 'succeeded',
        outputUrl: finalUrl,
        latencyMs,
      });
    }

    if (result.status === 'failed' || result.status === 'canceled') {
      const message = result.error ?? 'generation failed';
      await admin
        .from('ai_selfies')
        .update({
          status: result.status === 'canceled' ? 'cancelled' : 'failed',
          error_message: message,
          latency_ms: latencyMs,
          completed_at: new Date().toISOString(),
        })
        .eq('id', jobId);
      return jsonResponse({ jobId, status: result.status, error: message }, 502);
    }

    // Still processing after timeout — tell client to poll.
    return jsonResponse(
      { jobId, status: 'processing', latencyMs },
      202,
    );
  } catch (err) {
    if (err instanceof Response) return err;
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse({ error: message }, 500);
  }
});
