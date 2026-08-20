import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { buildSessionContext, estimateTokens } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join, sep as pathSeparator } from "node:path";
import { homedir } from "node:os";

interface RateWindow {
  label: string;
  usedPercent: number;
  resetsIn?: string;
}

interface UsageSnapshot {
  windows: RateWindow[];
}

interface GitCache {
  root: string;
  branch: string | null;
  dirty: boolean;
  ahead: number;
  behind: number;
}

const USAGE_REFRESH_INTERVAL = 5 * 60_000;
const GIT_REFRESH_INTERVAL = 2_000;
const usageCache = new Map<string, UsageSnapshot>();
let gitCache: GitCache | null = null;

function formatWorkingDirectory(cwd: string): string {
  const home = homedir();
  if (cwd === home) return "~";
  if (cwd.startsWith(`${home}${pathSeparator}`)) return `~${cwd.slice(home.length)}`;
  return cwd;
}

function runGitCommand(command: string, cwd: string, timeout = 500): string {
  return execSync(command, {
    cwd,
    encoding: "utf8",
    timeout,
  }).trim();
}

function sameGitCache(a: GitCache | null, b: GitCache | null): boolean {
  if (!a || !b) return a === b;
  return (
    a.root === b.root &&
    a.branch === b.branch &&
    a.dirty === b.dirty &&
    a.ahead === b.ahead &&
    a.behind === b.behind
  );
}

function refreshGitCache(cwd: string): boolean {
  const previous = gitCache;
  let next: GitCache | null = null;

  try {
    const gitRoot = runGitCommand("git --no-optional-locks rev-parse --show-toplevel 2>/dev/null", cwd);

    if (gitRoot) {
      const isJj = existsSync(join(gitRoot, ".jj"));
      let branch: string | null = null;

      if (isJj) {
        try {
          const jjBranch = runGitCommand(
            `jj --no-pager log -r 'heads(ancestors(@) & bookmarks())' --no-graph -T 'bookmarks.map(|b| b.name()).join(" ")' --limit 1 2>/dev/null`,
            gitRoot,
            1000
          );
          branch = jjBranch ? jjBranch.split(" ")[0] : null;
        } catch {}
      } else {
        try {
          const gitBranch = runGitCommand("git --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null", gitRoot);
          branch = gitBranch && gitBranch !== "HEAD" ? gitBranch : null;
        } catch {}
      }

      let dirty = false;
      try {
        if (isJj) {
          const jjStatus = runGitCommand("jj --no-pager status 2>/dev/null", gitRoot, 1000);
          dirty = jjStatus.length > 0 && !jjStatus.startsWith("The working copy is clean");
        } else {
          const status = runGitCommand("git --no-optional-locks status --porcelain 2>/dev/null", gitRoot);
          dirty = status.length > 0;
        }
      } catch {}

      let ahead = 0;
      let behind = 0;
      try {
        const counts = runGitCommand(
          "git --no-optional-locks rev-list --left-right --count HEAD...@{upstream} 2>/dev/null",
          gitRoot
        );
        const [a, b] = counts.split(/\s+/);
        ahead = parseInt(a, 10) || 0;
        behind = parseInt(b, 10) || 0;
      } catch {}

      next = { root: gitRoot, branch, dirty, ahead, behind };
    }
  } catch {}

  gitCache = next;
  return !sameGitCache(previous, next);
}

function loadAuthJson(): Record<string, any> {
  const authPath = join(homedir(), ".pi", "agent", "auth.json");
  try {
    if (existsSync(authPath)) {
      return JSON.parse(readFileSync(authPath, "utf-8"));
    }
  } catch {}
  return {};
}

function resolveAuthValue(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  if (!trimmed) return undefined;

  if (trimmed.startsWith("!")) {
    try {
      const output = execSync(trimmed.slice(1), {
        encoding: "utf-8",
        stdio: ["pipe", "pipe", "pipe"],
        timeout: 2000,
      }).trim();
      return output || undefined;
    } catch {
      return undefined;
    }
  }

  if (/^[A-Z][A-Z0-9_]*$/.test(trimmed) && process.env[trimmed]) {
    return process.env[trimmed];
  }

  return trimmed;
}

