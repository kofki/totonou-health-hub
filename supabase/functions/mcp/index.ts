// Totonou: the MCP server. It lets Claude (the phone app, claude.ai, or Claude
// Code) act as the coach and planner using your Claude subscription, with no
// API key and no per-call cost.
//
// MCP (Model Context Protocol) is JSON-RPC over HTTP: Claude POSTs a message
// such as {"method": "tools/call", ...} and gets a JSON answer. This server is
// stateless: every request stands alone, which suits an Edge Function.
//
// Who is calling is decided by a personal token the app creates ("Connect
// Claude"). It arrives as `Authorization: Bearer <token>` (Claude Code) or as
// `?token=<token>` on the URL (claude.ai connectors cannot send headers).
// Only the token's SHA-256 hash is stored (supabase/migrations/…_claude_mcp.sql).
//
// The phone stays the source of truth. Claude reads one snapshot the app
// uploads, and writes rows to `claude_changes`; the app applies them next time
// it opens.
//
// Deploy: supabase functions deploy mcp --no-verify-jwt

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { notify } from "../_shared/apns.ts";

type Json = Record<string, unknown>;

const PROTOCOL_VERSIONS = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"];
const MAX_PENDING = 200;

const STATS = ["strength", "endurance", "intellect", "discipline", "recovery"];
const RANKS = ["E", "D", "C", "B", "A", "S"];
const SIGNALS = ["steps", "sleepHours", "runKm", "focusMinutes", "activeCalories"];
const ARC_KINDS = ["seasonal", "objective"];
const PERIODS = ["day", "week", "arc"];

const INSTRUCTIONS = `Totonou is the user's personal quest game on their iPhone. Life is split into arcs \
(chapters) that run side by side: seasonal arcs with dates (Winter Arc, Summer Arc) and objective arcs \
with no end date, for one change or a life area (Healthy body, Professional, Founder, Social media). \
Finishing quests earns XP and raises five stats: strength, endurance, intellect, discipline, recovery. \
You are the coach and the planner.

Each arc has three levels, and the point is that the user can see progress on every one:
1. Outcomes: one to four results in words, with a number ("Squat 100 kg", "10 paying customers").
2. Objectives: counts to hit every day, every week, or once over the arc ("Strength sessions, 4 a \
week", "Protein meals, 3 a day", "Posts published, 12 in total"). The app shows "2 of 4 this week".
3. Quests: specific steps. Each one that counts toward an objective names it, and finishing it adds \
one to that objective's count. A weekly objective of 4 needs quests on 4 weekdays, not every day.

Always call get_overview first. It returns the measured facts: stats, streak, every arc with its \
outcomes, objectives and their counts so far, its daily plan, recent quests with what was done and \
missed and at what time of day, and Apple Health readings. Use only those facts; never invent numbers.

Writing good quests and objectives:
- Specific and checkable, never generic. "Train 4 days a week" or "Deep work" are wishes. "Strength \
session: lower body, 45 min" on Mon and Thu counting toward "Strength sessions, 4 a week" is a plan.
- Every objective has a count and a period; every quest that moves one names it in "objective".
- Schedule at times of day the history shows the user actually finishes things. Do not stack quests \
on top of existing ones.
- Size honestly: rank E is trivial (5-10 min), D easy, C a real session (30-45 min), B hard (60+ min), \
A and S rare and demanding. A normal day holds 4 to 7 quests across all arcs together, not per arc.
- When Apple Health can prove it, set autoComplete (steps, sleepHours, runKm, focusMinutes, \
activeCalories) with a target, so the quest finishes itself.
- healthToday may also hold restingHeartRate, hrv, vo2Max, and from Garmin bodyBattery, stress and \
sleepScore. Use them to judge recovery: a low Body Battery or HRV means an easier day, not a harder one.
- healthToday.screenMinutes is today's use of the apps the user chose to lock (social media and the \
like), in 15-minute steps, so "at least" that many minutes. screenTimeHistory holds earlier days. Look \
for patterns (which weekdays run high, whether it rises after missed quests or poor sleep) and plan \
around them, for example a phone-free quest at the hour usage usually climbs.
- mustDo is for the one or two quests a day that matter most; missing one has a penalty in the game.
- add_daily_quest for repeating steps (with weekdays), add_quests for one-off days, add_objective to \
give an existing arc a new count.
- A quest can have a checklist of steps (sub-quests), like the exercises of a workout. Give new \
quests "steps" in add_quests, add_daily_quest or create_arc; give an existing quest or daily quest \
steps with set_steps. One more step on one day: add_quests with partOf set to the quest's title. \
Each step has its own reward, and the quest unlocks only when every step is done. Steps keep \
Today's list short: the user sees one quest with its steps under it. A daily plan entry lists its \
steps under "steps". In get_overview a quest with steps lists them under \
"steps", with "stepsDone" and "lockedUntilStepsDone"; each step also appears in quests with "partOf". \
To remove a step, use remove_quest with its title and its quest's date and time.

Arcs can share quests. When a new arc overlaps what the user already does (a Winter Arc next to \
Healthy body and Founder), do not copy those quests: give the new arc's objectives "sharedQuests" \
(or use share_quest) so the existing quests count for it too, and add only what is new on top. \
In get_overview an objective lists "sharedQuests", and a quest or plan entry that counts elsewhere \
lists "alsoCountsFor".

Ask the user what they want before creating an arc, and tell them what you added afterwards. Changes \
reach the phone the next time the Totonou app is opened; until then get_overview lists them as pending.`;

