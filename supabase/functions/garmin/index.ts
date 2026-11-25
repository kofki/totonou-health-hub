// Totonou: today's Garmin data, from the Garmin Connect Personal API.
//
// The Personal API is Garmin's way for one person to read their own data: you
// make a key in Garmin Connect (Settings → Personal API token), and it is
// exchanged here for a short-lived bearer token. Pull only: the app asks on
// every sync and this function reads today's summary, sleep and HRV.
// Spec: https://developer.garmin.com/gc-developer-program/personal/swagger-docs/
//
// Secrets (supabase secrets set …):
//   GARMIN_API_KEY         the Personal API key
//   GARMIN_OWNER_USER_ID   the Supabase user id allowed to read it. The key
//                          reads one person's Garmin account, so only that
//                          person's app may call this.
//
// Deploy: supabase functions deploy garmin --no-verify-jwt

import { createClient } from "npm:@supabase/supabase-js@2";

const BASE = "https://personal.connectapi.garmin.com";
const TOKEN_PATH = "/personalapitoken-service/personal-api/personal-api-key/token";

let cached: { token: string; expiresAt: number } | null = null;

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

/** The bearer token's expiry, read from the JWT itself. */
function expiry(jwt: string): number {
  try {
    const payload = JSON.parse(atob(jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    return typeof payload.exp === "number" ? payload.exp * 1000 : Date.now() + 60 * 60 * 1000;
  } catch {
    return Date.now() + 60 * 60 * 1000;
  }
}

/** A cached bearer token, renewed an hour before it expires (as Garmin's own client does). */
async function bearer(key: string): Promise<string> {
  if (cached && cached.expiresAt - Date.now() > 60 * 60 * 1000) return cached.token;
  const response = await fetch(BASE + TOKEN_PATH, {
    method: "POST",
    headers: { Accept: "*/*", Authorization: `ApiKey ${key}` },
  });
  if (!response.ok) throw new Error(`Garmin token ${response.status}`);
  const token = (await response.text()).trim();
  cached = { token, expiresAt: expiry(token) };
  return token;
}

async function get(token: string, path: string): Promise<Record<string, unknown> | null> {
  const response = await fetch(BASE + path, { headers: { Authorization: `Bearer ${token}`, Accept: "application/json" } });
  if (response.status === 204 || response.status === 404) return null;
  if (!response.ok) throw new Error(`Garmin ${path.split("?")[0]} ${response.status}`);
  return await response.json();
}

function num(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return reply(405, { error: "POST only" });
  const key = Deno.env.get("GARMIN_API_KEY");
  const owner = Deno.env.get("GARMIN_OWNER_USER_ID");
  if (!key || !owner) return reply(503, { error: "Garmin is not set up on the server" });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const jwt = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const { data: who } = await admin.auth.getUser(jwt);
  if (!who.user) return reply(401, { error: "Sign in first" });
  if (who.user.id !== owner) return reply(403, { error: "This Garmin account belongs to another user" });

  let date: string;
  try {
    date = String((await request.json()).date ?? "");
  } catch {
    return reply(400, { error: "Body must be JSON" });
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return reply(400, { error: "date must look like 2026-11-25" });

  try {
    const token = await bearer(key);
    const [daily, sleep, hrv] = await Promise.all([
      get(token, `/usersummary-service/usersummary/daily?calendarDate=${date}`),
      get(token, `/sleep-service/sleep/dailySleep?date=${date}`),
      get(token, `/hrv-service/hrv/${date}`),
    ]);
    const hrvSummary = (hrv?.hrvSummary ?? {}) as Record<string, unknown>;
    const scores = (sleep?.sleepScores ?? {}) as Record<string, { value?: number }>;
    const sleepSeconds = num(sleep?.sleepTimeSeconds);
    // Only what Garmin reported: a missing value stays missing, never 0.
    const readings = {
      steps: num(daily?.totalSteps),
      activeCalories: num(daily?.activeKilocalories),
      restingHeartRate: num(daily?.restingHeartRate),
      bodyBattery: num(daily?.bodyBatteryMostRecentValue),
      stress: num(daily?.averageStressLevel),
      sleepHours: sleepSeconds === undefined ? undefined : Math.round(sleepSeconds / 360) / 10,
      // The overall score's key is not in Garmin's public spec; "overall" is what it returns.
      sleepScore: num(scores.overall?.value),
      hrv: num(hrvSummary.lastNightAvg),
    };
    return reply(200, { date, readings, hrvStatus: hrvSummary.status ?? null });
  } catch (error) {
    console.error(error);
    return reply(502, { error: "Garmin did not answer" });
  }
});