function getApiKey(providerKey: string, envVar: string): string | undefined {
  if (process.env[envVar]) return process.env[envVar];

  const auth = loadAuthJson();
  const entry = auth[providerKey];
  if (!entry) return undefined;

  if (typeof entry === "string") {
    return resolveAuthValue(entry);
  }

  return resolveAuthValue(entry.key ?? entry.access ?? entry.refresh);
}

function getClaudeToken(): string | undefined {
  const auth = loadAuthJson();
  const expires = Number(auth.anthropic?.expires);
  const notExpired = !Number.isFinite(expires) || expires > Date.now() + 60_000;
  if (auth.anthropic?.access && notExpired) return auth.anthropic.access;

  try {
    const keychainData = execSync(
      'security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null',
      { encoding: "utf-8", stdio: ["pipe", "pipe", "pipe"] }
    ).trim();
    if (keychainData) {
      const parsed = JSON.parse(keychainData);
      if (parsed.claudeAiOauth?.accessToken) {
        return parsed.claudeAiOauth.accessToken;
      }
    }
  } catch {}

  return undefined;
}

function getCopilotToken(): string | undefined {
  const auth = loadAuthJson();
  return auth["github-copilot"]?.refresh;
}

function getCodexToken(): { token: string; accountId?: string } | undefined {
  const auth = loadAuthJson();
  if (auth["openai-codex"]?.access) {
    return { token: auth["openai-codex"].access, accountId: auth["openai-codex"]?.accountId };
  }

  const codexPath = join(process.env.CODEX_HOME || join(homedir(), ".codex"), "auth.json");
  try {
    if (existsSync(codexPath)) {
      const data = JSON.parse(readFileSync(codexPath, "utf-8"));
      if (data.OPENAI_API_KEY) return { token: data.OPENAI_API_KEY };
      if (data.tokens?.access_token) {
        return { token: data.tokens.access_token, accountId: data.tokens.account_id };
      }
    }
  } catch {}

  return undefined;
}

function getGeminiToken(): string | undefined {
  const auth = loadAuthJson();
  if (auth["google-gemini-cli"]?.access) return auth["google-gemini-cli"].access;

  const geminiPath = join(homedir(), ".gemini", "oauth_creds.json");
  try {
    if (existsSync(geminiPath)) {
      const data = JSON.parse(readFileSync(geminiPath, "utf-8"));
      return data.access_token;
    }
  } catch {}

  return undefined;
}

function getMinimaxToken(provider: "minimax" | "minimax-cn"): string | undefined {
  return provider === "minimax"
    ? getApiKey("minimax", "MINIMAX_API_KEY")
    : getApiKey("minimax-cn", "MINIMAX_CN_API_KEY");
}

function formatResetTime(date: Date): string {
  const diffMs = date.getTime() - Date.now();
  if (diffMs < 0) return "now";

  const diffMins = Math.floor(diffMs / 60000);
  if (diffMins < 60) return `${diffMins}m`;

  const hours = Math.floor(diffMins / 60);
  const mins = diffMins % 60;
  if (hours < 24) return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;

  const days = Math.floor(hours / 24);
  const remainingHours = hours % 24;
  return remainingHours > 0 ? `${days}d ${remainingHours}h` : `${days}d`;
}

function formatTokenCount(value: number): string {
  if (!Number.isFinite(value) || value <= 0) return "0";

  const trim = (n: number) => n.toFixed(1).replace(/\.0$/, "");

  if (value >= 1_000_000_000) {
    const compact = value >= 10_000_000_000 ? Math.round(value / 1_000_000_000) : value / 1_000_000_000;
    return `${trim(compact)}b`;
  }

  if (value >= 1_000_000) {
    const compact = value >= 10_000_000 ? Math.round(value / 1_000_000) : value / 1_000_000;
    return `${trim(compact)}m`;
  }

  if (value >= 1_000) {
    const compact = value >= 10_000 ? Math.round(value / 1_000) : value / 1_000;
    return `${trim(compact)}k`;
  }

  return `${Math.round(value)}`;
}

