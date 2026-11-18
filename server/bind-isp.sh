#!/usr/bin/env bash
set -euo pipefail

# 服务端一键绑定/换绑独享静态 ISP 到 metacubexd（脱敏通用模板）
# 请将下方 MERGE_IDS 替换为你自己 metacubexd profiles 中的 Merge Profile UUID

if [ "$#" -lt 3 ]; then
  echo "用法: $0 <socks5|http> <ISP_IP> <PORT> [USERNAME] [PASSWORD]"
  exit 1
fi

ISP_TYPE="$1"
ISP_SERVER="$2"
ISP_PORT="$3"
ISP_USER="${4:-}"
ISP_PASS="${5:-}"
MERGE_IDS="${MERGE_IDS:-}"

if [ -z "$MERGE_IDS" ]; then
  echo "请先设置环境变量 MERGE_IDS（多个 UUID 用逗号分隔），例如："
  echo "MERGE_IDS=uuid1,uuid2 $0 socks5 1.2.3.4 1080 user pass"
  exit 1
fi

docker exec -i \
  -e ISP_TYPE="$ISP_TYPE" \
  -e ISP_SERVER="$ISP_SERVER" \
  -e ISP_PORT="$ISP_PORT" \
  -e ISP_USER="$ISP_USER" \
  -e ISP_PASS="$ISP_PASS" \
  -e MERGE_IDS="$MERGE_IDS" \
  metacubexd sh -c 'cd /app/server && node --input-type=module' << 'NODE'
import fs from 'node:fs/promises';
import YAML from 'yaml';

const MERGE_IDS = process.env.MERGE_IDS.split(',').map(s => s.trim()).filter(Boolean);
const ISP_NAME = '🇺🇸 独享静态ISP';
const proxyEntry = {
  name: ISP_NAME,
  type: process.env.ISP_TYPE,
  server: process.env.ISP_SERVER,
  port: Number(process.env.ISP_PORT),
  ...(process.env.ISP_USER ? { username: process.env.ISP_USER } : {}),
  ...(process.env.ISP_PASS ? { password: process.env.ISP_PASS } : {}),
  ...(process.env.ISP_TYPE === 'socks5' ? { udp: true } : {}),
  'dialer-proxy': 'ISP-前置跳板',
};

const token = process.env.CONTROL_TOKEN;
const headers = { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) };
async function api(method, path, body) {
  const r = await fetch(`http://127.0.0.1:8080/api/control${path}`, {
    method, headers, body: body ? JSON.stringify(body) : undefined,
  });
  const t = await r.text();
  if (!r.ok) throw new Error(`${method} ${path} -> ${r.status}: ${t}`);
  return t ? JSON.parse(t) : null;
}

for (const id of MERGE_IDS) {
  const doc = YAML.parse(await fs.readFile(`/data/profiles/${id}.yaml`, 'utf8')) || {};
  doc['append-proxies'] = [proxyEntry, ...(doc['append-proxies'] || []).filter(p => p.name !== ISP_NAME)];
  doc.listeners = [{ name: 'pure-static-isp', type: 'mixed', port: 17899, listen: '0.0.0.0', udp: true, proxy: ISP_NAME }];
  for (const g of (doc['append-proxy-groups'] || [])) {
    if (g.name === 'AI-sub' || g.name === 'AI-google') {
      g.proxies = [ISP_NAME, ...(g.proxies || []).filter(n => n !== ISP_NAME)];
    }
  }
  await api('PUT', `/profiles/${id}`, { content: YAML.stringify(doc) });
}

const state = JSON.parse(await fs.readFile('/data/profiles/state.json', 'utf8'));
await api('POST', `/profiles/${state.activeId}/activate`);
const clashSecret = process.env.CLASH_SECRET;
const clashHeaders = { 'Content-Type': 'application/json', ...(clashSecret ? { Authorization: `Bearer ${clashSecret}` } : {}) };
for (const g of ['AI-sub', 'AI-google']) {
  const chk = await fetch(`http://127.0.0.1:9090/proxies/${encodeURIComponent(g)}`, { headers: clashHeaders });
  if (chk.ok) {
    await fetch(`http://127.0.0.1:9090/proxies/${encodeURIComponent(g)}`, {
      method: 'PUT', headers: clashHeaders, body: JSON.stringify({ name: ISP_NAME }),
    });
  }
}
console.log('Successfully bound static ISP and reloaded active profile.');
NODE
