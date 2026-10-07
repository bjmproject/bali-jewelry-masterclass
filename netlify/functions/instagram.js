const fields = ['id', 'media_type', 'media_url', 'thumbnail_url', 'permalink', 'timestamp'];

function json(statusCode, payload, extraHeaders = {}) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      ...extraHeaders,
    },
    body: JSON.stringify(payload),
  };
}

exports.handler = async (event) => {
  if (event.httpMethod !== 'GET') {
    return json(405, { error: 'Method not allowed.' }, { Allow: 'GET' });
  }

  const token = process.env.INSTAGRAM_ACCESS_TOKEN;
  if (!token || !token.trim()) {
    return json(503, { error: 'Instagram feed is not configured.' });
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20000);
  try {
    const url = new URL('https://graph.instagram.com/me/media');
    url.searchParams.set('fields', fields.join(','));
    url.searchParams.set('limit', '24');
    url.searchParams.set('access_token', token);

    const response = await fetch(url, { signal: controller.signal, redirect: 'error' });
    if (!response.ok) throw new Error('Instagram request failed');
    const result = await response.json();
    if (!Array.isArray(result.data)) throw new Error('Invalid Instagram response');

    const data = result.data.slice(0, 24).map((item) =>
      Object.fromEntries(fields.map((field) => [field, typeof item[field] === 'string' ? item[field] : null]))
    );
    return json(200, { data });
  } catch {
    // Never return or log upstream errors: they may contain credentials.
    return json(502, { error: 'Unable to fetch Instagram media.' });
  } finally {
    clearTimeout(timeout);
  }
};