function clampPercent(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, value));
}

function getWindowLabel(durationMs: number | undefined, fallback: string): string {
  if (!durationMs || !Number.isFinite(durationMs) || durationMs <= 0) return fallback;

  const hourMs = 60 * 60 * 1000;
  const dayMs = 24 * hourMs;
  const weekMs = 7 * dayMs;

  const isCloseToWeek = Math.abs(durationMs - weekMs) <= hourMs * 2;
  const isCloseToDay = Math.abs(durationMs - dayMs) <= hourMs * 2;
  const isCloseTo5h = Math.abs(durationMs - 5 * hourMs) <= hourMs * 2;

  if (isCloseToWeek || fallback === "Week") return "Week";
  if (isCloseToDay || fallback === "Day") return "Day";
  if (isCloseTo5h || fallback === "5h") return fallback;

  const hours = Math.round(durationMs / hourMs);
  if (hours >= 1 && hours < 48) return `${hours}h`;

  const days = Math.round(durationMs / dayMs);
  if (days >= 1) return `${days}d`;

  const mins = Math.max(1, Math.round(durationMs / 60000));
  return `${mins}m`;
}

async function fetchWithTimeout(url: string, init: RequestInit, timeoutMs = 5000): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchClaudeUsage(): Promise<UsageSnapshot> {
  const token = getClaudeToken();
  if (!token) return { windows: [] };

  try {
    const res = await fetchWithTimeout("https://api.anthropic.com/api/oauth/usage", {
      headers: {
        Authorization: `Bearer ${token}`,
        "anthropic-beta": "oauth-2025-04-20",
      },
    });

    if (!res.ok) return { windows: [] };

    const data = (await res.json()) as any;
    const windows: RateWindow[] = [];

    if (data.five_hour?.utilization != null) {
      windows.push({
        label: "5h",
        usedPercent: clampPercent(Number(data.five_hour.utilization)),
        resetsIn: data.five_hour.resets_at ? formatResetTime(new Date(data.five_hour.resets_at)) : undefined,
      });
    }

    if (data.seven_day?.utilization != null) {
      windows.push({
        label: "Week",
        usedPercent: clampPercent(Number(data.seven_day.utilization)),
        resetsIn: data.seven_day.resets_at ? formatResetTime(new Date(data.seven_day.resets_at)) : undefined,
      });
    }

    return { windows };
  } catch {
    return { windows: [] };
  }
}

async function fetchCopilotUsage(): Promise<UsageSnapshot> {
  const token = getCopilotToken();
  if (!token) return { windows: [] };

  try {
    const res = await fetchWithTimeout("https://api.github.com/copilot_internal/user", {
      headers: {
        "Editor-Version": "vscode/1.96.2",
        "User-Agent": "GitHubCopilotChat/0.26.7",
        "X-Github-Api-Version": "2025-04-01",
        Accept: "application/json",
        Authorization: `token ${token}`,
      },
    });

    if (!res.ok) return { windows: [] };

    const data = (await res.json()) as any;
    const windows: RateWindow[] = [];
    const resetDate = data.quota_reset_date_utc ? new Date(data.quota_reset_date_utc) : undefined;
    const resetsIn = resetDate ? formatResetTime(resetDate) : undefined;

    if (data.quota_snapshots?.premium_interactions) {
      const pi = data.quota_snapshots.premium_interactions;
      windows.push({ label: "Premium", usedPercent: clampPercent(100 - (pi.percent_remaining || 0)), resetsIn });
    }

    if (data.quota_snapshots?.chat && !data.quota_snapshots.chat.unlimited) {
      const chat = data.quota_snapshots.chat;
      windows.push({ label: "Chat", usedPercent: clampPercent(100 - (chat.percent_remaining || 0)), resetsIn });
    }

    return { windows };
  } catch {
    return { windows: [] };
  }
}