// ── Tool definitions ────────────────────────────────────────────────────────

const questProperties = {
  title: { type: "string", description: "A specific action under eight words, e.g. 'Run 5 km easy'." },
  why: { type: "string", description: "One short sentence: which arc objective this moves." },
  stat: { type: "string", enum: STATS, description: "The stat it trains." },
  rank: { type: "string", enum: RANKS, description: "Difficulty. E trivial, C a real session, B hard, A and S rare." },
  time: { type: "string", description: "Local start time, 24-hour HH:MM, between 05:00 and 23:30." },
  minutes: { type: "integer", description: "How long it takes, 5 to 240." },
  mustDo: { type: "boolean", description: "True for a critical quest: missing it has a penalty. Use sparingly." },
  objective: {
    type: "string",
    description: "Exact title of the arc objective this quest counts toward, from get_overview or the same create_arc call.",
  },
  autoComplete: {
    type: "object",
    description: "Lets Apple Health finish the quest. Omit for quests the user ticks off by hand.",
    properties: {
      signal: { type: "string", enum: SIGNALS },
      target: { type: "number", description: "Value to reach today: steps, hours of sleep, km run, focus minutes, or active kcal." },
    },
    required: ["signal", "target"],
  },
  steps: {
    type: "array",
    description: "Optional checklist, 1 to 8 steps in order (e.g. each exercise of a workout). Each step pays its " +
      "own reward and the quest unlocks once all are done. On a daily quest, every day's copy gets them.",
    items: {
      type: "object",
      properties: {
        title: { type: "string", description: "A specific action under eight words, e.g. 'Bench press 4 x 6'." },
        minutes: { type: "integer", description: "How long it takes, 1 to 120. Default 10." },
        rank: { type: "string", enum: RANKS, description: "Difficulty. Usually E or D. Default E." },
      },
      required: ["title"],
    },
  },
};
const questRequired = ["title", "stat", "rank", "time", "minutes"];

const weekdaysProperty = {
  type: "array",
  items: { type: "integer" },
  description: "Weekdays it repeats, 1 = Monday ... 7 = Sunday. Omit for every day.",
};

const objectiveProperties = {
  title: { type: "string", description: "What is counted, under six words, e.g. 'Strength sessions'." },
  period: { type: "string", enum: PERIODS, description: "day or week: the count starts again each period. arc: once in total." },
  count: { type: "integer", description: "How many per period, 1 to 50." },
  detail: { type: "string", description: "What counts as one, e.g. '45 min, compound lifts, log the weights'." },
  sharedQuests: {
    type: "array",
    items: { type: "string" },
    description: "Exact titles of quests in OTHER arcs that also count toward this objective, so a new arc builds " +
      "on what the user already does instead of copying it. Finishing one counts here too (XP is paid once).",
  },
};

