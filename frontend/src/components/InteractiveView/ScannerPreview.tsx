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
    const [isDragging, setIsDragging] = useState(false);
    const [isHovering, setIsHovering] = useState(false);

    // Refs for event listeners to access latest state
    const stateRef = useRef({ scannerPosition, zoom, image });
    useEffect(() => {
        stateRef.current = { scannerPosition, zoom, image };
    }, [scannerPosition, zoom, image]);

    // Load WebP Image (Strictly WebP)
    useEffect(() => {
        if (!project) return;

        // Reset image while loading new project
        setImage(null);

        const loadPreview = async () => {
            const webpUrl = `${IMAGE_BASE_URL}/processed/${project.id}/full_preview.webp`;
            // Removed pngUrl and fallback logic as we now strictly enforce WebP

            try {
                const img = new Image();
                img.src = webpUrl;
                await new Promise((resolve, reject) => {
                    img.onload = resolve;
                    img.onerror = () => reject(new Error(`Failed to load ${webpUrl}`));
                });
                setImage(img);
            } catch (e) {
                console.error("Failed to load project preview image (WebP only)", e);
            }
        };

        loadPreview();
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

        // Draw drag handle button (circular)
        const buttonRadius = 12;
        const buttonCenterX = 10 + buttonRadius;
        const buttonCenterY = lineY;

        // Button background (circle) - white background
        ctx.save();
        ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
        ctx.shadowColor = 'rgba(0, 0, 0, 0.3)';
        ctx.shadowBlur = 5;
        ctx.beginPath();
        ctx.arc(buttonCenterX, buttonCenterY, buttonRadius, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();

        // Draw up and down triangles - gray icons
        ctx.save();
        ctx.fillStyle = '#666666';

        const triangleSize = 5;
        const triangleGap = 2;

        // Up triangle
        ctx.beginPath();
        ctx.moveTo(buttonCenterX, buttonCenterY - triangleGap - triangleSize); // top point
        ctx.lineTo(buttonCenterX - triangleSize, buttonCenterY - triangleGap); // bottom left
        ctx.lineTo(buttonCenterX + triangleSize, buttonCenterY - triangleGap); // bottom right
        ctx.closePath();
        ctx.fill();

        // Down triangle
        ctx.beginPath();
        ctx.moveTo(buttonCenterX, buttonCenterY + triangleGap + triangleSize); // bottom point
        ctx.lineTo(buttonCenterX - triangleSize, buttonCenterY + triangleGap); // top left
        ctx.lineTo(buttonCenterX + triangleSize, buttonCenterY + triangleGap); // top right
        ctx.closePath();
        ctx.fill();

        ctx.restore();

    }, [image, containerSize, zoom, scannerPosition, isDragging, isHovering]);

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

    // Mouse drag handlers
    useEffect(() => {
        const canvas = canvasRef.current;
        if (!canvas) return;

        const getLineY = () => {
            const { scannerPosition, zoom, image } = stateRef.current;
            if (!image || containerSize.height === 0) return 0;

            const scaledH = image.height * zoom;
            let lineY = 0;

            if (scaledH <= containerSize.height) {
                lineY = scannerPosition * zoom;
            } else {
                const progress = image.height > 0 ? scannerPosition / image.height : 0;
                lineY = progress * containerSize.height;
            }

            return lineY;
        };

        const isNearLine = (mouseY: number, lineY: number) => {
            return Math.abs(mouseY - lineY) < 20; // 20px tolerance
        };

        const handleMouseMove = (e: MouseEvent) => {
            const rect = canvas.getBoundingClientRect();
            const mouseY = e.clientY - rect.top;
            const lineY = getLineY();

            if (isDragging) {
                // Update scanner position based on mouse Y
                const { zoom, image } = stateRef.current;
                if (!image) return;

                const scaledH = image.height * zoom;

                let newPos: number;
                if (scaledH <= containerSize.height) {
                    // Image fits - direct mapping
                    newPos = mouseY / zoom;
                } else {
                    // Image needs scrolling - reverse the progress calculation
                    const progress = mouseY / containerSize.height;
                    newPos = progress * image.height;
                }

                newPos = Math.max(0, Math.min(newPos, image.height));
                setScannerPosition(newPos);
            } else {
                // Check if hovering near line
                const hovering = isNearLine(mouseY, lineY);
                if (hovering !== isHovering) {
                    setIsHovering(hovering);
                }
            }
        };

        const handleMouseDown = (e: MouseEvent) => {
            const rect = canvas.getBoundingClientRect();
            const mouseY = e.clientY - rect.top;
            const lineY = getLineY();

            if (isNearLine(mouseY, lineY)) {
                setIsDragging(true);
                e.preventDefault();
            }
        };

        const handleMouseUp = () => {
            if (isDragging) {
                setIsDragging(false);
            }
        };

        const handleMouseLeave = () => {
            setIsHovering(false);
        };

        canvas.addEventListener('mousemove', handleMouseMove);
        canvas.addEventListener('mousedown', handleMouseDown);
        window.addEventListener('mouseup', handleMouseUp);
        canvas.addEventListener('mouseleave', handleMouseLeave);

        return () => {
            canvas.removeEventListener('mousemove', handleMouseMove);
            canvas.removeEventListener('mousedown', handleMouseDown);
            window.removeEventListener('mouseup', handleMouseUp);
            canvas.removeEventListener('mouseleave', handleMouseLeave);
        };
    }, [setScannerPosition, isDragging, isHovering, containerSize]);

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
                background: 'var(--scanner-bg)', // Keep background color
                cursor: isDragging ? 'ns-resize' : (isHovering ? 'ns-resize' : 'default')
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
