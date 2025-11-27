export interface ImagePreviewProps {
  src: string;
  alt?: string;
  width?: number;
  height?: number;
  zoomable?: boolean;
  downloadable?: boolean;
  onClose?: () => void;
}