const TOOLS = [
  {
    name: "get_overview",
    title: "Read the game",
    description: "Everything measured about the user's game: stats, streak, all arcs with objectives and " +
      "progress, recent and upcoming quests, the coach's facts, and changes you made that the phone has not " +
      "applied yet. Call this before anything else.",
    inputSchema: { type: "object", properties: {} },
    annotations: { readOnlyHint: true },
  },
  {
    name: "add_quests",
    title: "Add quests to a day",
    description: "Add one-off quests on specific days. They appear in Today on the phone.",
    inputSchema: {
      type: "object",
      properties: {
        quests: {
          type: "array",
          items: {
            type: "object",
            properties: {
              ...questProperties,
              date: { type: "string", description: "Local date, YYYY-MM-DD. Today or later." },
              partOf: {
                type: "string",
                description: "Make this a step of another quest that day: its exact title. Steps pay their own " +
                  "reward, and that quest can only be finished once all its steps are done. time is then ignored.",
              },
              arc: { type: "string", description: "Exact title of the arc it belongs to, from get_overview." },
            },
            required: [...questRequired, "date"],
          },
        },
      },
      required: ["quests"],
    },
  },
  {
    name: "add_daily_quest",
    title: "Add a daily quest to an arc",
    description: "Add a quest that repeats every day while an arc is active.",
    inputSchema: {
      type: "object",
      properties: {
        ...questProperties,
        weekdays: weekdaysProperty,
        arc: { type: "string", description: "Exact title of the arc." },
      },
      required: [...questRequired, "arc"],
    },
  },
  {
    name: "remove_quest",
    title: "Remove a quest",
    description: "Remove one open quest. Finished and failed quests cannot be removed.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Exact title, from get_overview." },
        date: { type: "string", description: "Local date, YYYY-MM-DD." },
        time: { type: "string", description: "Local start time, HH:MM." },
      },
      required: ["title", "date", "time"],
    },
  },
  {
    name: "create_arc",
    title: "Start an arc",
    description: "Start a new arc alongside the existing ones. Ask the user about it first.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Short name, e.g. 'Winter Arc' or 'Founder'." },
        kind: {
          type: "string",
          enum: ARC_KINDS,
          description: "seasonal: runs between two dates (Winter Arc). objective: no end date, for one change or " +
            "a life area (Healthy body, Founder); it ends when the user closes it.",
        },
        manifesto: { type: "string", description: "In the user's words: who they are by the end, what changes." },
        goals: {
          type: "array",
          items: { type: "string" },
          description: "One to four outcomes in words, each with a number, e.g. 'Squat 100 kg'.",
        },
        objectives: {
          type: "array",
          description: "One to five counts to hit per day, per week, or over the arc.",
          items: { type: "object", properties: objectiveProperties, required: ["title", "period", "count"] },
        },
        startDate: { type: "string", description: "YYYY-MM-DD. Defaults to today." },
        endDate: { type: "string", description: "YYYY-MM-DD. Required for seasonal arcs." },
        dailyQuests: {
          type: "array",
          description: "Zero to eight repeating quests. Name the objective each counts toward and its weekdays.",
          items: { type: "object", properties: { ...questProperties, weekdays: weekdaysProperty }, required: questRequired },
        },
      },
      required: ["title", "kind", "manifesto", "goals", "objectives"],
    },
  },
  {
    name: "set_steps",
    title: "Give a quest a checklist",
    description: "Set the steps (sub-quests) of a quest that already exists: a daily quest in an arc's plan, so " +
      "every future day gets them, and the open copies from today on. With date, only that day's quest.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Exact title of the quest or daily quest, from get_overview." },
        arc: { type: "string", description: "Exact title of its arc. Omit to match the quest in any running arc." },
        date: { type: "string", description: "YYYY-MM-DD. Only that day's quest; the plan is still updated." },
        steps: questProperties.steps,
      },
      required: ["title", "steps"],
    },
  },
  {
    name: "share_quest",
    title: "Let a quest count for another arc",
    description: "Make a quest (or daily quest) from one arc also count toward an objective of another arc, or " +
      "stop it with remove. The quest stays in its own arc and shows on Today once.",
    inputSchema: {
      type: "object",
      properties: {
        quest: { type: "string", description: "Exact title of the quest or daily quest, from get_overview." },
        arc: { type: "string", description: "Exact title of the arc whose objective it should also count toward." },
        objective: { type: "string", description: "Exact title of that arc's objective." },
        remove: { type: "boolean", description: "True to stop it counting there." },
      },
      required: ["quest", "arc", "objective"],
    },
  },
  {
    name: "add_objective",
    title: "Add an objective to an arc",
    description: "Give a running arc a new count to hit per day, per week, or in total. Then link quests to it.",
    inputSchema: {
      type: "object",
      properties: { ...objectiveProperties, arc: { type: "string", description: "Exact title of the arc." } },
      required: ["arc", "title", "period", "count"],
    },
  },
  {
    name: "end_arc",
    title: "End an arc",
    description: "End an active arc today. Its future quests stop; its history stays. Confirm with the user first.",
    inputSchema: {
      type: "object",
      properties: { arc: { type: "string", description: "Exact title of the arc." } },
      required: ["arc"],
    },
    annotations: { destructiveHint: true },
  },
  {
    name: "get_coach_questions",
    title: "Read questions from the Coach tab",
    description: "Questions the user typed on the Coach tab that have no answer yet, oldest first, with the last " +
      "few answered ones for context. Answer each with answer_coach_question.",
    inputSchema: { type: "object", properties: {} },
    annotations: { readOnlyHint: true },
  },
  {
    name: "answer_coach_question",
    title: "Answer a Coach tab question",
    description: "Write the answer the user sees on the Coach tab. Two to five sentences, plain text, no markdown, " +
      "grounded in get_overview. Start with the one thing to do.",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string", description: "The question id from get_coach_questions." },
        answer: { type: "string" },
      },
      required: ["id", "answer"],
    },
  },
  {
    name: "set_coach_message",
    title: "Write the coach's advice",
    description: "Set the advice shown at the top of the Coach tab: one or two sentences, under 40 words, " +
      "starting with the one thing to do today, grounded in facts from get_overview.",
    inputSchema: {
      type: "object",
      properties: { text: { type: "string" } },
      required: ["text"],
    },
  },
];

