#!/usr/bin/env node

// 用法: node sync-via-etag.js <远程原始文件URL> <本地文件路径>
// 示例: node sync-via-etag.js https://raw.githubusercontent.com/torvalds/linux/master/README ./linux-readme.md

const fs = require('fs');
const path = require('path');

// 获取项目根目录（脚本所在目录的父目录）
const PROJECT_ROOT = path.join(__dirname, '..');

/**
 * 从本地 .etag 文件读取保存的 ETag
 * @param {string} localFile
 * @returns {string|null}
 */
function loadLocalETag(localFile) {
    if (fs.existsSync(localFile)) {
        const etagFile = path.join(PROJECT_ROOT, 'etags', localFile + '.etag');
        if (fs.existsSync(etagFile)) {
            return fs.readFileSync(etagFile, 'utf-8').trim();
        }
    }
    return null;
}

/**
 * 保存 ETag 到 .etag 文件
 */
function saveETag(localFile, etag) {
    const etagFile = path.join(PROJECT_ROOT, 'etags', localFile + '.etag');
    const dir = path.dirname(etagFile);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(etagFile, etag, 'utf-8');
}

async function syncViaConditionalRequest(url, localPath) {
    // 确保目录存在
    const dir = path.dirname(localPath);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }

    // 构造请求头
    const headers = {
        'User-Agent': 'NodeSyncScript/1.0',
    };

    const cachedETag = loadLocalETag(localPath);
    if (cachedETag && fs.existsSync(localPath)) {
        headers['If-None-Match'] = cachedETag;
        console.log(`[缓存] 使用 ETag: ${cachedETag}`);
    }

    const response = await fetch(url, { headers });

    // 304 → 文件未变化
    if (response.status === 304) {
        console.log('结果：远程文件未变化（304），无需下载。', localPath);
        return true;
    }

    if (!response.ok) {
        throw new Error(`请求失败: ${response.status} ${response.statusText}`);
    }

    // 200 → 文件更新或首次下载
    const newETag = response.headers.get('etag');
    if (newETag == cachedETag) {
        console.log('结果：远程文件未变化（ETag 相同），无需下载。', localPath);
        return true;
    }
    console.log('[下载]', localPath)
    // 写入文件
    const buffer = Buffer.from(await downloadWithProgress(response));
    try {
        fs.writeFileSync(localPath, buffer);
        console.log('文件已保存到', localPath);
    } catch (error) {
        console.error('保存文件时出错：', error);
        fs.writeFileSync(localPath + '.tmp', buffer);
        console.log('文件已保存到', localPath + '.tmp');
    }
    saveETag(localPath, newETag);
    console.log(`[更新] 新 ETag: ${newETag}`);
    console.log('=============================')
    return true;
}

async function downloadWithProgress(response) {
    // 1. 获取总大小
    const contentLength = response.headers.get('content-length');
    const total = contentLength ? parseInt(contentLength, 10) : null;

    // 无法获知总大小则直接回退（可选：也可以继续流式下载但不打印进度）
    if (!total) {
        return response.arrayBuffer();
    }

    const reader = response.body.getReader();
    const chunks = [];
    let received = 0;
    let startTime = null;          // 首次收到数据的时间
    let lastPrintTime = null;     // 上次打印的时间
    const INTERVAL_MS = 2000;

    while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        // 记录首次收到数据的时间
        if (startTime === null) {
            startTime = Date.now();
        }

        chunks.push(value);
        received += value.length;

        const now = Date.now();
        // 首次打印至少要在开始 2 秒后，且距离上次打印 ≥ 2 秒
        if (startTime !== null && now - startTime >= INTERVAL_MS) {
            if (lastPrintTime === null || now - lastPrintTime >= INTERVAL_MS) {
                const percent = ((received / total) * 100).toFixed(1);
                const downloadedMB = (received / (1024 * 1024)).toFixed(1);
                const totalMB = (total / (1024 * 1024)).toFixed(1);
                console.log(`下载进度: ${percent}% (${downloadedMB} MB / ${totalMB} MB)`);
                lastPrintTime = now;
            }
        }
    }

    // （可选）下载完成后的最终提示，如果你希望即使小文件也提示一句可取消注释
    // const totalMB = (total / (1024 * 1024)).toFixed(1);
    // console.log(`下载完成 (${totalMB} MB)`);

    // 合并所有块为 ArrayBuffer
    const buffer = new Uint8Array(received);
    let offset = 0;
    for (const chunk of chunks) {
        buffer.set(chunk, offset);
        offset += chunk.length;
    }
    return buffer.buffer;
}


module.exports = syncViaConditionalRequest
