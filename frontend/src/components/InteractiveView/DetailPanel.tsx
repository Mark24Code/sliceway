import React, { useState } from 'react';
import { Descriptions, Typography, Divider } from 'antd';
import { useAtom } from 'jotai';
import { layersAtom, selectedLayerIdsAtom, hoverLayerIdAtom } from '../../store/atoms';
import { ImagePreviewModal } from '../ImagePreview/ImagePreviewModal';
import { IMAGE_BASE_URL } from '../../config';

const { Title, Paragraph, Text } = Typography;

const DetailPanel: React.FC = () => {
    const [layers] = useAtom(layersAtom);
    const [selectedLayerIds] = useAtom(selectedLayerIdsAtom);
    const [hoverLayerId] = useAtom(hoverLayerIdAtom);
    const [previewVisible, setPreviewVisible] = useState(false);

    // 优先显示悬停图层，其次显示选中图层
    const displayLayerId = hoverLayerId || selectedLayerIds[selectedLayerIds.length - 1];
    const layer = layers.find(l => l.id === displayLayerId);

    // 缩略图点击处理
    const handleThumbnailClick = () => {
        setPreviewVisible(true);
    };

    // 模态框关闭处理
    const handlePreviewClose = () => {
        setPreviewVisible(false);
    };

    // 构建图片URL
    const imageUrl = layer?.image_path ? `${IMAGE_BASE_URL}/${layer.image_path}` : '';

    if (!layer) {
        return <div style={{ padding: 24, color: '#999' }}>选择一个图层查看详情</div>;
    }

    const cssCode = layer.layer_type === 'text'
        ? `/* Text Style */
font-family: '${layer.metadata?.font?.name || 'inherit'}';
font-size: ${layer.metadata?.font?.sizes?.[0] || 'inherit'}px;
color: ${layer.metadata?.font?.colors?.[0] ? `rgb(${layer.metadata.font.colors[0].join(',')})` : 'inherit'};
line-height: 1.5;`
        : `/* Image Style */
width: ${layer.width}px;
height: ${layer.height}px;
background-image: url('${layer.name}.png');
background-size: cover;`;

    return (
        <div style={{ padding: 24 }}>
            {/* 缩略图区域 */}
            {layer.image_path && (
                <div style={{ marginBottom: 16, textAlign: 'center' }}>
                    <div
                        style={{
                            width: '100%',
                            maxWidth: 200,
                            height: 120,
                            backgroundColor: '#f5f5f5',
                            backgroundImage: 'linear-gradient(45deg, #f0f0f0 25%, transparent 25%), linear-gradient(-45deg, #f0f0f0 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f0f0f0 75%), linear-gradient(-45deg, transparent 75%, #f0f0f0 75%)',
                            backgroundSize: '10px 10px',
                            backgroundPosition: '0 0, 0 5px, 5px -5px, -5px 0px',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            borderRadius: 6,
                            overflow: 'hidden',
                            cursor: 'pointer',
                            margin: '0 auto'
                        }}
                        onClick={handleThumbnailClick}
                    >
                        <img
                            src={imageUrl}
                            alt={layer.name}
                            style={{
                                maxWidth: '100%',
                                maxHeight: '100%',
                                objectFit: 'contain',
                                border: '1px solid #ccc'
                            }}
                        />
                    </div>
                    <div style={{ marginTop: 8, fontSize: 12, color: '#666' }}>
                        点击查看大图
                    </div>
                </div>
            )}

            <Title level={4}>图层详情</Title>
            <Descriptions column={1} bordered size="small">
                <Descriptions.Item label="ID">{layer.id}</Descriptions.Item>
                <Descriptions.Item label="名称">{layer.name}</Descriptions.Item>
                <Descriptions.Item label="类型">{layer.layer_type}</Descriptions.Item>
                <Descriptions.Item label="位置">({layer.x}, {layer.y})</Descriptions.Item>
                <Descriptions.Item label="尺寸">{layer.width} x {layer.height}</Descriptions.Item>
            </Descriptions>

            <Divider />

            <Title level={5}>CSS代码片段</Title>
            <Paragraph>
                <pre style={{ background: '#f5f5f5', padding: 10, borderRadius: 4, fontSize: 12 }}>
                    {cssCode}
                </pre>
                <Text copyable={{ text: cssCode }}>复制代码</Text>
            </Paragraph>

            {/* 图片预览模态框 */}
            <ImagePreviewModal
                visible={previewVisible}
                imageUrl={imageUrl}
                alt={layer.name}
                onClose={handlePreviewClose}
                layerInfo={{
                    id: layer.id,
                    name: layer.name,
                    layer_type: layer.layer_type,
                    width: layer.width,
                    height: layer.height
                }}
            />
        </div>
    );
};

export default DetailPanel;
