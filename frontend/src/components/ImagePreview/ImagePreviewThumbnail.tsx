import React from 'react';

interface ImagePreviewThumbnailProps {
  src: string;
  alt: string;
  width?: number;
  height?: number;
  onClick?: () => void;
  onMouseEnter?: () => void;
  onMouseLeave?: () => void;
  onMouseMove?: (e: React.MouseEvent) => void;
}

export const ImagePreviewThumbnail: React.FC<ImagePreviewThumbnailProps> = ({
  src,
  alt,
  width = 40,
  height = 40,
  onClick,
  onMouseEnter,
  onMouseLeave,
  onMouseMove
}) => {
  return (
    <img
      src={src}
      alt={alt}
      style={{
        maxWidth: width,
        maxHeight: height,
        cursor: onClick ? 'pointer' : 'default'
      }}
      onClick={onClick}
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
      onMouseMove={onMouseMove}
    />
  );
};