async function fetchCodexUsage(): Promise<UsageSnapshot> {
  const creds = getCodexToken();
  if (!creds) return { windows: [] };

  try {
    const headers: Record<string, string> = {
      Authorization: `Bearer ${creds.token}`,
      "User-Agent": "pi-agent",
      Accept: "application/json",
    };

    if (creds.accountId) headers["ChatGPT-Account-Id"] = creds.accountId;

    const res = await fetchWithTimeout("https://chatgpt.com/backend-api/wham/usage", {
      method: "GET",
      headers,
    });

    if (!res.ok) return { windows: [] };

    const data = (await res.json()) as any;
    const windows: RateWindow[] = [];

    if (data.rate_limit?.primary_window) {
      const pw = data.rate_limit.primary_window;
      windows.push({
        label: getWindowLabel(typeof pw.limit_window_seconds === "number" ? pw.limit_window_seconds * 1000 : undefined, "5h"),
        usedPercent: clampPercent(pw.used_percent || 0),
        resetsIn: pw.reset_at ? formatResetTime(new Date(pw.reset_at * 1000)) : undefined,
      });
    }

    if (data.rate_limit?.secondary_window) {
      const sw = data.rate_limit.secondary_window;
      windows.push({
        label: getWindowLabel(typeof sw.limit_window_seconds === "number" ? sw.limit_window_seconds * 1000 : undefined, "Week"),
        usedPercent: clampPercent(sw.used_percent || 0),
        resetsIn: sw.reset_at ? formatResetTime(new Date(sw.reset_at * 1000)) : undefined,
      });
    }

    return { windows };
  } catch {
    return { windows: [] };
  }
}

async function fetchGeminiUsage(): Promise<UsageSnapshot> {
  const token = getGeminiToken();
  if (!token) return { windows: [] };

  try {
    const res = await fetchWithTimeout("https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota", {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: "{}",
    });

    if (!res.ok) return { windows: [] };

    const data = (await res.json()) as any;
    const quotas: Record<string, number> = {};

    for (const bucket of data.buckets || []) {
      const model = bucket.modelId || "unknown";
      const frac = bucket.remainingFraction ?? 1;
      if (!quotas[model] || frac < quotas[model]) quotas[model] = frac;
    }

    const windows: RateWindow[] = [];
    let proMin = 1;
    let flashMin = 1;
    let hasProModel = false;
    let hasFlashModel = false;

    for (const [model, frac] of Object.entries(quotas)) {
      if (model.toLowerCase().includes("pro")) {
        hasProModel = true;
        if (frac < proMin) proMin = frac;
      }
      if (model.toLowerCase().includes("flash")) {
        hasFlashModel = true;
        if (frac < flashMin) flashMin = frac;
      }
    }

    if (hasProModel) windows.push({ label: "Pro", usedPercent: clampPercent((1 - proMin) * 100) });
    if (hasFlashModel) windows.push({ label: "Flash", usedPercent: clampPercent((1 - flashMin) * 100) });

    return { windows };
  } catch {
    return { windows: [] };
  }
}

