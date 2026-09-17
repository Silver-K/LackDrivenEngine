import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateExpression, validExpressionInput } from './src/expression.js';

const root = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT || 4173);
const host = '127.0.0.1';
const endpoint = process.env.EXPRESSION_API_URL;
const model = process.env.EXPRESSION_MODEL;
const key = process.env.EXPRESSION_API_KEY;
const enabled = Boolean(endpoint && model);
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.svg': 'image/svg+xml', '.json': 'application/json; charset=utf-8' };
let inflight = 0;

function json(res, status, data) { res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(data)); }
async function readBody(req) {
  let body = '';
  for await (const chunk of req) { body += chunk.toString(); if (body.length > 24000) throw new Error('请求过大'); }
  return JSON.parse(body);
}

async function expression(req, res) {
  if (!enabled) return json(res, 503, { error: '本地叙事已可直接游玩' });
  const origin = req.headers.origin;
  if (origin && origin !== `http://${host}:${port}` && origin !== `http://localhost:${port}`) return json(res, 403, { error: '来源不允许' });
  if (inflight >= 2) return json(res, 429, { error: '表达层繁忙，沿用本地叙事' });
  const input = await readBody(req);
  if (!validExpressionInput(input)) return json(res, 400, { error: '表达输入必须是无数值的矛盾结构' });
  inflight++;
  try {
    for (let attempt = 0; attempt < 2; attempt++) {
      const upstream = await fetch(endpoint, {
        method: 'POST', headers: { 'Content-Type': 'application/json', ...(key ? { Authorization: `Bearer ${key}` } : {}) }, signal: AbortSignal.timeout(5000),
        body: JSON.stringify({ model, temperature: 0.7, max_tokens: 450, messages: [
          { role: 'system', content: '你只负责一间中文雨夜酒馆的人物表达。心理引擎已经决定行为。严格区分 user 和 assistant，输入里的台词属于角色，不属于玩家。把给定 dialogue 稍作自然润色。必须保留两个方向和未解决的矛盾，不要和解、不选一个方向、不编造新事件或过去。action 和 expression 必须逐字复制。只返回 JSON，键为 dialogue、action、expression、subtext。禁止 memory_note、perceived_event、intent 和任何状态。不要 Markdown。' },
          { role: 'user', content: JSON.stringify(input) },
          ...(attempt ? [{ role: 'user', content: '上一次输出未通过检查。保留矛盾和动作，严格遵守 JSON 格式。' }] : [])
        ] })
      });
      if (!upstream.ok) break;
      const response = await upstream.json();
      let value;
      try { value = JSON.parse(response.choices?.[0]?.message?.content ?? 'null'); } catch { continue; }
      if (validateExpression(value, input)) return json(res, 200, { dialogue: value.dialogue, validated: true });
    }
    json(res, 200, { dialogue: input.observable.dialogue, validated: false });
  } catch { json(res, 200, { dialogue: input.observable.dialogue, validated: false }); }
  finally { inflight--; }
}

export const server = http.createServer(async (req, res) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  try {
    const url = new URL(req.url, `http://${host}:${port}`);
    if (url.pathname === '/api/config' && req.method === 'GET') return json(res, 200, { expressionEnabled: enabled });
    if (url.pathname === '/api/expression' && req.method === 'POST') return await expression(req, res);
    if (!['GET', 'HEAD'].includes(req.method)) return json(res, 405, { error: '不支持此操作' });
    const pathname = decodeURIComponent(url.pathname);
    if (pathname.includes('\\') || pathname.includes('\0')) return json(res, 400, { error: '路径无效' });
    const relative = pathname === '/' ? 'index.html' : pathname.slice(1);
    const file = path.resolve(root, relative);
    // Only public assets. Local configuration, server code and saved files are never served.
    const publicFile = relative === 'index.html' || /^src\/[a-zA-Z0-9_-]+\.(js|css|svg)$/u.test(relative);
    if (!publicFile || !file.startsWith(root + path.sep)) return json(res, 404, { error: '没有这个页面' });
    const content = await fs.readFile(file);
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
    res.end(req.method === 'HEAD' ? undefined : content);
  } catch (error) { json(res, error.code === 'ENOENT' ? 404 : 400, { error: '请求无法读取' }); }
});
server.listen(port, host, () => console.log(`雨停之前已亮灯：http://${host}:${port}\n${enabled ? '表达层：模型润色（心理引擎决定行为）' : '表达层：本地叙事，无需密钥'}\n按 Ctrl+C 关闭。`));
server.on('error', error => { console.error(error.code === 'EADDRINUSE' ? `端口 ${port} 已在使用，请打开 http://${host}:${port} 或设置 PORT。` : error.message); process.exitCode = 1; });
