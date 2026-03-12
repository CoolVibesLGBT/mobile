import React, { useEffect, useRef, useState } from 'react';
import { Image as RNImage, StyleSheet } from 'react-native';
import { Asset } from 'expo-asset';
import { GLView, ExpoWebGLRenderingContext } from 'expo-gl';

import type { VibeItemData } from './types';

const VERTEX_SHADER_SOURCE = `
attribute vec4 a_position;
attribute vec2 a_texcoord;
varying vec2 v_texcoord;
void main() {
  gl_Position = a_position;
  v_texcoord = a_texcoord;
}
`;

const FRAGMENT_SHADER_SOURCE = `
precision highp float;
varying vec2 v_texcoord;

uniform sampler2D u_tex_from;
uniform sampler2D u_tex_to;
uniform vec2 u_resolution;
uniform vec2 u_res_from;
uniform vec2 u_res_to;
uniform float u_progress;
uniform float u_velocity;

vec2 getCoverUv(vec2 uv, vec2 planeRes, vec2 mediaRes) {
  vec2 ratio = vec2(
    min((planeRes.x / planeRes.y) / (mediaRes.x / mediaRes.y), 1.0),
    min((planeRes.y / planeRes.x) / (mediaRes.y / mediaRes.x), 1.0)
  );
  return uv * ratio + (1.0 - ratio) * 0.5;
}

void main() {
  float distortion = clamp(abs(u_velocity) * 0.05, 0.0, 0.1);

  vec2 centeredUv = v_texcoord - 0.5;
  float radius = length(centeredUv);
  float distortionFactor = smoothstep(0.0, 0.5, radius);
  vec2 distortedUv = centeredUv + normalize(centeredUv) * distortion * distortionFactor * sin(radius * 10.0 - u_progress * 3.14159);
  distortedUv += 0.5;

  vec2 uv_from = distortedUv;
  uv_from.y -= u_progress;

  vec2 uv_to = distortedUv;
  uv_to.y += (1.0 - u_progress);

  vec2 cover_uv_from = getCoverUv(uv_from, u_resolution, u_res_from);
  vec2 cover_uv_to = getCoverUv(uv_to, u_resolution, u_res_to);

  vec2 half_texel_from = 0.5 / u_res_from;
  vec2 half_texel_to = 0.5 / u_res_to;

  vec2 clamped_uv_from = clamp(cover_uv_from, half_texel_from, 1.0 - half_texel_from);
  vec2 clamped_uv_to = clamp(cover_uv_to, half_texel_to, 1.0 - half_texel_to);

  vec4 color_from = texture2D(u_tex_from, clamped_uv_from);
  vec4 color_to = texture2D(u_tex_to, clamped_uv_to);

  float fade_progress = smoothstep(0.0, 1.0, u_progress);
  gl_FragColor = mix(color_from, color_to, fade_progress);
}
`;

type PositionState = {
  current: number;
  target: number;
  velocity: number;
};

interface LoadedTexture {
  texture: WebGLTexture | null;
  resolution: [number, number];
  isReady: boolean;
}

interface VibesGLRendererProps {
  vibes: VibeItemData[];
  positionRef: React.MutableRefObject<PositionState>;
  opacity: number;
}

function createShader(gl: ExpoWebGLRenderingContext, type: number, source: string) {
  const shader = gl.createShader(type);
  if (!shader) {
    return null;
  }
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    return shader;
  }
  console.error('VibesGL shader compile error', gl.getShaderInfoLog(shader));
  gl.deleteShader(shader);
  return null;
}

function createProgram(gl: ExpoWebGLRenderingContext, vertexShader: WebGLShader, fragmentShader: WebGLShader) {
  const program = gl.createProgram();
  if (!program) {
    return null;
  }
  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);
  if (gl.getProgramParameter(program, gl.LINK_STATUS)) {
    return program;
  }
  console.error('VibesGL program link error', gl.getProgramInfoLog(program));
  gl.deleteProgram(program);
  return null;
}

async function getImageSize(uri: string): Promise<[number, number]> {
  return await new Promise((resolve) => {
    RNImage.getSize(
      uri,
      (width, height) => resolve([width, height]),
      () => resolve([1, 1])
    );
  });
}