async function fetchMinimaxUsage(provider: "minimax" | "minimax-cn"): Promise<UsageSnapshot> {
  const token = getMinimaxToken(provider);
  const endpoint =
    provider === "minimax-cn"
      ? "https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains"
      : "https://api.minimax.io/v1/api/openplatform/coding_plan/remains";

  if (!token) return { windows: [] };

  try {
    const res = await fetchWithTimeout(endpoint, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
    });

    if (!res.ok) return { windows: [] };

    const data = (await res.json()) as any;
    const baseResp = data?.base_resp;
    if (baseResp?.status_code && baseResp.status_code !== 0) {
      return { windows: [] };
    }

    const remains = Array.isArray(data?.model_remains) ? data.model_remains : [];
    const textBucket =
      remains.find((entry: any) => typeof entry?.model_name === "string" && /^minimax-m/i.test(entry.model_name)) ||
      remains.find((entry: any) => typeof entry?.model_name === "string" && /minimax/i.test(entry.model_name)) ||
      remains[0];

    if (!textBucket) return { windows: [] };

    const windows: RateWindow[] = [];

    const intervalTotal = Number(textBucket.current_interval_total_count) || 0;
    const intervalRemaining = Number(textBucket.current_interval_usage_count) || 0;
    if (intervalTotal > 0) {
      const used = intervalTotal - intervalRemaining;
      windows.push({
        label: getWindowLabel(
          textBucket.start_time && textBucket.end_time ? Number(textBucket.end_time) - Number(textBucket.start_time) : undefined,
          "5h"
        ),
        usedPercent: clampPercent((used / intervalTotal) * 100),
        resetsIn: textBucket.end_time ? formatResetTime(new Date(Number(textBucket.end_time))) : undefined,
      });
    }

    const weeklyTotal = Number(textBucket.current_weekly_total_count) || 0;
    const weeklyRemaining = Number(textBucket.current_weekly_usage_count) || 0;
    if (weeklyTotal > 0) {
      const used = weeklyTotal - weeklyRemaining;
      windows.push({
        label: getWindowLabel(
          textBucket.weekly_start_time && textBucket.weekly_end_time
            ? Number(textBucket.weekly_end_time) - Number(textBucket.weekly_start_time)
            : undefined,
          "Week"
        ),
        usedPercent: clampPercent((used / weeklyTotal) * 100),
        resetsIn: textBucket.weekly_end_time ? formatResetTime(new Date(Number(textBucket.weekly_end_time))) : undefined,
      });
    }

    return { windows };
  } catch {
    return { windows: [] };
  }
}

const PROVIDER_MAP: Record<string, string> = {
  anthropic: "claude",
  "openai-codex": "codex",
  "github-copilot": "copilot",
  "google-gemini-cli": "gemini",
  minimax: "minimax",
  "minimax-cn": "minimax-cn",
};

function detectProvider(modelProvider: string): string | null {
  return PROVIDER_MAP[modelProvider] || null;
}

async function fetchUsageForProvider(provider: string): Promise<UsageSnapshot> {
  switch (provider) {
    case "claude":
      return fetchClaudeUsage();
    case "codex":
      return fetchCodexUsage();
    case "copilot":
      return fetchCopilotUsage();
    case "gemini":
      return fetchGeminiUsage();
    case "minimax":
      return fetchMinimaxUsage("minimax");
    case "minimax-cn":
      return fetchMinimaxUsage("minimax-cn");
    default:
      return { windows: [] };
  }
}

