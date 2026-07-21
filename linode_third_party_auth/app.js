#!/usr/bin/env node

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { URL } = require('url');

const ROOT = __dirname;
const ENV_PATH = path.join(ROOT, '.env');
const DATA_DIR = path.join(ROOT, 'data');
const TOKEN_PATH = path.join(DATA_DIR, 'linode_oauth_token.json');
const PAT_PATH = path.join(DATA_DIR, 'linode_generated_pat.json');

function loadEnv(filePath) {
    if (!fs.existsSync(filePath)) return;
    const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
    for (const rawLine of lines) {
        const line = rawLine.trim();
        if (!line || line.startsWith('#')) continue;
        const eq = line.indexOf('=');
        if (eq <= 0) continue;
        const key = line.slice(0, eq).trim();
        let value = line.slice(eq + 1).trim();
        if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
            value = value.slice(1, -1);
        }
        if (!process.env[key]) process.env[key] = value;
    }
}

loadEnv(ENV_PATH);

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '127.0.0.1';

function normalizeScopeValue(value) {
    return value
        .replace(/:read(\b)/g, ':read_only$1')
        .replace(/:write(\b)/g, ':read_write$1');
}

function normalizeScopes(scopes) {
    return scopes
        .split(/\s+/)
        .filter(Boolean)
        .map(normalizeScopeValue)
        .join(' ');
}

const CLIENT_ID = process.env.LINODE_OAUTH_CLIENT_ID || '';
const CLIENT_SECRET = process.env.LINODE_OAUTH_CLIENT_SECRET || '';
const REDIRECT_URI = process.env.LINODE_OAUTH_REDIRECT_URI || `http://${HOST}:${PORT}/auth/callback`;
const SCOPES = normalizeScopes(process.env.LINODE_OAUTH_SCOPES || 'linodes:read_only');
const PAT_SCOPES = normalizeScopes(process.env.LINODE_PAT_SCOPES || '*');
const PAT_EXPIRY = (process.env.LINODE_PAT_EXPIRY || '').trim();

const AUTHORIZE_URL = 'https://login.linode.com/oauth/authorize';
const TOKEN_URL = 'https://login.linode.com/oauth/token';
const API_PAT_URL = 'https://api.linode.com/v4/profile/tokens';

const oauthRequests = new Map();

function isPlaceholder(value) {
    if (!value) return true;
    const normalized = value.trim().toLowerCase();
    return normalized === 'your_client_id' || normalized === 'your_client_secret';
}

function sendHtml(res, statusCode, html) {
    res.writeHead(statusCode, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(html);
}

function sendJson(res, statusCode, data) {
    res.writeHead(statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(data, null, 2));
}

function ensureDir(dirPath) {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true, mode: 0o700 });
    }
}

function saveToken(payload) {
    ensureDir(DATA_DIR);
    fs.writeFileSync(TOKEN_PATH, JSON.stringify(payload, null, 2), { mode: 0o600 });
}

function savePat(payload) {
    ensureDir(DATA_DIR);
    fs.writeFileSync(PAT_PATH, JSON.stringify(payload, null, 2), { mode: 0o600 });
}

function parsePatLabel(raw) {
    const value = (raw || '').trim();
    if (!value) return { ok: false, message: 'PAT label is required.' };
    if (value.length > 100) return { ok: false, message: 'PAT label must be 100 characters or fewer.' };
    return { ok: true, value };
}

function buildAuthorizeUrl(state) {
    const u = new URL(AUTHORIZE_URL);
    u.searchParams.set('response_type', 'code');
    u.searchParams.set('client_id', CLIENT_ID);
    u.searchParams.set('redirect_uri', REDIRECT_URI);
    u.searchParams.set('scope', SCOPES);
    u.searchParams.set('state', state);
    return u.toString();
}

