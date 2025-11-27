import React from 'react';
import { Button, Space } from 'antd';
import { useAtom } from 'jotai';
import { previewZoomAtom } from '../../../store/atoms';
import './PreviewControls.scss'

const PreviewControls: React.FC = () => {
    const [zoom, setZoom] = useAtom(previewZoomAtom);

    const zoomOptions = [
        { label: '100%', value: 1 },
        { label: '75%', value: 0.75 },
        { label: '50%', value: 0.5 }
    ];

    return (
        <div className="preview-controls">
            <Space>
                {zoomOptions.map(option => (
                    <Button
                        key={option.value}
                        type={zoom === option.value ? 'primary' : 'default'}
                        size="small"
                        onClick={() => setZoom(option.value)}
                    >
                        {option.label}
                    </Button>
                ))}
            </Space>
        </div>
    );
};

export default PreviewControls;