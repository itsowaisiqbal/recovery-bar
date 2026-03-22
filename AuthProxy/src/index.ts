interface Env {
  WHOOP_CLIENT_ID: string;
  WHOOP_CLIENT_SECRET: string;
}

interface TokenRequest {
  code?: string;
  redirect_uri?: string;
  refresh_token?: string;
}

const WHOOP_TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Max-Age": "86400",
};

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

async function handleTokenExchange(
  body: TokenRequest,
  env: Env
): Promise<Response> {
  if (!body.code || !body.redirect_uri) {
    return errorResponse("Missing 'code' or 'redirect_uri'", 400);
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

  return jsonResponse(data as Record<string, unknown>);
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

    // Only POST allowed
    if (request.method !== "POST") {
      return errorResponse("Method not allowed", 405);
    }

    // Rate limiting
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    if (isRateLimited(ip)) {
      return errorResponse("Rate limited", 429);
    }

    const url = new URL(request.url);
    let body: TokenRequest;

    try {
      body = (await request.json()) as TokenRequest;
    } catch {
      return errorResponse("Invalid JSON body", 400);
    }

    switch (url.pathname) {
      case "/token":
        return handleTokenExchange(body, env);
      case "/refresh":
        return handleTokenRefresh(body, env);
      default:
        return errorResponse("Not found", 404);
    }
  },
};