export function VibesGLRenderer({ vibes, positionRef, opacity }: VibesGLRendererProps) {
  const glRef = useRef<ExpoWebGLRenderingContext | null>(null);
  const programRef = useRef<WebGLProgram | null>(null);
  const animationFrameRef = useRef<number>(0);
  const texturesRef = useRef<LoadedTexture[]>([]);
  const vibesRef = useRef<VibeItemData[]>(vibes);
  const readyRef = useRef(false);
  const [contextReady, setContextReady] = useState(false);
  const prevVibesLengthRef = useRef(0);
  const prevFirstIdRef = useRef<string | null>(null);

  useEffect(() => {
    vibesRef.current = vibes;
  }, [contextReady, vibes]);

  useEffect(() => {
    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, []);

  useEffect(() => {
    const gl = glRef.current;
    if (!gl || !readyRef.current) {
      return;
    }

    let cancelled = false;

    const loadTextures = async () => {
      const prevLen = prevVibesLengthRef.current;
      const prevFirstId = prevFirstIdRef.current;
      const nextFirstId = vibes[0]?.id ?? null;

      const isAppend =
        prevLen > 0 &&
        vibes.length > prevLen &&
        texturesRef.current.length === prevLen &&
        prevFirstId != null &&
        nextFirstId === prevFirstId;

      const createPlaceholderTexture = () => {
        const texture = gl.createTexture();
        if (!texture) {
          console.warn('VibesGL texture creation failed; falling back to native media for this frame');
          return {
            texture: null,
            resolution: [1, 1] as [number, number],
            isReady: false,
          };
        }
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 255]));
        return {
          texture,
          resolution: [1, 1] as [number, number],
          isReady: false,
        };
      };

      let nextTextures: LoadedTexture[];
      let loadTargets: { vibe: VibeItemData; index: number }[];

      if (isAppend) {
        const existing = texturesRef.current;
        const toAddCount = vibes.length - existing.length;
        const additions = Array.from({ length: toAddCount }, () => createPlaceholderTexture());
        nextTextures = [...existing, ...additions];
        texturesRef.current = nextTextures;
        loadTargets = vibes.slice(existing.length).map((vibe, idx) => ({ vibe, index: existing.length + idx }));
      } else {
        texturesRef.current.forEach((item) => {
          if (item.texture) {
            gl.deleteTexture(item.texture);
          }
        });
        nextTextures = vibes.map(() => createPlaceholderTexture());
        texturesRef.current = nextTextures;
        loadTargets = vibes.map((vibe, index) => ({ vibe, index }));
      }

      prevVibesLengthRef.current = vibes.length;
      prevFirstIdRef.current = nextFirstId;

      await Promise.all(
        loadTargets.map(async ({ vibe, index }) => {
          const sourceUri = vibe.mediaType === 'video' ? vibe.posterUrl || vibe.mediaUrl : vibe.mediaUrl;
          if (!sourceUri) {
            return;
          }

          try {
            const asset = Asset.fromURI(sourceUri);
            await asset.downloadAsync();
            const uri = asset.localUri || asset.uri;
            const size = await getImageSize(uri);
            if (cancelled) {
              return;
            }

            if (!nextTextures[index] || !nextTextures[index].texture) {
              return;
            }

            gl.bindTexture(gl.TEXTURE_2D, nextTextures[index].texture);
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, asset as never);
            nextTextures[index].resolution = size;
            nextTextures[index].isReady = true;
          } catch (error) {
            console.error('VibesGL texture load failed', error);
          }
        })
      );
    };

    void loadTextures();

    return () => {
      cancelled = true;
    };
  }, [vibes]);

  const handleContextCreate = async (gl: ExpoWebGLRenderingContext) => {
    glRef.current = gl;

    const vertexShader = createShader(gl, gl.VERTEX_SHADER, VERTEX_SHADER_SOURCE);
    const fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, FRAGMENT_SHADER_SOURCE);
    if (!vertexShader || !fragmentShader) {
      return;
    }

    const program = createProgram(gl, vertexShader, fragmentShader);
    if (!program) {
      return;
    }
    programRef.current = program;

    const positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]), gl.STATIC_DRAW);

    const texcoordBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, texcoordBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0]), gl.STATIC_DRAW);

    const positionAttributeLocation = gl.getAttribLocation(program, 'a_position');
    gl.enableVertexAttribArray(positionAttributeLocation);
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.vertexAttribPointer(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0);

    const texcoordAttributeLocation = gl.getAttribLocation(program, 'a_texcoord');
    gl.enableVertexAttribArray(texcoordAttributeLocation);
    gl.bindBuffer(gl.ARRAY_BUFFER, texcoordBuffer);
    gl.vertexAttribPointer(texcoordAttributeLocation, 2, gl.FLOAT, false, 0, 0);

    readyRef.current = true;
    setContextReady(true);

    const texFromLocation = gl.getUniformLocation(program, 'u_tex_from');
    const texToLocation = gl.getUniformLocation(program, 'u_tex_to');
    const resLocation = gl.getUniformLocation(program, 'u_resolution');
    const resFromLocation = gl.getUniformLocation(program, 'u_res_from');
    const resToLocation = gl.getUniformLocation(program, 'u_res_to');
    const progressLocation = gl.getUniformLocation(program, 'u_progress');
    const velocityLocation = gl.getUniformLocation(program, 'u_velocity');

      const render = () => {
      animationFrameRef.current = requestAnimationFrame(render);
      const currentVibes = vibesRef.current;

      gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
      gl.clearColor(0, 0, 0, 1);
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.useProgram(program);

      if (texturesRef.current.length === 0 || currentVibes.length === 0) {
        gl.endFrameEXP();
        return;
      }

      const p = positionRef.current.current;
      const fromIndex = Math.max(0, Math.min(currentVibes.length - 1, Math.floor(p)));
      const toIndex = Math.max(0, Math.min(currentVibes.length - 1, Math.ceil(p)));
      const progress = p - fromIndex;

      const fromItem = texturesRef.current[fromIndex];
      const toItem = texturesRef.current[toIndex];

      if (!fromItem || !toItem || !fromItem.texture || !toItem.texture || !fromItem.isReady || !toItem.isReady) {
        gl.endFrameEXP();
        return;
      }

      gl.uniform1i(texFromLocation, 0);
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, fromItem.texture);

      gl.uniform1i(texToLocation, 1);
      gl.activeTexture(gl.TEXTURE1);
      gl.bindTexture(gl.TEXTURE_2D, toItem.texture);

      gl.uniform2f(resLocation, gl.drawingBufferWidth, gl.drawingBufferHeight);
      gl.uniform2f(resFromLocation, fromItem.resolution[0], fromItem.resolution[1]);
      gl.uniform2f(resToLocation, toItem.resolution[0], toItem.resolution[1]);
      gl.uniform1f(progressLocation, progress);
      gl.uniform1f(velocityLocation, positionRef.current.velocity);

      gl.drawArrays(gl.TRIANGLES, 0, 6);
      gl.flush();
      gl.endFrameEXP();
    };

    render();
  };

  return <GLView style={[StyleSheet.absoluteFillObject, { opacity }]} onContextCreate={handleContextCreate} />;
}
