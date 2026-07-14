#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.join(__dirname, '..', '..');

function etagPath(localPath) {
    return path.join(PROJECT_ROOT, 'etags', localPath + '.etag');
}

function loadETag(localPath) {
    const p = etagPath(localPath);
    return fs.existsSync(p) ? fs.readFileSync(p, 'utf-8').trim() : null;
}

function saveETag(localPath, etag) {
    const p = etagPath(localPath);
    const dir = path.dirname(p);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(p, etag, 'utf-8');
}

async function downloadStream(response) {
    const contentLength = response.headers.get('content-length');
    const contentEncoding = response.headers.get('content-encoding');
    const total = contentLength ? parseInt(contentLength, 10) : null;

    if (!total || contentEncoding) return response.arrayBuffer();

    const reader = response.body.getReader();
    const chunks = [];
    let received = 0;
    let lastLog = 0;

    try {
        while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            chunks.push(value);
            received += value.length;

            const now = Date.now();
            if (now - lastLog > 2000) {
                const pct = ((received / total) * 100).toFixed(1);
                const mb = (received / (1024 * 1024)).toFixed(1);
                const tmb = (total / (1024 * 1024)).toFixed(1);
                console.log(`下载进度: ${pct}% (${mb} MB / ${tmb} MB)`);
                lastLog = now;
            }
        }
    } catch (err) {
        throw new Error(`下载过程中连接中断: ${err.message}`);
    }

    const buf = new Uint8Array(received);
    let offset = 0;
    for (const chunk of chunks) {
        buf.set(chunk, offset);
        offset += chunk.length;
    }
    return buf.buffer;
}

async function syncFile(url, localPath) {
    const fullPath = path.join(PROJECT_ROOT, localPath);
    const dir = path.dirname(fullPath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

    const headers = { 'User-Agent': 'NodeSyncScript/1.0' };
    const cachedETag = loadETag(localPath);
    if (cachedETag && fs.existsSync(fullPath)) {
        headers['If-None-Match'] = cachedETag;
        console.log(`[缓存] 使用 ETag: ${cachedETag}`);
    }

    let response;
    try {
        response = await fetch(url, { headers });
    } catch (err) {
        throw new Error(
            `[错误] 下载失败: ${path.basename(localPath)}\n` +
            `  URL: ${url}\n` +
            `  原因: ${err.cause?.code || err.code || err.message}\n` +
            `  建议: 请检查网络连接，或稍后重试`
        );
    }

    if (response.status === 304) {
        console.log('结果：远程文件未变化（304），无需下载。', localPath);
        return true;
    }

    if (!response.ok) throw new Error(`请求失败: ${response.status} ${response.statusText}`);

    const newETag = response.headers.get('etag');
    if (newETag === cachedETag && fs.existsSync(fullPath)) {
        console.log('结果：远程文件未变化（ETag 相同），无需下载。', localPath);
        return true;
    }

    console.log('[下载]', url, localPath);
    if (!response.body) throw new Error(`响应无数据: ${response.status}`);
    const buffer = Buffer.from(await downloadStream(response));
    try {
        fs.writeFileSync(fullPath, buffer);
        console.log('文件已保存到', localPath);
    } catch (err) {
        console.error('保存文件时出错：', err);
        fs.writeFileSync(fullPath + '.tmp', buffer);
        console.log('文件已保存到', localPath + '.tmp');
        if (newETag) saveETag(localPath, newETag);
        console.log(`[更新] 新 ETag: ${newETag}`);
        console.log('=============================');
        return { ok: true, warn: true };
    }
    if (newETag) saveETag(localPath, newETag);
    console.log(`[更新] 新 ETag: ${newETag}`);
    console.log('=============================');
    return true;
}

module.exports = syncFile;