// ── Checking what Claude sends ──────────────────────────────────────────────
// The schemas above are advice to the model; these checks are the rule. Each
// returns the cleaned value, or throws a message Claude can read and fix.

class Invalid extends Error {}

function str(value: unknown, name: string, max: number): string {
  if (typeof value !== "string" || value.trim().length === 0) throw new Invalid(`${name} is required`);
  const trimmed = value.trim();
  if (trimmed.length > max) throw new Invalid(`${name} must be at most ${max} characters`);
  return trimmed;
}

function oneOf(value: unknown, name: string, allowed: string[]): string {
  if (typeof value !== "string" || !allowed.includes(value)) {
    throw new Invalid(`${name} must be one of: ${allowed.join(", ")}`);
  }
  return value;
}

function date(value: unknown, name: string): string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value) || isNaN(Date.parse(value))) {
    throw new Invalid(`${name} must be a date like 2026-12-01`);
  }
  return value;
}

function time(value: unknown, name: string): string {
  const match = typeof value === "string" ? /^(\d{2}):(\d{2})$/.exec(value) : null;
  const hour = match ? Number(match[1]) : -1;
  if (!match || hour < 5 || hour > 23 || Number(match[2]) > 59) {
    throw new Invalid(`${name} must be a time like 07:30, between 05:00 and 23:59`);
  }
  return value as string;
}

/** The fields every quest has, wherever it is going. */
function quest(input: unknown): Json {
  if (typeof input !== "object" || input === null) throw new Invalid("each quest must be an object");
  const raw = input as Json;
  const minutes = raw.minutes;
  if (typeof minutes !== "number" || !Number.isInteger(minutes) || minutes < 5 || minutes > 240) {
    throw new Invalid("minutes must be a whole number from 5 to 240");
  }
  const cleaned: Json = {
    title: str(raw.title, "title", 80),
    stat: oneOf(raw.stat, "stat", STATS),
    rank: oneOf(raw.rank, "rank", RANKS),
    time: time(raw.time, "time"),
    minutes,
    mustDo: raw.mustDo === true,
  };
  if (raw.why !== undefined) cleaned.why = str(raw.why, "why", 200);
  if (raw.objective !== undefined) cleaned.objective = str(raw.objective, "objective", 80);
  if (raw.steps !== undefined) cleaned.steps = steps(raw.steps);
  if (raw.autoComplete !== undefined) {
    const auto = raw.autoComplete as Json;
    if (typeof auto !== "object" || auto === null) throw new Invalid("autoComplete must be an object");
    if (typeof auto.target !== "number" || !(auto.target > 0)) throw new Invalid("autoComplete.target must be above 0");
    cleaned.signal = oneOf(auto.signal, "autoComplete.signal", SIGNALS);
    cleaned.target = auto.target;
  }
  return cleaned;
}

