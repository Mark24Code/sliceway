import { atom } from 'jotai';
import type { Project, Layer } from '../types';

export const projectAtom = atom<Project | null>(null);
export const layersAtom = atom<Layer[]>([]);
export const scannerPositionAtom = atom<number>(0);
export const selectedLayerIdsAtom = atom<number[]>([]);
export const hoverLayerIdAtom = atom<number | null>(null);

// 全局Loading状态管理
export const globalLoadingAtom = atom<boolean>(false);
