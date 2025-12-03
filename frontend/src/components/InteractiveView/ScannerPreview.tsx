import React, { useRef, useState, useEffect } from 'react';
import { useAtom, useAtomValue } from 'jotai';
import { projectAtom, scannerPositionAtom, previewZoomAtom } from '../../store/atoms';
import { IMAGE_BASE_URL } from '../../config';

const ScannerPreview: React.FC = () => {
    const [project] = useAtom(projectAtom);
    const [, setScannerPosition] = useAtom(scannerPositionAtom);
    const zoom = useAtomValue(previewZoomAtom);
    const [scannerWidth, setScannerWidth] = useState(0);
    const [scannerLeft, setScannerLeft] = useState(0);
    const containerRef = useRef<HTMLDivElement>(null);
    const imgRef = useRef<HTMLImageElement>(null);
    const [visualScannerY, setVisualScannerY] = useState(0)

    const handleScroll = () => {
        if (containerRef.current && imgRef.current) {
            const scrollTop = containerRef.current.scrollTop;
            const clientHeight = containerRef.current.clientHeight;
            const scrollHeight = containerRef.current.scrollHeight;
            const imageHeight = imgRef.current.naturalHeight;

            if (!imageHeight) return;

            // 计算滚动进度（0到1）
            const maxScroll = scrollHeight - clientHeight;
            const scrollProgress = maxScroll > 0 ? scrollTop / maxScroll : 0;

            // 扫描线在图片坐标系中的位置
            const realOffsetY = scrollProgress * imageHeight;
            setScannerPosition(realOffsetY);

            // 视觉位置：扫描线在可视区域中的位置
            const renderedImageHeight = imageHeight * zoom;

            if (renderedImageHeight <= clientHeight) {
                // 图片完全可见时：扫描线在图片内按比例移动
                setVisualScannerY(scrollProgress * renderedImageHeight);
            } else {
                // 图片需要滚动时：保持原有逻辑
                setVisualScannerY(scrollProgress * clientHeight);
            }
        }
    };



    useEffect(() => {
        if (containerRef.current) {
            const updateDimensions = () => {
                const previewContainer = containerRef.current?.querySelector('.preview-container');
                if (previewContainer) {
                    setScannerWidth(previewContainer.clientWidth);
                }

                // 计算容器相对于视口的左边距
                if (containerRef.current) {
                    const rect = containerRef.current.getBoundingClientRect();
                    setScannerLeft(rect.left);
                }
            };

            updateDimensions();
            window.addEventListener('resize', updateDimensions);

            // 使用 MutationObserver 监听布局变化
            const observer = new MutationObserver(updateDimensions);
            observer.observe(document.body, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['style', 'class']
            });

            return () => {
                window.removeEventListener('resize', updateDimensions);
                observer.disconnect();
            };
        }
    }, []);

    if (!project) return null;

    return (
        <div
            ref={containerRef}
            onScroll={handleScroll}
            className="scanner-preview"
        >
            <div className='preview-container' style={{ position: 'relative' }}>
                <img
                    ref={imgRef}
                    src={`${IMAGE_BASE_URL}/processed/${project.id}/full_preview.png`}
                    alt="完整预览"
                    style={{
                        display: 'block',
                        maxWidth: '100%',
                        transform: `scale(${zoom})`,
                        transformOrigin: 'top left',
                        width: `${100 / zoom}%`,
                        height: 'auto'
                    }}
                />
                <div
                    className="scanner-line"
                    style={{
                        top: `${visualScannerY}px`,
                        left: `${scannerLeft}px`,
                        width: scannerWidth > 0 ? `${scannerWidth}px` : '100%',
                        transform: 'none'
                    }}
                />
            </div>
        </div>
    );
};

export default ScannerPreview;
