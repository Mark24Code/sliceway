export interface ImagePreviewProps {
  src: string;
  alt?: string;
  width?: number;
  height?: number;
  zoomable?: boolean;
  downloadable?: boolean;
  onClose?: () => void;
}

export interface ImagePreviewHoverProps {
  src: string;
  alt?: string;
  children: React.ReactElement;
  maxWidth?: number;
  maxHeight?: number;
  delay?: number;
  offset?: { x: number; y: number };
}