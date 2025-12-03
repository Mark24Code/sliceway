import React, { useRef, useState, useEffect } from 'react';
import { useAtom, useAtomValue } from 'jotai';
import { projectAtom, scannerPositionAtom, previewZoomAtom } from '../../store/atoms';
import { IMAGE_BASE_URL } from '../../config';

const ScannerPreview: React.FC = () => {
    const [project] = useAtom(projectAtom);
    const [scannerPosition, setScannerPosition] = useAtom(scannerPositionAtom);
    const zoom = useAtomValue(previewZoomAtom);

    const containerRef = useRef<HTMLDivElement>(null);
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const [image, setImage] = useState<HTMLImageElement | null>(null);
    const [containerSize, setContainerSize] = useState({ width: 0, height: 0 });

    // Refs for event listeners to access latest state
    const stateRef = useRef({ scannerPosition, zoom, image });
    useEffect(() => {
        stateRef.current = { scannerPosition, zoom, image };
    }, [scannerPosition, zoom, image]);

    // Load Image
    useEffect(() => {
        if (!project) return;
        const img = new Image();
        img.src = `${IMAGE_BASE_URL}/processed/${project.id}/full_preview.png`;
        img.onload = () => {
            setImage(img);
        };
    }, [project]);

    // Resize Observer for Container
    useEffect(() => {
        if (!containerRef.current) return;
        const resizeObserver = new ResizeObserver((entries) => {
            for (const entry of entries) {
                setContainerSize({
                    width: entry.contentRect.width,
                    height: entry.contentRect.height
                });
            }
        });
        resizeObserver.observe(containerRef.current);
        return () => resizeObserver.disconnect();
    }, []);

    // Draw
    useEffect(() => {
        const canvas = canvasRef.current;
        const ctx = canvas?.getContext('2d');
        if (!canvas || !ctx || !image || containerSize.width === 0) return;

        // Set Canvas Size
        canvas.width = containerSize.width;
        canvas.height = containerSize.height;

        const { width: imgW, height: imgH } = image;
        const scaledW = imgW * zoom;
        const scaledH = imgH * zoom;

        // Calculate Positions
        let imageY = 0;
        let lineY = 0;

        if (scaledH <= containerSize.height) {
            // Image fits vertically - align to top
            imageY = 0;
            lineY = scannerPosition * zoom;
        } else {
            // Image needs scrolling
            // Logic: progress = scannerPosition / imgH
            // lineY = progress * containerSize.height
            // imageY = -progress * (scaledH - containerSize.height)

            // Ensure we don't divide by zero if imgH is 0 (unlikely)
            const progress = imgH > 0 ? scannerPosition / imgH : 0;
            lineY = progress * containerSize.height;
            imageY = -progress * (scaledH - containerSize.height);
        }

        // Center Horizontally
        const imageX = (containerSize.width - scaledW) / 2;

        // Clear
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        // Draw Image
        ctx.drawImage(image, imageX, imageY, scaledW, scaledH);

        // Draw Scanner Line
        ctx.save();
        ctx.strokeStyle = '#ff0000';
        ctx.lineWidth = 2;
        ctx.shadowColor = '#ff0000';
        ctx.shadowBlur = 10;

        ctx.beginPath();
        ctx.moveTo(0, lineY);
        ctx.lineTo(canvas.width, lineY);
        ctx.stroke();

        // Add extra glow
        ctx.shadowBlur = 20;
        ctx.stroke();

        ctx.restore();

    }, [image, containerSize, zoom, scannerPosition]);

    // Wheel Handler
    useEffect(() => {
        const canvas = canvasRef.current;
        if (!canvas) return;

        const handleWheel = (e: WheelEvent) => {
            e.preventDefault();

            const { scannerPosition, zoom, image } = stateRef.current;
            if (!image) return;

            const delta = e.deltaY;
            // Sensitivity: adjust as needed. 
            // Using delta / zoom means moving 1 screen pixel moves 1 image pixel (visually).
            // But since we are mapping scroll to scanner position, maybe we want a direct mapping?
            // Let's try delta / zoom.
            const moveAmount = delta / zoom;

            let newPos = scannerPosition + moveAmount;
            newPos = Math.max(0, Math.min(newPos, image.height));

            setScannerPosition(newPos);
        };

        canvas.addEventListener('wheel', handleWheel, { passive: false });
        return () => canvas.removeEventListener('wheel', handleWheel);
    }, [setScannerPosition]); // Dependencies that don't change often

    if (!project) return null;

    return (
        <div
            ref={containerRef}
            className="scanner-preview"
            style={{
                width: '100%',
                height: '100%',
                overflow: 'hidden',
                position: 'relative',
                background: 'var(--scanner-bg)' // Keep background color
            }}
        >
            <canvas
                ref={canvasRef}
                style={{ display: 'block' }}
            />
        </div>
    );
};

export default ScannerPreview;
