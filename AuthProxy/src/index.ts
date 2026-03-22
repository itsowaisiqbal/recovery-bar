interface Env {
  WHOOP_CLIENT_ID: string;
  WHOOP_CLIENT_SECRET: string;
  STATS_SECRET: string; // Set via: wrangler secret put STATS_SECRET
  ANALYTICS: KVNamespace;
}

interface TokenRequest {
  code?: string;
  redirect_uri?: string;
  refresh_token?: string;
}

const WHOOP_TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token";

// Allowed redirect URIs — reject anything else
const ALLOWED_REDIRECT_URIS = ["http://localhost:8919/callback"];

// Native macOS apps don't send Origin headers, so CORS is not needed.
// Explicitly omit Access-Control-Allow-Origin to prevent browser-based abuse.
const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Access-Control-Max-Age": "86400",
};

// Reject requests from browsers (they send Origin headers, native apps don't)
function isBrowserRequest(request: Request): boolean {
  const origin = request.headers.get("Origin");
  return origin !== null;
}

// Simple in-memory rate limiter (per-isolate, resets on cold start)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 10; // requests per minute per IP
const RATE_WINDOW_MS = 60_000;

function isRateLimited(ip: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(ip);

  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return false;
  }

  entry.count += 1;
  return entry.count > RATE_LIMIT;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
}

function errorResponse(message: string, status: number): Response {
  return jsonResponse({ error: message }, status);
}

// MARK: - Analytics helpers

async function trackSignIn(env: Env, ip: string): Promise<void> {
  // Increment total sign-ins
  const total = parseInt((await env.ANALYTICS.get("total_signins")) || "0");
  await env.ANALYTICS.put("total_signins", String(total + 1));

  // Track unique IPs as a proxy for unique users
  const usersJson = (await env.ANALYTICS.get("unique_users")) || "[]";
  const users: string[] = JSON.parse(usersJson);
  // Hash the IP for privacy (using client secret as salt — never exposed)
  const hash = await hashIP(ip, env.WHOOP_CLIENT_SECRET);
  if (!users.includes(hash)) {
    users.push(hash);
    await env.ANALYTICS.put("unique_users", JSON.stringify(users));
  }

  // Track last sign-in time
  await env.ANALYTICS.put("last_signin", new Date().toISOString());

  // Increment today's count
  const today = new Date().toISOString().split("T")[0];
  const todayCount = parseInt(
    (await env.ANALYTICS.get(`daily_${today}`)) || "0"
  );
  await env.ANALYTICS.put(`daily_${today}`, String(todayCount + 1));
}

async function trackRefresh(env: Env): Promise<void> {
  const total = parseInt(
    (await env.ANALYTICS.get("total_refreshes")) || "0"
  );
  await env.ANALYTICS.put("total_refreshes", String(total + 1));
}

async function hashIP(ip: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(ip + secret);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray
    .slice(0, 8)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// MARK: - Handlers

async function handleTokenExchange(
  body: TokenRequest,
  env: Env,
  ip: string
): Promise<Response> {
  if (!body.code || !body.redirect_uri) {
    return errorResponse("Missing 'code' or 'redirect_uri'", 400);
  }

  // Validate code format (alphanumeric, bounded length)
  if (!/^[A-Za-z0-9_\-\.]{8,512}$/.test(body.code)) {
    return errorResponse("Invalid code format", 400);
  }

  if (!ALLOWED_REDIRECT_URIS.includes(body.redirect_uri)) {
    return errorResponse("Invalid redirect_uri", 400);
  }

  const params = new URLSearchParams({
    grant_type: "authorization_code",
    code: body.code,
    redirect_uri: body.redirect_uri,
    client_id: env.WHOOP_CLIENT_ID,
    client_secret: env.WHOOP_CLIENT_SECRET,
  });

  const response = await fetch(WHOOP_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString(),
  });

  const data = await response.json();

  if (!response.ok) {
    const errorData = data as Record<string, unknown>;
    return errorResponse(
      (errorData.error_description as string) ||
        (errorData.error as string) ||
        "Token exchange failed",
      response.status
    );
  }

  // Track successful sign-in
  await trackSignIn(env, ip);

  return jsonResponse(data as Record<string, unknown>);
}

async function handleTokenRefresh(
  body: TokenRequest,
  env: Env
): Promise<Response> {
  if (!body.refresh_token) {
    return errorResponse("Missing 'refresh_token'", 400);
  }

  const params = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: body.refresh_token,
    client_id: env.WHOOP_CLIENT_ID,
    client_secret: env.WHOOP_CLIENT_SECRET,
    scope: "offline",
  });

  const response = await fetch(WHOOP_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString(),
  });

  const data = await response.json();

  if (!response.ok) {
    const errorData = data as Record<string, unknown>;
    return errorResponse(
      (errorData.error_description as string) ||
        (errorData.error as string) ||
        "Token refresh failed",
      response.status
    );
  }

  // Track refresh
  await trackRefresh(env);

  return jsonResponse(data as Record<string, unknown>);
}

async function handleStats(env: Env): Promise<Response> {
  const totalSignins = parseInt(
    (await env.ANALYTICS.get("total_signins")) || "0"
  );
  const totalRefreshes = parseInt(
    (await env.ANALYTICS.get("total_refreshes")) || "0"
  );
  const usersJson = (await env.ANALYTICS.get("unique_users")) || "[]";
  const uniqueUsers = JSON.parse(usersJson).length;
  const lastSignin = (await env.ANALYTICS.get("last_signin")) || "never";

  const today = new Date().toISOString().split("T")[0];
  const todayCount = parseInt(
    (await env.ANALYTICS.get(`daily_${today}`)) || "0"
  );

  return jsonResponse({
    unique_users: uniqueUsers,
    total_signins: totalSignins,
    total_refreshes: totalRefreshes,
    signins_today: todayCount,
    last_signin: lastSignin,
    user_limit: 10,
    remaining_slots: Math.max(0, 10 - uniqueUsers),
  });
}

export default {
  async fetch(
    request: Request,
    env: Env,
    _ctx: ExecutionContext
  ): Promise<Response> {
    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    // Stats endpoint (GET only, requires STATS_SECRET)
    if (url.pathname === "/stats" && request.method === "GET") {
      const authHeader = request.headers.get("Authorization");
      if (!env.STATS_SECRET || authHeader !== `Bearer ${env.STATS_SECRET}`) {
        return errorResponse("Unauthorized", 401);
      }
      return handleStats(env);
    }

    // Only POST allowed for auth endpoints
    if (request.method !== "POST") {
      return errorResponse("Method not allowed", 405);
    }

    // Reject browser-based requests (native apps don't send Origin)
    if (isBrowserRequest(request)) {
      return errorResponse("Browser requests not allowed", 403);
    }

    // Rate limiting
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    if (isRateLimited(ip)) {
      return errorResponse("Rate limited", 429);
    }

    let body: TokenRequest;

    try {
      body = (await request.json()) as TokenRequest;
    } catch {
      return errorResponse("Invalid JSON body", 400);
    }

    switch (url.pathname) {
      case "/token":
        return handleTokenExchange(body, env, ip);
      case "/refresh":
        return handleTokenRefresh(body, env);
      default:
        return errorResponse("Not found", 404);
    }
  },
};