/** A repeating quest: a quest plus the weekdays it runs. */
function dailyQuest(input: unknown): Json {
  const cleaned = quest(input);
  const days = (input as Json).weekdays;
  if (days !== undefined) {
    if (!Array.isArray(days) || days.length === 0 || days.some((d) => !Number.isInteger(d) || d < 1 || d > 7)) {
      throw new Invalid("weekdays must be a list of numbers from 1 (Monday) to 7 (Sunday)");
    }
    cleaned.weekdays = [...new Set(days as number[])].sort();
  }
  return cleaned;
}

/** A checklist: titles with minutes and rank. */
function steps(value: unknown): Json[] {
  return list(value, "steps", 1, 8).map((input) => {
    if (typeof input !== "object" || input === null) throw new Invalid("each step must be an object");
    const raw = input as Json;
    const minutes = raw.minutes ?? 10;
    if (typeof minutes !== "number" || !Number.isInteger(minutes) || minutes < 1 || minutes > 120) {
      throw new Invalid("step minutes must be a whole number from 1 to 120");
    }
    return {
      title: str(raw.title, "step title", 80),
      minutes,
      rank: raw.rank === undefined ? "E" : oneOf(raw.rank, "step rank", RANKS),
    };
  });
}

function objective(input: unknown): Json {
  if (typeof input !== "object" || input === null) throw new Invalid("each objective must be an object");
  const raw = input as Json;
  const count = raw.count;
  if (typeof count !== "number" || !Number.isInteger(count) || count < 1 || count > 50) {
    throw new Invalid("count must be a whole number from 1 to 50");
  }
  const cleaned: Json = { title: str(raw.title, "title", 80), period: oneOf(raw.period, "period", PERIODS), count };
  if (raw.detail !== undefined) cleaned.detail = str(raw.detail, "detail", 200);
  if (raw.sharedQuests !== undefined) {
    cleaned.sharedQuests = list(raw.sharedQuests, "sharedQuests", 0, 10).map((t) => str(t, "shared quest title", 80));
  }
  return cleaned;
}

function list(value: unknown, name: string, min: number, max: number): unknown[] {
  if (!Array.isArray(value) || value.length < min || value.length > max) {
    throw new Invalid(`${name} must be a list of ${min} to ${max} items`);
  }
  return value;
}

// ── The tools themselves ────────────────────────────────────────────────────

type Change = { kind: string; payload: Json };

/** What the phone shows for a batch of changes: "Update" and what it was about. */
function pushText(changes: Change[]): [string, string] {
  if (changes.length === 1 && changes[0].kind === "coach_message") {
    return ["Coach", String(changes[0].payload.text)];
  }
  // The arc when there is one, else the item itself; each named once.
  const subjects = [...new Set(changes.filter((c) => c.kind !== "coach_message")
    .map((c) => String(c.payload.arc ?? c.payload.title ?? "")).filter(Boolean))];
  if (subjects.length === 0) return ["Update", "There has been an update to your plan."];
  const named = subjects.length <= 2 ? subjects.join(" and ")
    : `${subjects.slice(0, 2).join(", ")} and ${subjects.length - 2} more`;
  return ["Update", `There has been an update for ${named}.`];
}

async function queue(db: SupabaseClient, userID: string, changes: Change[]): Promise<string> {
  const { count } = await db.from("claude_changes")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userID).is("applied_at", null);
  if ((count ?? 0) + changes.length > MAX_PENDING) {
    throw new Invalid(`Too many changes are waiting (${count}). Ask the user to open Totonou so they apply.`);
  }
  const { error } = await db.from("claude_changes")
    .insert(changes.map((change) => ({ user_id: userID, ...change })));
  if (error) throw new Error(error.message);
  const noun = changes.length === 1 ? "change" : "changes";
  await notify(db, userID, ...pushText(changes));
  return `Saved ${changes.length} ${noun}. They apply the next time the Totonou app is opened.`;
}

