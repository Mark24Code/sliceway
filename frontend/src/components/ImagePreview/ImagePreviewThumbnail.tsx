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
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        maxWidth: width,
        maxHeight: height,
        background: `
          linear-gradient(45deg, #ccc 25%, transparent 25%),
          linear-gradient(-45deg, #ccc 25%, transparent 25%),
          linear-gradient(45deg, transparent 75%, #ccc 75%),
          linear-gradient(-45deg, transparent 75%, #ccc 75%)
        `,
        backgroundSize: '8px 8px',
        backgroundPosition: '0 0, 0 4px, 4px -4px, -4px 0px',
        cursor: onClick ? 'pointer' : 'default'
      }}
      onClick={onClick}
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
      onMouseMove={onMouseMove}
    >
      <img
        src={src}
        alt={alt}
        style={{
          maxWidth: width,
          maxHeight: height,
          display: 'block'
        }}
      />
    </div>
  );
};