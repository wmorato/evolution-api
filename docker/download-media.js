// Download and decrypt WhatsApp media using Baileys
// Usage: node /evolution/scripts/download-media.js <messageId> <instanceName>

const baileys = require('baileys');
const { Pool } = require('pg');

const PG_URI = 'postgresql://postgres:50086a3babd882dd3d5faca7008bf255c1cad675522ac486@127.0.0.1:5432/evolution_api?schema=public';

async function main() {
    const [messageId, instanceName] = process.argv.slice(2);
    if (!messageId) {
        console.error('Usage: node download-media.js <messageId> [instanceName]');
        process.exit(1);
    }

    const pool = new Pool({ connectionString: PG_URI });
    
    try {
        // Query the message
        const result = await pool.query(
            `SELECT m."message" as msg, m."key" as key, m."messageType" as type,
                    m."pushName" as name, m."participant" as participant,
                    i."id" as instance_id
             FROM "Message" m
             JOIN "Instance" i ON i."id" = m."instanceId"
             WHERE m."key"->>'id' = $1
             LIMIT 1`,
            [messageId]
        );

        if (result.rows.length === 0) {
            console.error('Message not found:', messageId);
            process.exit(1);
        }

        const row = result.rows[0];
        const msgKey = row.key;
        const msgContent = row.msg;

        // Build a minimal message object that Baileys can process
        const waMsg = {
            key: msgKey,
            message: msgContent,
            messageType: row.type,
        };

        // Extract media content
        let mediaContent = null;
        let mediaType = null;
        
        for (const [type, content] of Object.entries(msgContent)) {
            if (['imageMessage', 'videoMessage', 'audioMessage', 'documentMessage', 'stickerMessage'].includes(type)) {
                mediaContent = content;
                mediaType = type.replace('Message', '');
                break;
            }
        }

        if (!mediaContent) {
            console.error('No media content found in message. Available keys:', Object.keys(msgContent));
            process.exit(1);
        }

        // Download and decrypt using Baileys
        // downloadContentFromMessage expects { mediaKey, directPath, url } directly
        const stream = await baileys.downloadContentFromMessage(mediaContent, mediaType);
        
        const chunks = [];
        for await (const chunk of stream) {
            chunks.push(chunk);
        }
        
        const buffer = Buffer.concat(chunks);
        
        // Output to stdout (pipe works for binary)
        process.stdout.write(buffer);
        
    } finally {
        await pool.end();
    }
}

main().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});
