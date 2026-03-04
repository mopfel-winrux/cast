// S3 upload using presigned URLs (AWS Signature V4)
// Generates a presigned PUT URL, then uploads with a simple fetch — no auth headers needed.

const S3Upload = {
  async getConfig() {
    return CastAPI.getS3Config();
  },

  async upload(file, filename) {
    const config = await this.getConfig();
    if (!config.bucket || !config.accessKeyId) {
      throw new Error('S3 not configured. Set up storage credentials in Landscape.');
    }

    const key = `casts/${filename}`;
    const contentType = file.type || 'audio/mpeg';
    const endpoint = config.endpoint || `https://s3.${config.region}.amazonaws.com`;

    const presignedUrl = await this.createPresignedUrl({
      endpoint,
      bucket: config.bucket,
      key,
      region: config.region,
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
      contentType,
    });

    const resp = await fetch(presignedUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': contentType,
        'Cache-Control': 'public, max-age=3600',
      },
      body: file,
    });

    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`S3 upload failed: ${resp.status} ${text}`);
    }

    if (config.publicUrlBase) {
      return `${config.publicUrlBase}/${key}`;
    }
    return `${endpoint}/${config.bucket}/${key}`;
  },

  async createPresignedUrl({ endpoint, bucket, key, region, accessKeyId, secretAccessKey, contentType }) {
    const url = new URL(`${endpoint}/${bucket}/${key}`);
    const now = new Date();
    const dateStr = now.toISOString().replace(/[-:]/g, '').replace(/\.\d+/, '');
    const dateShort = dateStr.slice(0, 8);
    const scope = `${dateShort}/${region}/s3/aws4_request`;

    // For presigned URLs, sign host + content-type + cache-control
    const signedHeaders = 'cache-control;content-type;host';

    // Set query parameters (signature added after signing)
    url.searchParams.set('X-Amz-Algorithm', 'AWS4-HMAC-SHA256');
    url.searchParams.set('X-Amz-Credential', `${accessKeyId}/${scope}`);
    url.searchParams.set('X-Amz-Date', dateStr);
    url.searchParams.set('X-Amz-Expires', '3600');
    url.searchParams.set('X-Amz-SignedHeaders', signedHeaders);

    // Build canonical query string (sorted, URI-encoded, WITHOUT signature)
    const sortedParams = [...url.searchParams.entries()]
      .sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));
    const canonicalQueryString = sortedParams
      .map(([k, v]) => `${this.uriEncode(k)}=${this.uriEncode(v)}`)
      .join('&');

    const canonicalHeaders =
      `cache-control:public, max-age=3600\n` +
      `content-type:${contentType}\n` +
      `host:${url.host}\n`;

    const canonicalRequest = [
      'PUT',
      url.pathname,
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    const stringToSign = [
      'AWS4-HMAC-SHA256',
      dateStr,
      scope,
      await this.sha256hex(canonicalRequest),
    ].join('\n');

    const signingKey = await this.getSignatureKey(secretAccessKey, dateShort, region, 's3');
    const signature = await this.hmacHex(signingKey, stringToSign);

    url.searchParams.set('X-Amz-Signature', signature);
    return url.toString();
  },

  // URI-encode per RFC 3986 (AWS requires this specific encoding)
  uriEncode(str) {
    return encodeURIComponent(str).replace(/[!'()*]/g, c =>
      '%' + c.charCodeAt(0).toString(16).toUpperCase()
    );
  },

  // Crypto helpers using Web Crypto API
  async hmac(key, data) {
    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      key instanceof ArrayBuffer ? key : new TextEncoder().encode(key),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );
    return crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(data));
  },

  async hmacHex(key, data) {
    const sig = await this.hmac(key, data);
    return Array.from(new Uint8Array(sig))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
  },

  async sha256hex(data) {
    const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
    return Array.from(new Uint8Array(hash))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
  },

  async getSignatureKey(key, dateStamp, region, service) {
    let k = await this.hmac('AWS4' + key, dateStamp);
    k = await this.hmac(k, region);
    k = await this.hmac(k, service);
    k = await this.hmac(k, 'aws4_request');
    return k;
  },
};
