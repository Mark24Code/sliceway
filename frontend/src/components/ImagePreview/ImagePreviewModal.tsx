import React, { useState, useRef, useCallback } from 'react';
import { Modal, Button } from 'antd';

interface ImagePreviewModalProps {
  visible: boolean;
  imageUrl: string;
  alt?: string;
  onClose: () => void;
  // 新增图片信息
  layerInfo?: {
    id: number;
    name: string;
    layer_type: string;
    width: number;
    height: number;
  };
}

export const ImagePreviewModal: React.FC<ImagePreviewModalProps> = ({
  visible,
  imageUrl,
  alt = '预览图片',
  onClose,
  layerInfo
}) => {
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [zoomLevel, setZoomLevel] = useState(1);
  const [isDragging, setIsDragging] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const [imagePosition, setImagePosition] = useState({ x: 0, y: 0 });
  const imageRef = useRef<HTMLImageElement>(null);

  // 缩放处理
  const handleZoom = useCallback((type: 'in' | 'out') => {
    setZoomLevel(prev => {
      const newZoom = type === 'in' ? prev * 1.2 : prev / 1.2;
      return Math.max(0.1, Math.min(5, newZoom));
    });
  }, []);

  // 下载处理
  const handleDownload = useCallback(() => {
    if (imageRef.current) {
      const link = document.createElement('a');
      link.href = imageUrl;
      link.download = 'preview-image.png';
      link.click();
    }
  }, [imageUrl]);

  // 拖拽处理
  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    if (zoomLevel > 1) {
      setIsDragging(true);
      setDragStart({ x: e.clientX - imagePosition.x, y: e.clientY - imagePosition.y });
    }
  }, [zoomLevel, imagePosition]);

  const handleMouseMove = useCallback((e: React.MouseEvent) => {
    if (isDragging && zoomLevel > 1) {
      setImagePosition({
        x: e.clientX - dragStart.x,
        y: e.clientY - dragStart.y
      });
    }
  }, [isDragging, zoomLevel, dragStart]);

  const handleMouseUp = useCallback(() => {
    setIsDragging(false);
  }, []);

  // 重置状态
  const handleClose = useCallback(() => {
    setIsFullscreen(false);
    setZoomLevel(1);
    setIsDragging(false);
    setImagePosition({ x: 0, y: 0 });
    onClose();
  }, [onClose]);

  return (
    <Modal
      title="图片预览"
      open={visible}
      onCancel={handleClose}
      footer={[
        <Button key="zoom-in" onClick={() => handleZoom('in')}>
          放大
        </Button>,
        <Button key="zoom-out" onClick={() => handleZoom('out')}>
          缩小
        </Button>,
        <Button key="fullscreen" onClick={() => setIsFullscreen(!isFullscreen)}>
          {isFullscreen ? '退出全屏' : '全屏'}
        </Button>,
        <Button key="download" onClick={handleDownload}>
          下载
        </Button>,
        <Button key="close" onClick={handleClose}>
          关闭
        </Button>
      ]}
      width={isFullscreen ? '100vw' : 800}
      style={isFullscreen ? { top: 0, margin: 0, maxWidth: '100vw' } : {}}
      className={isFullscreen ? 'preview-image-modal fullscreen' : 'preview-image-modal'}
    >
      <div style={{
        textAlign: 'center',
        height: isFullscreen ? 'calc(100vh - 108px)' : 'auto',
        overflow: 'auto',
        backgroundColor: '#f5f5f5',
        padding: isFullscreen ? 0 : 16
      }}>
        <img
          ref={imageRef}
          src={imageUrl}
          alt={alt}
          style={{
            maxWidth: isFullscreen ? '100%' : '100%',
            maxHeight: isFullscreen ? '100%' : '600px',
            transform: `scale(${zoomLevel})`,
            transition: 'transform 0.3s ease',
            cursor: zoomLevel > 1 ? 'grab' : 'default'
          }}
          onMouseDown={handleMouseDown}
          onMouseMove={handleMouseMove}
          onMouseUp={handleMouseUp}
        />
        {layerInfo && !isFullscreen && (
          <div
            style={{
              marginTop: '16px',
              padding: '12px 16px',
              background: 'white',
              borderRadius: '6px',
              border: '1px solid #e8e8e8',
              fontSize: '14px',
              lineHeight: '1.5',
              textAlign: 'left'
            }}
          >
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '16px' }}>
              <div><strong>ID:</strong> {layerInfo.id}</div>
              <div><strong>名称:</strong> {layerInfo.name}</div>
              <div><strong>类型:</strong> {layerInfo.layer_type}</div>
              <div><strong>尺寸:</strong> {layerInfo.width}×{layerInfo.height}</div>
            </div>
          </div>
        )}
      </div>
    </Modal>
  );
};