export default function (pi: ExtensionAPI) {
  const SEP = " · ";

  function getPercentColor(percentage: number | null): string {
    if (typeof percentage !== "number" || !Number.isFinite(percentage)) return "dim";

    const clamped = Math.max(0, Math.min(100, percentage));
    if (clamped >= 90) return "error";
    if (clamped >= 70) return "warning";
    if (clamped >= 50) return "success";
    return "accent";
  }

  function renderContextGauge(
    percentage: number | null,
    theme: any,
    used?: number | null,
    total?: number,
    estimated = false
  ): string {
    const known = typeof percentage === "number" && Number.isFinite(percentage);
    const clamped = known ? Math.max(0, Math.min(100, percentage)) : null;
    const estimateMark = estimated ? "~" : "";
    const pct = known ? `${estimateMark}${Math.round(clamped!)}%` : "?%";
    const usage =
      typeof total === "number" && total > 0
        ? theme.fg(
            "dim",
            ` (${typeof used === "number" ? `${estimateMark}${formatTokenCount(used)}` : "?"}/${formatTokenCount(total)})`
          )
        : "";
    return theme.fg("dim", "Context:") + " " + theme.fg(getPercentColor(clamped), pct) + usage;
  }

  function wrapSections(parts: Array<string | null | undefined>, width: number, sep: string): string[] {
    const lines: string[] = [];
    let current = "";

    for (const part of parts) {
      if (!part) continue;

      const next = current ? `${current}${sep}${part}` : part;
      if (current && visibleWidth(next) > width) {
        lines.push(current);
        current = part;
      } else {
        current = next;
      }
    }

    if (current) lines.push(current);
    return lines;
  }

  function renderUsageSections(usage: UsageSnapshot, theme: any): string[] {
    if (!usage.windows.length) return [];

    const dim = (s: string) => theme.fg("dim", s);
    const parts: string[] = [];

    for (const w of usage.windows) {
      const clamped = Math.max(0, Math.min(100, w.usedPercent));
      const pct = theme.fg(getPercentColor(clamped), `${Math.round(clamped)}%`);
      const timeStr = w.resetsIn ? " " + dim(`(${w.resetsIn})`) : "";
      parts.push(`${dim(`${w.label}:`)} ${pct}${timeStr}`);
    }

    return parts;
  }

  function joinSections(parts: Array<string | null | undefined>, sep: string): string {
    return parts.filter((part): part is string => Boolean(part)).join(sep);
  }

  function getThinkingLevel(ctx: any): string {
    const entries = ctx.sessionManager.getEntries();
    const leafId = ctx.sessionManager.getLeafId();
    const context = buildSessionContext(entries, leafId);
    return context.thinkingLevel || "off";
  }

  function getNumber(value: unknown): number | null {
    return typeof value === "number" && Number.isFinite(value) ? value : null;
  }

  function getEventPostCompactionEstimate(event: any): number | null {
    return (
      getNumber(event?.estimatedTokensAfter) ??
      getNumber(event?.result?.estimatedTokensAfter) ??
      getNumber(event?.compactionResult?.estimatedTokensAfter) ??
      getNumber(event?.compaction?.estimatedTokensAfter) ??
      getNumber(event?.compactionEntry?.estimatedTokensAfter) ??
      getNumber(event?.compactionEntry?.details?.estimatedTokensAfter)
    );
  }

  function estimateCurrentContextTokens(ctx: any): number | null {
    try {
      const entries = ctx.sessionManager.getEntries();
      const leafId = ctx.sessionManager.getLeafId();
      const context = buildSessionContext(entries, leafId);
      return context.messages.reduce((total: number, message: any) => total + estimateTokens(message), 0);
    } catch {
      return null;
    }
  }

  let postCompactionTokenEstimate: number | null = null;

  function getContextInfo(ctx: any): { percentage: number | null; used: number | null; total: number; estimated: boolean } {
    const usage = ctx.getContextUsage?.();
    if (usage) {
      const used = getNumber(usage.tokens);
      const total = usage.contextWindow;

      if (used !== null) {
        postCompactionTokenEstimate = null;
        return { percentage: usage.percent, used, total, estimated: false };
      }

      // Immediately after compaction, pi intentionally reports unknown context usage
      // until the next provider response. Use pi's post-compaction estimate when the
      // event provides it, and fall back to the same message-token heuristic.
      const estimatedTokens =
        getNumber((usage as any).estimatedTokensAfter) ?? postCompactionTokenEstimate ?? estimateCurrentContextTokens(ctx);
      if (estimatedTokens !== null && total > 0) {
        return { percentage: (estimatedTokens / total) * 100, used: estimatedTokens, total, estimated: true };
      }

      return { percentage: usage.percent, used: null, total, estimated: false };
    }

    const contextWindow = ctx.model?.contextWindow ?? 0;
    return { percentage: 0, used: 0, total: contextWindow, estimated: false };
  }

  let latestUsage: UsageSnapshot | null = null;
  let activeProvider: string | null = null;
  let refreshTimer: ReturnType<typeof setInterval> | null = null;
  let gitRefreshTimer: ReturnType<typeof setInterval> | null = null;
  let tuiRef: { requestRender: () => void } | null = null;

  function fetchUsage(modelProvider: string): void {
    const provider = detectProvider(modelProvider);
    if (!provider) return;

    activeProvider = provider;
    const cached = usageCache.get(provider);
    if (cached && cached.windows.length > 0) {
      latestUsage = cached;
      tuiRef?.requestRender();
    }

    fetchUsageForProvider(provider)
      .then((u) => {
        if (!u || activeProvider !== provider) return;
        if (u.windows.length === 0 && cached?.windows.length) return;
        usageCache.set(provider, u);
        latestUsage = u;
        tuiRef?.requestRender();
      })
      .catch(() => {});
  }

  function startRefreshTimer(): void {
    if (refreshTimer) clearInterval(refreshTimer);
    refreshTimer = setInterval(() => {
      if (!activeProvider) return;
      const provider = activeProvider;
      const cached = usageCache.get(provider);
      fetchUsageForProvider(provider)
        .then((u) => {
          if (!u || activeProvider !== provider) return;
          if (u.windows.length === 0 && cached?.windows.length) return;
          usageCache.set(provider, u);
          latestUsage = u;
          tuiRef?.requestRender();
        })
        .catch(() => {});
    }, USAGE_REFRESH_INTERVAL);
  }

  function stopRefreshTimer(): void {
    if (!refreshTimer) return;
    clearInterval(refreshTimer);
    refreshTimer = null;
  }

  function startGitRefreshTimer(getCwd: () => string): void {
    if (gitRefreshTimer) clearInterval(gitRefreshTimer);
    gitRefreshTimer = setInterval(() => {
      if (refreshGitCache(getCwd())) tuiRef?.requestRender();
    }, GIT_REFRESH_INTERVAL);
  }

  function stopGitRefreshTimer(): void {
    if (!gitRefreshTimer) return;
    clearInterval(gitRefreshTimer);
    gitRefreshTimer = null;
  }

  pi.on("session_start", async (_event, ctx) => {
    const getCwd = () => ctx.sessionManager.getCwd();
    postCompactionTokenEstimate = null;
    refreshGitCache(getCwd());
    if (!ctx.hasUI) return;

    ctx.ui.setFooter((tui: any, theme: any, footerData: any) => {
      tuiRef = tui;

      const unsub = footerData.onBranchChange(() => {
        postCompactionTokenEstimate = null;
        refreshGitCache(getCwd());
        tui.requestRender();
      });

      startGitRefreshTimer(getCwd);

      if (ctx.model?.provider) {
        fetchUsage(ctx.model.provider);
        startRefreshTimer();
      }

      return {
        dispose: () => {
          unsub();
          tuiRef = null;
          stopRefreshTimer();
          stopGitRefreshTimer();
        },
        invalidate() {},
        render(width: number): string[] {
          const { percentage, used: ctxUsed, total: ctxTotal, estimated } = getContextInfo(ctx);

          const cwd = getCwd();
          const pwd = formatWorkingDirectory(cwd);

          let branchStr = "";
          if (gitCache?.branch) {
            branchStr = theme.fg("dim", gitCache.branch);
            if (gitCache.dirty) branchStr += theme.fg("warning", "*");
            if (gitCache.ahead) branchStr += theme.fg("success", ` ⇡${gitCache.ahead}`);
            if (gitCache.behind) branchStr += theme.fg("warning", ` ⇣${gitCache.behind}`);
          }

          const sep = theme.fg("dim", SEP);
          const modelName = ctx.model?.id?.split("/").pop() || "no-model";
          let reasoningStr = "";
          if (ctx.model?.reasoning) {
            const thinkingLevel = getThinkingLevel(ctx);
            if (thinkingLevel !== "off") {
              reasoningStr = theme.fg("dim", thinkingLevel);
            }
          }

          const pwdStr = theme.fg("accent", pwd);
          const space = " ";
          const pwdBranchStr = joinSections([pwdStr, branchStr], space);
          const modelStr = joinSections([theme.fg("dim", modelName), reasoningStr], space);
          const gauge = renderContextGauge(percentage, theme, ctxUsed, ctxTotal, estimated);
          const usageSections = latestUsage && latestUsage.windows.length > 0
            ? renderUsageSections(latestUsage, theme)
            : [];

          return wrapSections([pwdBranchStr, modelStr, gauge, ...usageSections], width, sep).map((line) =>
            truncateToWidth(line, width)
          );
        },
      };
    });
  });

  pi.on("model_select", (event) => {
    if (!event.model?.provider) return;
    fetchUsage(event.model.provider);
    startRefreshTimer();
  });

  pi.on("session_compact", (event, ctx) => {
    postCompactionTokenEstimate = getEventPostCompactionEstimate(event) ?? estimateCurrentContextTokens(ctx);
    tuiRef?.requestRender();
  });
}
