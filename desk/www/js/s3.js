// Minimal S3 upload using AWS Signature V4
// Uploads files directly from browser to S3

const S3Upload = {
  async getConfig() {
    return CastAPI.getS3Config();
  },

  async upload(file, filename, onProgress) {
    const config = await this.getConfig();
    if (!config.bucket || !config.accessKeyId) {
      throw new Error('S3 not configured. Set up storage credentials in Landscape.');
    }

    const key = `casts/${filename}`;
    const contentType = file.type || 'audio/mpeg';

    // Build the S3 PUT URL
    const endpoint = config.endpoint || `https://s3.${config.region}.amazonaws.com`;
    const url = `${endpoint}/${config.bucket}/${key}`;

    const now = new Date();
    const dateStr = now.toISOString().replace(/[-:]/g, '').replace(/\.\d+/, '');
    const dateShort = dateStr.slice(0, 8);

    const headers = {
      'Content-Type': contentType,
      'x-amz-date': dateStr,
      'x-amz-content-sha256': 'UNSIGNED-PAYLOAD',
    };

    // AWS Signature V4
    const signedHeaders = Object.keys(headers).sort().map(k => k.toLowerCase()).join(';');
    const canonicalHeaders = Object.keys(headers).sort()
      .map(k => `${k.toLowerCase()}:${headers[k]}\n`).join('');

    const canonicalUri = `/${config.bucket}/${key}`;
    const canonicalRequest = [
      'PUT', canonicalUri, '',
      `host:${new URL(endpoint).host}\n${canonicalHeaders}`,
      `host;${signedHeaders}`,
      'UNSIGNED-PAYLOAD'
    ].join('\n');

    const scope = `${dateShort}/${config.region}/s3/aws4_request`;
    const stringToSign = [
      'AWS4-HMAC-SHA256', dateStr, scope,
      await this.sha256hex(canonicalRequest)
    ].join('\n');

    const signingKey = await this.getSignatureKey(
      config.secretAccessKey, dateShort, config.region, 's3'
    );
    const signature = await this.hmacHex(signingKey, stringToSign);

    const authHeader = `AWS4-HMAC-SHA256 Credential=${config.accessKeyId}/${scope}, SignedHeaders=host;${signedHeaders}, Signature=${signature}`;

    const resp = await fetch(url, {
      method: 'PUT',
      headers: {
        ...headers,
        'Host': new URL(endpoint).host,
        'Authorization': authHeader,
      },
      body: file,
    });

    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`S3 upload failed: ${resp.status} ${text}`);
    }

    // Return the public URL
    if (config.publicUrlBase) {
      return `${config.publicUrlBase}/${key}`;
    }
    return url;
  },

  // Crypto helpers using Web Crypto API
  async hmac(key, data) {
    const cryptoKey = await crypto.subtle.importKey(
      'raw', key instanceof ArrayBuffer ? key : new TextEncoder().encode(key),
      { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
    );
    return crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(data));
  },

  async hmacHex(key, data) {
    const sig = await this.hmac(key, data);
    return Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, '0')).join('');
  },

  async sha256hex(data) {
    const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
    return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('');
  },

  async getSignatureKey(key, dateStamp, region, service) {
    let k = await this.hmac('AWS4' + key, dateStamp);
    k = await this.hmac(k, region);
    k = await this.hmac(k, service);
    k = await this.hmac(k, 'aws4_request');
    return k;
  }
};
