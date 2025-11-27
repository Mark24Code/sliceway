import React from 'react';
import { Descriptions, Typography, Divider } from 'antd';
import { useAtom } from 'jotai';
import { layersAtom, selectedLayerIdsAtom } from '../../store/atoms';

const { Title, Paragraph, Text } = Typography;

const DetailPanel: React.FC = () => {
    const [layers] = useAtom(layersAtom);
    const [selectedLayerIds] = useAtom(selectedLayerIdsAtom);

    // Show details for the last selected layer
    const selectedId = selectedLayerIds[selectedLayerIds.length - 1];
    const layer = layers.find(l => l.id === selectedId);

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
        </div>
    );
};

export default DetailPanel;
