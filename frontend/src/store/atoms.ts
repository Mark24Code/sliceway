import { atom } from 'jotai';
import type { Project, Layer } from '../types';

export const projectAtom = atom<Project | null>(null);
export const layersAtom = atom<Layer[]>([]);
export const scannerPositionAtom = atom<number>(0);
export const selectedLayerIdsAtom = atom<number[]>([]);
export const hoverLayerIdAtom = atom<number | null>(null);

// 全局Loading状态管理
export const globalLoadingAtom = atom<boolean>(false);

// 预览缩放状态管理
export const previewZoomAtom = atom<number>(0.5); // 1 = 100%, 0.75 = 75%, 0.5 = 50% (默认 50%)
