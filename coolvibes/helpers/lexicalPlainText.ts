function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function looksLikeLexicalStateObject(value: unknown): boolean {
  if (!isRecord(value)) return false;
  // Lexical editor state is typically { root: { type: 'root', children: [...] } }
  const root = (value as any).root;
  return isRecord(root) && Array.isArray((root as any).children);
}

function safeJsonParse(input: string): unknown {
  try {
    return JSON.parse(input) as unknown;
  } catch {
    return null;
  }
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function maybeDecodeTagEntities(input: string): string {
  // If backend sends HTML as escaped entities, decode only the basics.
  // We do this conservatively and only if it seems to contain tags.
  if (!/&lt;\/?[a-zA-Z]/.test(input)) return input;
  return input
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
}

function looksLikeHtmlString(input: string): boolean {
  const s = input.trim();
  if (!s) return false;
  // Basic heuristic: contains a tag-like pattern
  return /<\s*\/?\s*[a-zA-Z][^>]*>/.test(s);
}

const ALLOWED_TAGS = new Set([
  'p',
  'br',
  'strong',
  'b',
  'em',
  'i',
  'u',
  's',
  'code',
  'blockquote',
  'ul',
  'ol',
  'li',
  'a',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
]);

function sanitizeHtmlAllowlist(html: string): string {
  // Remove script/style blocks entirely.
  let out = html.replace(/<\s*(script|style)[^>]*>[\s\S]*?<\s*\/\s*\1\s*>/gi, '');

  // Strip comments.
  out = out.replace(/<!--[\s\S]*?-->/g, '');

  // Sanitize tags/attributes with a simple allowlist.
  out = out.replace(/<\s*\/?\s*([a-zA-Z0-9]+)([^>]*)>/g, (match, rawName: string, rawAttrs: string) => {
    const name = String(rawName).toLowerCase();
    const isClosing = /^<\s*\//.test(match);
    if (!ALLOWED_TAGS.has(name)) {
      return '';
    }

    if (isClosing) {
      return `</${name}>`;
    }

    if (name === 'br') {
      return '<br/>';
    }

    if (name === 'a') {
      const hrefMatch = rawAttrs.match(/\bhref\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+))/i);
      const href = hrefMatch ? (hrefMatch[2] ?? hrefMatch[3] ?? hrefMatch[4] ?? '') : '';
      const safeHref = href.startsWith('http://') || href.startsWith('https://') || href.startsWith('mailto:') ? href : '';
      return safeHref ? `<a href="${escapeHtml(safeHref)}">` : '<a>';
    }

    // No other attributes allowed.
    return `<${name}>`;
  });

  return out.trim();
}

function extractTextFromNode(node: unknown, out: string[], depth: number) {
  if (depth > 50) return;
  if (!isRecord(node)) return;

  const type = node.type;
  if (type === 'text') {
    const text = node.text;
    if (typeof text === 'string' && text) {
      out.push(text);
    }
    return;
  }

  // Some Lexical exports may encode breaks as nodes.
  if (type === 'linebreak') {
    out.push('\n');
    return;
  }

  const children = node.children;
  if (Array.isArray(children)) {
    for (const child of children) {
      extractTextFromNode(child, out, depth + 1);
    }

    // Add paragraph-like separation when we finish a block node.
    if (type === 'paragraph' || type === 'heading' || type === 'quote' || type === 'listitem') {
      out.push('\n');
    }
  }
}

// Lexical text formatting bitmask (common subset)
// https://lexical.dev/docs/concepts/serialization (format is a number bitmask)
const FORMAT_BOLD = 1;
const FORMAT_ITALIC = 1 << 1; // 2
const FORMAT_UNDERLINE = 1 << 2; // 4
const FORMAT_STRIKETHROUGH = 1 << 3; // 8
const FORMAT_CODE = 1 << 4; // 16

function wrapWithMarks(textHtml: string, format: unknown): string {
  const fmt = typeof format === 'number' ? format : 0;
  let html = textHtml;
  if (fmt & FORMAT_CODE) html = `<code>${html}</code>`;
  if (fmt & FORMAT_STRIKETHROUGH) html = `<s>${html}</s>`;
  if (fmt & FORMAT_UNDERLINE) html = `<u>${html}</u>`;
  if (fmt & FORMAT_ITALIC) html = `<em>${html}</em>`;
  if (fmt & FORMAT_BOLD) html = `<strong>${html}</strong>`;
  return html;
}

