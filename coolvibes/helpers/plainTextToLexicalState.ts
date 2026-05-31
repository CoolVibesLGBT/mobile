type ComposerContentMedia = {
  type?: string;
  name?: string;
  data?: any;
};

const createTextNode = (text: string) => ({
  detail: 0,
  format: 0,
  mode: 'normal',
  style: '',
  text,
  type: 'text',
  version: 1,
});

const createParagraphNode = (children: any[] = []) => ({
  children,
  direction: null,
  format: '',
  indent: 0,
  type: 'paragraph',
  version: 1,
  textFormat: 0,
  textStyle: '',
});

const createEmptyEditorState = () => ({
  root: {
    children: [],
    direction: null,
    format: '',
    indent: 0,
    type: 'root',
    version: 1,
  },
});

const resolveStickerPath = (media: ComposerContentMedia): string => {
  const source = media.data ?? {};

  if (typeof source.stickerPath === 'string' && source.stickerPath.trim()) {
    return source.stickerPath.trim();
  }

  const stickerUrl =
    typeof source.stickerUrl === 'string' && source.stickerUrl.trim()
      ? source.stickerUrl.trim()
      : '';
  if (!stickerUrl) return '';

  try {
    const parsed = new URL(stickerUrl);
    return parsed.pathname || '';
  } catch {
    return stickerUrl.startsWith('/') ? stickerUrl : '';
  }
};

const createStickerNode = (media: ComposerContentMedia) => {
  const src = resolveStickerPath(media);
  if (!src) return null;

  return {
    altText:
      (typeof media.data?.label === 'string' && media.data.label.trim()) ||
      (typeof media.name === 'string' && media.name.trim()) ||
      'Sticker',
    caption: {
      editorState: createEmptyEditorState(),
    },
    height: '100%',
    maxWidth: 500,
    showCaption: false,
    src,
    type: 'image',
    version: 1,
    width: '100%',
  };
};

export function composeLexicalState(
  text: string,
  media: ComposerContentMedia[] = [],
): string {
  const safe = String(text ?? '').replace(/\r\n/g, '\n');
  const hasText = safe.length > 0;
  const children: any[] = [];

  if (hasText) {
    safe.split('\n').forEach((line) => {
      children.push(createParagraphNode(line ? [createTextNode(line)] : []));
    });
  }

  media.forEach((item) => {
    if (item?.type !== 'sticker') return;
    const stickerNode = createStickerNode(item);
    if (!stickerNode) return;
    children.push(createParagraphNode([stickerNode]));
    children.push(createParagraphNode());
  });

  if (children.length === 0) {
    children.push(createParagraphNode());
  }

  return JSON.stringify({
    root: {
      children,
      direction: null,
      format: '',
      indent: 0,
      type: 'root',
      version: 1,
    },
  });
}

export function plainTextToLexicalState(text: string): string {
  return composeLexicalState(text, []);
}
