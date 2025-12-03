import React from 'react';
import { Button, Space, Divider } from 'antd';
import { ColumnWidthOutlined, ColumnHeightOutlined } from '@ant-design/icons';
import { useAtom } from 'jotai';
import { previewZoomAtom, layoutModeAtom } from '../../../store/atoms';
import './PreviewControls.scss'

const PreviewControls: React.FC = () => {
    const [zoom, setZoom] = useAtom(previewZoomAtom);
    const [layoutMode, setLayoutMode] = useAtom(layoutModeAtom);

    const zoomOptions = [
        { label: '100%', value: 1 },
        { label: '75%', value: 0.75 },
        { label: '50%', value: 0.5 }
    ];

    return (
        <div className="preview-controls">
            <Space split={<Divider type="vertical" />}>
                <Space size="small">
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
                <Space size="small">
                    <Button
                        type={layoutMode === 'horizontal' ? 'primary' : 'default'}
                        size="small"
                        icon={<ColumnWidthOutlined />}
                        onClick={() => setLayoutMode('horizontal')}
                        title="左右布局"
                    />
                    <Button
                        type={layoutMode === 'vertical' ? 'primary' : 'default'}
                        size="small"
                        icon={<ColumnHeightOutlined />}
                        onClick={() => setLayoutMode('vertical')}
                        title="上下布局"
                    />
                </Space>
            </Space>
        </div>
    );
};

export default PreviewControls;