function extractHtmlFromNode(node: unknown, out: string[], depth: number) {
  if (depth > 50) return;
  if (!isRecord(node)) return;

  const type = node.type;
  if (type === 'text') {
    const text = typeof node.text === 'string' ? node.text : '';
    const escaped = escapeHtml(text);
    out.push(wrapWithMarks(escaped, (node as any).format));
    return;
  }

  if (type === 'linebreak') {
    out.push('<br/>');
    return;
  }

  if (type === 'link') {
    const url = typeof (node as any).url === 'string' ? (node as any).url : '';
    const safeUrl = escapeHtml(url);
    out.push(`<a href="${safeUrl}">`);
    const children = (node as any).children;
    if (Array.isArray(children)) {
      for (const child of children) extractHtmlFromNode(child, out, depth + 1);
    }
    out.push('</a>');
    return;
  }

  const children = (node as any).children;

  // Block wrappers
  if (type === 'paragraph') {
    out.push('<p>');
    if (Array.isArray(children)) for (const child of children) extractHtmlFromNode(child, out, depth + 1);
    out.push('</p>');
    return;
  }

  if (type === 'heading') {
    const tag = typeof (node as any).tag === 'string' ? (node as any).tag : 'h2';
    const safeTag = /^h[1-6]$/.test(tag) ? tag : 'h2';
    out.push(`<${safeTag}>`);
    if (Array.isArray(children)) for (const child of children) extractHtmlFromNode(child, out, depth + 1);
    out.push(`</${safeTag}>`);
    return;
  }

  if (type === 'quote') {
    out.push('<blockquote>');
    if (Array.isArray(children)) for (const child of children) extractHtmlFromNode(child, out, depth + 1);
    out.push('</blockquote>');
    return;
  }

  if (type === 'list') {
    const listType = (node as any).listType;
    const tag = listType === 'number' ? 'ol' : 'ul';
    out.push(`<${tag}>`);
    if (Array.isArray(children)) for (const child of children) extractHtmlFromNode(child, out, depth + 1);
    out.push(`</${tag}>`);
    return;
  }

  if (type === 'listitem') {
    out.push('<li>');
    if (Array.isArray(children)) for (const child of children) extractHtmlFromNode(child, out, depth + 1);
    out.push('</li>');
    return;
  }

  // Root or unknown container: just recurse.
  if (Array.isArray(children)) {
    for (const child of children) extractHtmlFromNode(child, out, depth + 1);
  }
}

/**
 * Convert a Lexical editor state (JSON object or JSON string) into plain text.
 * If input is not Lexical state, returns null.
 */
export function lexicalToPlainText(input: unknown): string | null {
  let value: unknown = input;
  if (typeof input === 'string') {
    const trimmed = input.trim();
    // Fast path: most bios are not JSON.
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) {
      return null;
    }
    value = safeJsonParse(trimmed);
  }

  if (!looksLikeLexicalStateObject(value)) {
    return null;
  }

  const root = (value as any).root;
  const out: string[] = [];
  extractTextFromNode(root, out, 0);

  const text = out.join('');
  // Normalize whitespace/newlines.
  const normalized = text
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

  return normalized || '';
}

/**
 * Convert a Lexical editor state (JSON object or JSON string) into HTML.
 * If input is not Lexical state, returns null.
 */
export function lexicalToHtml(input: unknown): string | null {
  let value: unknown = input;
  if (typeof input === 'string') {
    const trimmed = input.trim();
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) {
      return null;
    }
    value = safeJsonParse(trimmed);
  }

  if (!looksLikeLexicalStateObject(value)) {
    return null;
  }

  const root = (value as any).root;
  const out: string[] = [];
  extractHtmlFromNode(root, out, 0);

  const html = out.join('').trim();
  return html || '<p></p>';
}

/**
 * Coerce unknown rich text into safe HTML.
 * - Lexical JSON -> HTML
 * - Plain text -> escaped HTML inside <p>
 */
export function toSafeBioHtml(input: unknown): string {
  if (input == null) return '';
  if (typeof input === 'string') {
    const decoded = maybeDecodeTagEntities(input);
    const lexicalHtml = lexicalToHtml(decoded);
    if (lexicalHtml != null) return lexicalHtml;
    const trimmed = decoded.trim();
    if (!trimmed) return '';
    if (looksLikeHtmlString(trimmed)) {
      return sanitizeHtmlAllowlist(trimmed);
    }
    return `<p>${escapeHtml(trimmed)}</p>`;
  }

  // If it’s already an object, try lexical directly.
  const lexicalHtml = lexicalToHtml(input);
  if (lexicalHtml != null) return lexicalHtml;
  return '';
}

