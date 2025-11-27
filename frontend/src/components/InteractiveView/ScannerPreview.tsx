import React, { useRef, useState, useEffect } from 'react';
import { useAtom, useAtomValue } from 'jotai';
import { projectAtom, scannerPositionAtom, previewZoomAtom } from '../../store/atoms';
import { IMAGE_BASE_URL } from '../../config';

const ScannerPreview: React.FC = () => {
    const [project] = useAtom(projectAtom);
    const [, setScannerPosition] = useAtom(scannerPositionAtom);
    const zoom = useAtomValue(previewZoomAtom);
    const [scannerWidth, setScannerWidth] = useState(0);
    const containerRef = useRef<HTMLDivElement>(null);
    const imgRef = useRef<HTMLImageElement>(null);

    const handleScroll = () => {
        if (containerRef.current && imgRef.current) {
            const scrollTop = containerRef.current.scrollTop;
            const containerHeight = containerRef.current.clientHeight;

            // 计算扫描线在图片上的实际位置
            // 扫描线在容器中间 (50%)，加上滚动偏移
            const scanLineImageY = scrollTop + (containerHeight / 2);

            // 考虑缩放级别
            const actualScanLineY = scanLineImageY / zoom;

            setScannerPosition(actualScanLineY);
        }
    };

    useEffect(() => {
        if (containerRef.current) {
            const updateWidth = () => {
                const previewContainer = containerRef.current?.querySelector('.preview-container');
                if (previewContainer) {
                    setScannerWidth(previewContainer.clientWidth);
                }
            };

            updateWidth();
            window.addEventListener('resize', updateWidth);
            return () => window.removeEventListener('resize', updateWidth);
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
            </div>
            <div
                className="scanner-line"
                style={{
                    width: scannerWidth > 0 ? `${scannerWidth}px` : '100%'
                }}
            />
        </div>
    );
};

export default ScannerPreview;
