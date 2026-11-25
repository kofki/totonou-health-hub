// Totonou: the cloud model, for phones without Apple Intelligence.
//
// The app sends one of two requests and gets JSON back:
//   { "kind": "coach", "facts": "...", "question": "..." }  ->  { "text": "..." }
//   { "kind": "plan", "title": "...", "manifesto": "..." }  ->  { "goals": [...], "quests": [...] }
//
// The Anthropic API key lives here as a secret and never ships in the app:
//   supabase secrets set ANTHROPIC_API_KEY=...
//
// Deploy with JWT checking off at the gateway, because the function checks the
// caller itself (below), which also works with the project's newer signing keys:
//   supabase functions deploy ai --no-verify-jwt

import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

// One line to change if the answers are not good enough: "claude-sonnet-5-5"
// or "claude-opus-5-5" are smarter and cost more per call.
const MODEL = "claude-haiku-5-5";

// The publishable key is public and sign-in is anonymous, so anyone could call
// this. These caps bound what a stranger can spend (supabase/migrations/…_ai_usage.sql).
const USER_CALLS_PER_DAY = 40;
const ALL_CALLS_PER_DAY = 400;
const EVERYONE = "00000000-0000-0000-0000-000000000000";

const COACH_SYSTEM = `You are a blunt coach in a habit app. Reply in one or two sentences, under 30 words. \
No greeting, no praise, no preamble. Start with the one thing to do today, then the reason. \
Use only the facts you are given: never invent numbers, events, foods, injuries or plans. \
If the facts cannot answer the question, say which data is missing. No emojis, no lists, no markdown.`;

const PLAN_SYSTEM = `You are the planner inside a habit app that works like a game. The user describes a \
chapter of their life. Turn it into three levels:
1. One to three outcomes, each under nine words with a number in it ("Squat 100 kg").
2. Two to four objectives: counts to hit per day or per week that lead there ("Strength sessions", 4 per week).
3. Four to seven specific quests. Each counts toward one objective (copy its title exactly) and runs on \
the weekdays it happens (1 is Monday, 7 is Sunday): a weekly count of 4 needs quests on 4 weekdays.
Never write vague quests like "Deep work" or "Exercise": say what exactly, how long, how hard, for \
example "Strength session: lower body". Each quest has the hour to do it (6 to 22) and its minutes \
(5 to 120). Plain English. No emojis.`;

const PLAN_SCHEMA = {
  type: "object",
  properties: {
    goals: { type: "array", items: { type: "string" } },
    objectives: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title: { type: "string" },
          period: { type: "string", enum: ["day", "week"] },
          target: { type: "integer" },
        },
        required: ["title", "period", "target"],
        additionalProperties: false,
      },
    },
    quests: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title: { type: "string" },
          stat: { type: "string", enum: ["strength", "endurance", "intellect", "discipline", "recovery"] },
          hour: { type: "integer" },
          minutes: { type: "integer" },
          objective: { type: "string" },
          weekdays: { type: "array", items: { type: "integer" } },
        },
        required: ["title", "stat", "hour", "minutes", "objective", "weekdays"],
        additionalProperties: false,
      },
    },
  },
  required: ["goals", "objectives", "quests"],
  additionalProperties: false,
};

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

/** A trimmed string no longer than `max`, or null when it is missing or empty. */
function text(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 && trimmed.length <= max ? trimmed : null;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return reply(405, { error: "POST only" });

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return reply(503, { error: "ANTHROPIC_API_KEY is not set on this project" });

  // Who is calling? The app sends the signed-in user's token; no user, no answer.
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const token = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const { data: who, error: authError } = await admin.auth.getUser(token);
  if (authError || !who.user) return reply(401, { error: "Sign in first" });

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return reply(400, { error: "Body must be JSON" });
  }

  // Check the request before it counts against the daily cap.
  let system: string;
  let prompt: string;
  const isPlan = body.kind === "plan";
  if (isPlan) {
    const title = text(body.title, 120);
    const manifesto = text(body.manifesto, 2000);
    if (!title || !manifesto) return reply(400, { error: "plan needs a title and a manifesto" });
    system = PLAN_SYSTEM;
    prompt = `Chapter name: ${title}\nIn their words: ${manifesto}`;
  } else if (body.kind === "coach") {
    const facts = text(body.facts, 4000);
    if (!facts) return reply(400, { error: "coach needs facts" });
    const question = text(body.question, 300);
    system = COACH_SYSTEM;
    prompt = `Facts (the only things you know):\n${facts}\n\n` +
      (question ? `The user asks: ${question}` : "What should they do today?");
  } else {
    return reply(400, { error: 'kind must be "coach" or "plan"' });
  }

  for (const [id, cap] of [[who.user.id, USER_CALLS_PER_DAY], [EVERYONE, ALL_CALLS_PER_DAY]] as const) {
    const { data: calls, error } = await admin.rpc("bump_ai_usage", { p_user: id });
    if (error) return reply(500, { error: "Could not count this call" });
    if (calls > cap) return reply(429, { error: "Daily limit reached. Try again tomorrow." });
  }

  const client = new Anthropic({ apiKey });
  try {
    const message = await client.messages.create({
      model: MODEL,
      // Thinking counts toward this, so it is well above the length of the answer.
      max_tokens: isPlan ? 2048 : 1024,
      system,
      messages: [{ role: "user", content: prompt }],
      output_config: {
        effort: "low",
        ...(isPlan ? { format: { type: "json_schema", schema: PLAN_SCHEMA } } : {}),
      },
    });

    if (message.stop_reason === "refusal") return reply(422, { error: "The model declined this request" });
    // The answer is the text block; a thinking block may come before it.
    const answer = message.content.find((block) => block.type === "text");
    if (!answer || answer.type !== "text" || message.stop_reason === "max_tokens") {
      return reply(502, { error: "The model did not finish its answer" });
    }
    return isPlan ? reply(200, JSON.parse(answer.text)) : reply(200, { text: answer.text.trim() });
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) return reply(429, { error: "Busy. Try again in a minute." });
    if (error instanceof Anthropic.AuthenticationError) return reply(503, { error: "The API key was rejected" });
    if (error instanceof Anthropic.APIError) {
      console.error("Anthropic error", error.status, error.message);
      return reply(502, { error: "The model is unavailable" });
    }
    console.error(error);
    return reply(500, { error: "Something went wrong" });
  }
});
