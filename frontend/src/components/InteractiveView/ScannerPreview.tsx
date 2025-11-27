import React, { useRef } from 'react';
import { useAtom, useAtomValue } from 'jotai';
import { projectAtom, scannerPositionAtom, hoverLayerIdAtom, layersAtom, previewZoomAtom } from '../../store/atoms';
import { IMAGE_BASE_URL } from '../../config';

const ScannerPreview: React.FC = () => {
    const [project] = useAtom(projectAtom);
    const [layers] = useAtom(layersAtom);
    const [, setScannerPosition] = useAtom(scannerPositionAtom);
    const [hoverLayerId] = useAtom(hoverLayerIdAtom);
    const zoom = useAtomValue(previewZoomAtom);
    const containerRef = useRef<HTMLDivElement>(null);
    const imgRef = useRef<HTMLImageElement>(null);

    const handleScroll = () => {
        if (containerRef.current) {
            setScannerPosition(containerRef.current.scrollTop);
        }
    };

    const hoverLayer = layers.find(l => l.id === hoverLayerId);

    if (!project) return null;

    return (
        <div
            ref={containerRef}
            onScroll={handleScroll}
            className="scanner-preview"
        >
            <div style={{ position: 'relative' }}>
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

                {/* Highlight Box */}
                {hoverLayer && (
                    <div
                        className="highlight-box"
                        style={{
                            left: hoverLayer.x * zoom,
                            top: hoverLayer.y * zoom,
                            width: hoverLayer.width * zoom,
                            height: hoverLayer.height * zoom,
                        }}
                    />
                )}
            </div>

            {/* Red Line Overlay */}
            <div className="scanner-line" />
        </div>
    );
};

export default ScannerPreview;
