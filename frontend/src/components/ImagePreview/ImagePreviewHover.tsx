import React, { useState, useRef, useCallback, useEffect } from 'react';

interface ImagePreviewHoverProps {
  src: string;
  alt?: string;
  children: React.ReactElement;
  maxWidth?: number;
  maxHeight?: number;
  delay?: number;
  offset?: { x: number; y: number };
  // 新增图片信息
  layerInfo?: {
    id: number;
    name: string;
    layer_type: string;
    width: number;
    height: number;
  };
}

export const ImagePreviewHover: React.FC<ImagePreviewHoverProps> = ({
  src,
  alt = '预览图片',
  children,
  maxWidth = 500,
  maxHeight = 400,
  delay = 300,
  offset = { x: 10, y: 10 },
  layerInfo
}) => {
  const [isVisible, setIsVisible] = useState(false);
  const [position, setPosition] = useState({ x: -9999, y: -9999 }); // 初始位置设为屏幕外
  const [imageSize, setImageSize] = useState({ width: 0, height: 0 });
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const imgRef = useRef<HTMLImageElement>(null);

  // 计算显示位置
  const calculatePosition = useCallback((mouseX: number, mouseY: number) => {
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    // 使用实际图片尺寸或预设最大值
    const displayWidth = Math.min(imageSize.width || maxWidth, maxWidth);
    const displayHeight = Math.min(imageSize.height || maxHeight, maxHeight);

    // 计算右下方位置
    const x = mouseX + offset.x;
    const y = mouseY + offset.y;

    // 边界检查，确保不超出视口
    const adjustedX = x + displayWidth > viewportWidth
      ? viewportWidth - displayWidth - 10
      : x;
    const adjustedY = y + displayHeight > viewportHeight
      ? viewportHeight - displayHeight - 10
      : y;

    return { x: adjustedX, y: adjustedY };
  }, [imageSize, maxWidth, maxHeight, offset]);

  // 鼠标事件处理
  const handleMouseEnter = useCallback((e: React.MouseEvent) => {
    // 捕获鼠标位置并立即计算
    const initialPosition = calculatePosition(e.clientX, e.clientY);
    setPosition(initialPosition);

    timeoutRef.current = setTimeout(() => setIsVisible(true), delay);
  }, [delay, calculatePosition]);

  const handleMouseLeave = useCallback(() => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
      timeoutRef.current = null;
    }
    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
      debounceRef.current = null;
    }
    setIsVisible(false);
  }, []);

  const handleMouseMove = useCallback((e: React.MouseEvent) => {
    if (!isVisible) return;

    // 清除之前的防抖
    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }

    // 设置新的防抖
    debounceRef.current = setTimeout(() => {
      setPosition(calculatePosition(e.clientX, e.clientY));
    }, 16); // 约60fps的防抖间隔
  }, [isVisible, calculatePosition]);

  // 图片加载处理
  const handleImageLoad = useCallback(() => {
    if (imgRef.current) {
      setImageSize({
        width: imgRef.current.naturalWidth,
        height: imgRef.current.naturalHeight
      });
    }
  }, []);

  // 清理定时器
  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
      if (debounceRef.current) {
        clearTimeout(debounceRef.current);
      }
    };
  }, []);

  return (
    <>
      {React.cloneElement(children as React.ReactElement<any>, {
        onMouseEnter: handleMouseEnter,
        onMouseLeave: handleMouseLeave,
        onMouseMove: handleMouseMove
      })}

      {isVisible && (
        <div
          className="image-preview-hover"
          style={{
            position: 'fixed',
            left: position.x,
            top: position.y,
            zIndex: 9999,
            background: 'white',
            borderRadius: '8px',
            boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)',
            border: '1px solid #e8e8e8',
            overflow: 'hidden',
            maxWidth: maxWidth,
            maxHeight: maxHeight
          }}
        >
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              background: `
                linear-gradient(45deg, #ccc 25%, transparent 25%),
                linear-gradient(-45deg, #ccc 25%, transparent 25%),
                linear-gradient(45deg, transparent 75%, #ccc 75%),
                linear-gradient(-45deg, transparent 75%, #ccc 75%)
              `,
              backgroundSize: '16px 16px',
              backgroundPosition: '0 0, 0 8px, 8px -8px, -8px 0px'
            }}
          >
            <img
              ref={imgRef}
              src={src}
              alt={alt}
              style={{
                display: 'block',
                maxWidth: maxWidth,
                maxHeight: maxHeight,
                objectFit: 'contain'
              }}
              onLoad={handleImageLoad}
            />
          </div>
          {layerInfo && (
            <div
              style={{
                padding: '8px 12px',
                background: '#f8f9fa',
                borderTop: '1px solid #e8e8e8',
                fontSize: '12px',
                lineHeight: '1.4'
              }}
            >
              <div><strong>ID:</strong> {layerInfo.id}</div>
              <div><strong>名称:</strong> {layerInfo.name}</div>
              <div><strong>类型:</strong> {layerInfo.layer_type}</div>
              <div><strong>尺寸:</strong> {layerInfo.width}×{layerInfo.height}</div>
            </div>
          )}
        </div>
      )}
    </>
  );
};