async function exchangeCodeForToken(code) {
    const body = new URLSearchParams();
    body.set('grant_type', 'authorization_code');
    body.set('code', code);
    body.set('client_id', CLIENT_ID);
    body.set('client_secret', CLIENT_SECRET);
    body.set('redirect_uri', REDIRECT_URI);

    const resp = await fetch(TOKEN_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            Accept: 'application/json',
        },
        body,
    });

    const text = await resp.text();
    let json;
    try {
        json = JSON.parse(text);
    } catch {
        json = { raw: text };
    }

    if (!resp.ok) {
        const msg = json.error_description || json.error || `Token request failed with status ${resp.status}`;
        const err = new Error(msg);
        err.stage = 'token_exchange';
        err.details = json;
        throw err;
    }

    return json;
}

async function createPatWithOAuth(oauthAccessToken, label) {
    const body = {
        label,
        scopes: PAT_SCOPES,
    };

    if (PAT_EXPIRY) {
        body.expiry = PAT_EXPIRY;
    }

    const resp = await fetch(API_PAT_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
            Authorization: `Bearer ${oauthAccessToken}`,
        },
        body: JSON.stringify(body),
    });

    const text = await resp.text();
    let json;
    try {
        json = JSON.parse(text);
    } catch {
        json = { raw: text };
    }

    if (!resp.ok) {
        const defaultReason = `PAT request failed with status ${resp.status}`;
        const msg =
            json.error_description ||
            json.error ||
            (Array.isArray(json.errors) && json.errors[0] && json.errors[0].reason) ||
            defaultReason;
        const err = new Error(msg);
        err.stage = 'pat_creation';
        err.details = json;
        throw err;
    }

    return json;
}

function maskToken(token) {
    if (!token || token.length < 12) return token || '';
    return `${token.slice(0, 6)}...${token.slice(-4)}`;
}