async function call(db: SupabaseClient, userID: string, name: string, args: Json): Promise<string> {
  switch (name) {
    case "get_overview": {
      const [snapshot, pending] = await Promise.all([
        db.from("claude_snapshots").select("data, updated_at").eq("user_id", userID).maybeSingle(),
        db.from("claude_changes").select("kind, payload, created_at")
          .eq("user_id", userID).is("applied_at", null).order("created_at"),
      ]);
      if (snapshot.error || pending.error) throw new Error("Could not read the game");
      if (!snapshot.data) {
        return JSON.stringify({
          game: null,
          note: "The phone has not uploaded anything yet. Ask the user to open Totonou once, then try again.",
          pendingChanges: pending.data,
        });
      }
      return JSON.stringify({
        game: snapshot.data.data,
        uploadedAt: snapshot.data.updated_at,
        pendingChanges: pending.data,
      });
    }
    case "add_quests": {
      const changes = list(args.quests, "quests", 1, 30).map((item) => {
        const payload = quest(item);
        payload.date = date((item as Json).date, "date");
        if ((item as Json).arc !== undefined) payload.arc = str((item as Json).arc, "arc", 80);
        if ((item as Json).partOf !== undefined) payload.partOf = str((item as Json).partOf, "partOf", 80);
        return { kind: "add_quest", payload };
      });
      return await queue(db, userID, changes);
    }
    case "add_daily_quest": {
      const payload = dailyQuest(args);
      payload.arc = str(args.arc, "arc", 80);
      return await queue(db, userID, [{ kind: "add_daily_quest", payload }]);
    }
    case "add_objective": {
      const payload = objective(args);
      payload.arc = str(args.arc, "arc", 80);
      return await queue(db, userID, [{ kind: "add_objective", payload }]);
    }
    case "remove_quest": {
      const payload = {
        title: str(args.title, "title", 80),
        date: date(args.date, "date"),
        time: time(args.time, "time"),
      };
      return await queue(db, userID, [{ kind: "remove_quest", payload }]);
    }
    case "create_arc": {
      const kind = oneOf(args.kind, "kind", ARC_KINDS);
      const payload: Json = {
        title: str(args.title, "title", 80),
        kind,
        manifesto: str(args.manifesto, "manifesto", 2000),
        goals: list(args.goals, "goals", 1, 4).map((item) => str(item, "goal", 120)),
        objectives: list(args.objectives, "objectives", 1, 5).map(objective),
        dailyQuests: args.dailyQuests === undefined ? [] : list(args.dailyQuests, "dailyQuests", 0, 8).map(dailyQuest),
      };
      const titles = new Set((payload.objectives as Json[]).map((o) => String(o.title).toLowerCase()));
      for (const q of payload.dailyQuests as Json[]) {
        if (q.objective !== undefined && !titles.has(String(q.objective).toLowerCase())) {
          throw new Invalid(`daily quest "${q.title}" names objective "${q.objective}", which is not in objectives`);
        }
      }
      if (args.startDate !== undefined) payload.startDate = date(args.startDate, "startDate");
      if (args.endDate !== undefined) payload.endDate = date(args.endDate, "endDate");
      if (kind === "seasonal" && payload.endDate === undefined) throw new Invalid("a seasonal arc needs an endDate");
      return await queue(db, userID, [{ kind: "add_arc", payload }]);
    }
    case "set_steps": {
      const payload: Json = { title: str(args.title, "title", 80), steps: steps(args.steps) };
      if (args.arc !== undefined) payload.arc = str(args.arc, "arc", 80);
      if (args.date !== undefined) payload.date = date(args.date, "date");
      return await queue(db, userID, [{ kind: "set_steps", payload }]);
    }
    case "share_quest": {
      const payload: Json = {
        title: str(args.quest, "quest", 80),
        arc: str(args.arc, "arc", 80),
        objective: str(args.objective, "objective", 80),
        remove: args.remove === true,
      };
      return await queue(db, userID, [{ kind: "share_quest", payload }]);
    }
    case "end_arc":
      return await queue(db, userID, [{ kind: "end_arc", payload: { arc: str(args.arc, "arc", 80) } }]);
    case "get_coach_questions": {
      const [waiting, recent] = await Promise.all([
        db.from("coach_questions").select("id, question, created_at")
          .eq("user_id", userID).is("answer", null).order("created_at").limit(10),
        db.from("coach_questions").select("question, answer, answered_at")
          .eq("user_id", userID).not("answer", "is", null).order("answered_at", { ascending: false }).limit(5),
      ]);
      if (waiting.error || recent.error) throw new Error("Could not read questions");
      return JSON.stringify({ waiting: waiting.data, recentlyAnswered: (recent.data ?? []).reverse() });
    }
    case "answer_coach_question": {
      const id = str(args.id, "id", 64);
      const answer = str(args.answer, "answer", 2000);
      const { data, error } = await db.from("coach_questions")
        .update({ answer, answered_at: new Date().toISOString() })
        .eq("id", id).eq("user_id", userID).is("answer", null).select("id");
      if (error) throw new Invalid("id must be a question id from get_coach_questions");
      if (!data || data.length === 0) throw new Invalid("No unanswered question with that id");
      await notify(db, userID, "Coach answered", answer);
      return "Answered. It shows on the Coach tab.";
    }
    case "set_coach_message":
      return await queue(db, userID, [{ kind: "coach_message", payload: { text: str(args.text, "text", 400) } }]);
    default:
      throw new Invalid(`Unknown tool: ${name}`);
  }
}

