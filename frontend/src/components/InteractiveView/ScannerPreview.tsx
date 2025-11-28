import React, { useRef, useState, useEffect } from 'react';
import { useAtom, useAtomValue } from 'jotai';
import { projectAtom, scannerPositionAtom, previewZoomAtom } from '../../store/atoms';
import { IMAGE_BASE_URL } from '../../config';

const ScannerPreview: React.FC = () => {
    const [project] = useAtom(projectAtom);
    const [scannerY, setScannerPosition] = useAtom(scannerPositionAtom);
    const zoom = useAtomValue(previewZoomAtom);
    const [scannerWidth, setScannerWidth] = useState(0);
    const containerRef = useRef<HTMLDivElement>(null);
    const imgRef = useRef<HTMLImageElement>(null);
    const [visualScannerY, setVisualScannerY] = useState(0)

    const handleScroll = () => {
        if (containerRef.current && imgRef.current) {
            // 因为容器的高度其实是图片高度决定的，zoom：100% 就是图片高度
            // 偏移位置就是滚动条位置就是人的注意力位置
            // 当比例缩小的时候，图片在原位置缩小，等价于 滚动条变大了，所以处以比例，换算到图片偏移比例 
            const scrollTop = containerRef.current.scrollTop;
            const clientHeight = containerRef.current.clientHeight;
            // 等价图片偏移距离 
            const realOffsetY = scrollTop / zoom;
            setScannerPosition(realOffsetY);

            // 视觉的线是根据 fixed 换算成 viewport 的移动距离
            const imageHeight = imgRef.current?.naturalHeight
            if (imageHeight) {
                const ratio = realOffsetY < imageHeight ? realOffsetY / imageHeight : 1
                setVisualScannerY(ratio * clientHeight)
            }

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
                <div
                    className="scanner-line"
                    style={{
                        top: `${visualScannerY}px`,
                        width: scannerWidth > 0 ? `${scannerWidth}px` : '100%'
                    }}
                />
            </div>
        </div>
    );
};

export default ScannerPreview;