function renderHome() {
    return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Linode OAuth Demo</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; margin: 2rem; max-width: 760px; }
      code { background: #f3f3f3; padding: 0.2rem 0.4rem; border-radius: 4px; }
      .card { border: 1px solid #ddd; border-radius: 8px; padding: 1rem; margin-bottom: 1rem; }
      a.button { display: inline-block; background: #222; color: #fff; text-decoration: none; padding: 0.6rem 1rem; border-radius: 6px; }
    </style>
  </head>
  <body>
    <h1>Linode Third-Party Auth Demo</h1>
    <div class="card">
      <p>This app demonstrates the OAuth Authorization Code flow against <code>https://login.linode.com/oauth/authorize</code>.</p>
                <p>After callback, OAuth token is saved at <code>${TOKEN_PATH}</code> and generated PAT is saved at <code>${PAT_PATH}</code>.</p>
                <form action="/auth/login" method="GET" style="display:flex; gap:0.5rem; flex-wrap:wrap; align-items:center;">
                    <label for="pat_label"><strong>PAT label</strong></label>
                    <input id="pat_label" name="pat_label" type="text" maxlength="100" required placeholder="my-cli-token" style="padding:0.5rem; min-width:260px;" />
                    <button type="submit" style="background:#222; color:#fff; border:0; border-radius:6px; padding:0.6rem 1rem; cursor:pointer;">Start OAuth Flow</button>
                </form>
    </div>
    <div class="card">
      <h3>Current Config</h3>
      <p>Client ID set: <strong>${CLIENT_ID ? 'yes' : 'no'}</strong></p>
      <p>Client Secret set: <strong>${CLIENT_SECRET ? 'yes' : 'no'}</strong></p>
      <p>Redirect URI: <code>${REDIRECT_URI}</code></p>
      <p>Scopes: <code>${SCOPES}</code></p>
                <p>PAT scopes to request: <code>${PAT_SCOPES}</code></p>
                <p>PAT expiry: <code>${PAT_EXPIRY || '(none)'}</code></p>
    </div>
            <p>Check files quickly: <code>cat data/linode_oauth_token.json</code> and <code>cat data/linode_generated_pat.json</code></p>
  </body>
</html>`;
}

const server = http.createServer(async (req, res) => {
    const reqUrl = new URL(req.url, `http://${req.headers.host || `${HOST}:${PORT}`}`);

    if (reqUrl.pathname === '/') {
        return sendHtml(res, 200, renderHome());
    }

    if (reqUrl.pathname === '/healthz') {
        return sendJson(res, 200, { ok: true });
    }

    if (reqUrl.pathname === '/auth/login') {
        if (isPlaceholder(CLIENT_ID) || isPlaceholder(CLIENT_SECRET)) {
            return sendJson(res, 500, {
                error: 'missing_oauth_config',
                message:
                    'Set valid LINODE_OAUTH_CLIENT_ID and LINODE_OAUTH_CLIENT_SECRET in .env (not placeholder values).',
            });
        }

        const parsedLabel = parsePatLabel(reqUrl.searchParams.get('pat_label'));
        if (!parsedLabel.ok) {
            return sendJson(res, 400, {
                error: 'invalid_pat_label',
                message: parsedLabel.message,
            });
        }

        const state = crypto.randomBytes(24).toString('hex');
        oauthRequests.set(state, { patLabel: parsedLabel.value, createdAt: Date.now() });

        const authUrl = buildAuthorizeUrl(state);
        res.writeHead(302, { Location: authUrl });
        return res.end();
    }

    if (reqUrl.pathname === '/auth/callback') {
        const error = reqUrl.searchParams.get('error');
        const errorDesc = reqUrl.searchParams.get('error_description');
        if (error) {
            return sendJson(res, 400, {
                error,
                error_description: errorDesc || 'Authorization failed',
            });
        }

        const code = reqUrl.searchParams.get('code');
        const state = reqUrl.searchParams.get('state');

        if (!code || !state) {
            return sendJson(res, 400, { error: 'invalid_callback', message: 'Missing code or state' });
        }

        const pendingRequest = oauthRequests.get(state);
        if (!pendingRequest) {
            return sendJson(res, 400, { error: 'invalid_state', message: 'State validation failed' });
        }
        oauthRequests.delete(state);

        try {
            const tokenResponse = await exchangeCodeForToken(code);
            const patResponse = await createPatWithOAuth(tokenResponse.access_token, pendingRequest.patLabel);

            const persisted = {
                saved_at: new Date().toISOString(),
                token_endpoint: TOKEN_URL,
                scopes: SCOPES,
                response: tokenResponse,
            };
            saveToken(persisted);

            const patPersisted = {
                saved_at: new Date().toISOString(),
                api_endpoint: API_PAT_URL,
                requested_scopes: PAT_SCOPES,
                requested_expiry: PAT_EXPIRY || null,
                label: pendingRequest.patLabel,
                response: patResponse,
            };
            savePat(patPersisted);

            return sendHtml(
                res,
                200,
                `<!doctype html>
<html>
  <head><meta charset="utf-8" /><title>OAuth Success</title></head>
  <body style="font-family: -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; margin: 2rem;">
        <h2>OAuth + PAT created</h2>
        <p>OAuth access token: <code>${maskToken(tokenResponse.access_token)}</code></p>
        <p>PAT label: <code>${pendingRequest.patLabel}</code></p>
        <p>PAT token: <code>${maskToken(patResponse.token)}</code></p>
        <p>OAuth saved to: <code>${TOKEN_PATH}</code></p>
        <p>PAT saved to: <code>${PAT_PATH}</code></p>
    <p><a href="/">Back to home</a></p>
  </body>
</html>`
            );
        } catch (err) {
            const isPatCreationError = err.stage === 'pat_creation';
            return sendJson(res, 500, {
                error: isPatCreationError ? 'pat_creation_failed' : 'token_exchange_failed',
                message: err.message,
                hint: isPatCreationError
                    ? 'Ensure OAuth token includes account:read_write and user has create_profile_pat permission.'
                    : null,
                details: err.details || null,
            });
        }
    }

    sendJson(res, 404, { error: 'not_found' });
});

server.listen(PORT, HOST, () => {
    console.log(`Linode OAuth demo listening on http://${HOST}:${PORT}`);
    console.log(`Authorize endpoint: ${AUTHORIZE_URL}`);
    console.log(`Token file path: ${TOKEN_PATH}`);
});
