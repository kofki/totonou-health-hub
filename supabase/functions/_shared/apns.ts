// Sends Apple push notifications to a user's phones.
//
// Needs four secrets, from an APNs key made in the Apple developer account
// (Certificates, Identifiers & Profiles → Keys → +, tick Apple Push
// Notifications service):
//   APNS_KEY        the contents of the .p8 file
//   APNS_KEY_ID     the key's 10-character id
//   APNS_TEAM_ID    the team id (Alarex LLC: U4YL483XHM)
//   APNS_BUNDLE_ID  dev.kenzo.totonou
// Without them nothing is sent and nothing fails: push is optional.

import { importPKCS8, SignJWT } from "npm:jose@5";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

let cached: { jwt: string; at: number } | null = null;

/** Apple accepts a signed token for up to an hour; reuse one for 50 minutes. */
async function providerToken(): Promise<string | null> {
  const key = Deno.env.get("APNS_KEY");
  const keyID = Deno.env.get("APNS_KEY_ID");
  const teamID = Deno.env.get("APNS_TEAM_ID");
  if (!key || !keyID || !teamID) return null;
  if (cached && Date.now() - cached.at < 50 * 60 * 1000) return cached.jwt;
  const signingKey = await importPKCS8(key.replace(/\\n/g, "\n"), "ES256");
  const jwt = await new SignJWT({}).setProtectedHeader({ alg: "ES256", kid: keyID })
    .setIssuer(teamID).setIssuedAt().sign(signingKey);
  cached = { jwt, at: Date.now() };
  return jwt;
}

/** Sends one alert to every phone the user registered. Never throws. */
export async function notify(db: SupabaseClient, userID: string, title: string, body: string): Promise<void> {
  try {
    const topic = Deno.env.get("APNS_BUNDLE_ID");
    const jwt = await providerToken();
    if (!jwt || !topic) return;
    const { data: devices } = await db.from("push_devices").select("token, environment").eq("user_id", userID);
    for (const device of devices ?? []) {
      const host = device.environment === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
      const response = await fetch(`https://${host}/3/device/${device.token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": topic,
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        body: JSON.stringify({ aps: { alert: { title, body: body.slice(0, 180) }, sound: "default" } }),
      });
      // 410: the app was removed or notifications turned off. Forget the token.
      if (response.status === 410) await db.from("push_devices").delete().eq("token", device.token);
      else if (!response.ok) console.error("APNs", response.status, await response.text());
    }
  } catch (error) {
    console.error("push failed", error);
  }
}