// ── JSON-RPC ────────────────────────────────────────────────────────────────

function result(id: unknown, value: unknown): Json {
  return { jsonrpc: "2.0", id, result: value };
}

function failure(id: unknown, code: number, message: string): Json {
  return { jsonrpc: "2.0", id: id ?? null, error: { code, message } };
}

/** Answers one message. Returns null for a notification, which gets no answer. */
async function handle(db: SupabaseClient, userID: string, message: Json): Promise<Json | null> {
  if (message.jsonrpc !== "2.0" || typeof message.method !== "string") {
    return failure(message.id, -32600, "Not a JSON-RPC 2.0 request");
  }
  if (message.id === undefined) return null;
  const params = (message.params ?? {}) as Json;

  switch (message.method) {
    case "initialize": {
      const asked = params.protocolVersion;
      const version = typeof asked === "string" && PROTOCOL_VERSIONS.includes(asked) ? asked : PROTOCOL_VERSIONS[0];
      return result(message.id, {
        protocolVersion: version,
        capabilities: { tools: {} },
        serverInfo: { name: "totonou", title: "Totonou", version: "1.0.0" },
        instructions: INSTRUCTIONS,
      });
    }
    case "ping":
      return result(message.id, {});
    case "tools/list":
      return result(message.id, { tools: TOOLS });
    case "tools/call": {
      const args = (params.arguments ?? {}) as Json;
      try {
        const text = await call(db, userID, String(params.name), args);
        return result(message.id, { content: [{ type: "text", text }] });
      } catch (error) {
        // A tool that fails answers normally with isError, so Claude can read
        // the reason and try again. Only our own messages are passed on.
        if (!(error instanceof Invalid)) console.error(error);
        const text = error instanceof Invalid ? error.message : "Something went wrong on the server.";
        return result(message.id, { content: [{ type: "text", text }], isError: true });
      }
    }
    default:
      return failure(message.id, -32601, `Method not found: ${message.method}`);
  }
}

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function json(status: number, body: unknown, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...headers } });
}

Deno.serve(async (request) => {
  // No server-to-client stream is offered, which the protocol allows.
  if (request.method !== "POST") return json(405, { error: "POST only" }, { Allow: "POST" });

  const url = new URL(request.url);
  const token = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") || url.searchParams.get("token") || "";
  if (token.length < 20) return json(401, { error: "Missing token. Create one in Totonou: Connect → Claude." });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const hash = await sha256(token);
  const { data: owner } = await db.from("claude_tokens").select("user_id").eq("token_hash", hash).maybeSingle();
  if (!owner) return json(401, { error: "Unknown token. Create a new one in Totonou: Connect → Claude." });

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json(400, failure(null, -32700, "Body must be JSON"));
  }

  // One message, or (older clients) a list of them.
  const messages = Array.isArray(body) ? body : [body];
  const answers: Json[] = [];
  for (const message of messages) {
    const answer = typeof message === "object" && message !== null
      ? await handle(db, owner.user_id, message as Json)
      : failure(null, -32600, "Not a JSON-RPC 2.0 request");
    if (answer) answers.push(answer);
  }

  // Not awaited on purpose: the answer should not wait for bookkeeping.
  db.from("claude_tokens").update({ last_used_at: new Date().toISOString() }).eq("token_hash", hash).then(() => {});

  if (answers.length === 0) return new Response(null, { status: 202 });
  return json(200, Array.isArray(body) ? answers : answers[0]);
});
