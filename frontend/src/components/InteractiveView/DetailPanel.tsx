import React, { useState } from 'react';
import { Descriptions, Typography, Divider, Tabs, Button, message } from 'antd';
import { CopyOutlined } from '@ant-design/icons';
import { useAtom } from 'jotai';
import { layersAtom, selectedLayerIdsAtom, hoverLayerIdAtom } from '../../store/atoms';
import { ImagePreviewModal } from '../ImagePreview/ImagePreviewModal';
import { IMAGE_BASE_URL } from '../../config';
import { CodeGenerator } from '../../utils/CodeGenerator';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism';

const { Title } = Typography;

const CodeBlock: React.FC<{ code: string; language: string }> = ({ code, language }) => {
    const handleCopy = () => {
        navigator.clipboard.writeText(code);
        message.success('代码已复制');
    };

    return (
        <div style={{ position: 'relative' }}>
            <Button
                icon={<CopyOutlined />}
                type="text"
                size="small"
                style={{
                    position: 'absolute',
                    top: 8,
                    right: 8,
                    zIndex: 1,
                    color: '#fff',
                    background: 'rgba(0,0,0,0.3)'
                }}
                onClick={handleCopy}
            />
            <SyntaxHighlighter
                language={language}
                style={vscDarkPlus}
                customStyle={{ margin: 0, borderRadius: 4, fontSize: 12 }}
            >
                {code}
            </SyntaxHighlighter>
        </div>
    );
};

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

    // 监听空格键预览
    React.useEffect(() => {
        const handleKeyDown = (e: KeyboardEvent) => {
            if (e.code === 'Space') {
                if (previewVisible) {
                    e.preventDefault();
                    setPreviewVisible(false);
                } else if (layer) {
                    e.preventDefault();
                    setPreviewVisible(true);
                }
            }
        };

        window.addEventListener('keydown', handleKeyDown);
        return () => {
            window.removeEventListener('keydown', handleKeyDown);
        };
    }, [layer, previewVisible]);

    if (!layer) {
        return <div style={{ transform: 'translateY(50%)', padding: 24, color: 'var(--text-secondary)', textAlign: 'center' }}>
            <p>鼠标悬浮在一个"图层"</p>
            <p>查看详情</p>
            <p>"空格"直接预览或关闭预览</p>
        </div>;
    }



    return (
        <div style={{ padding: 24, overflowY: 'scroll', height: '100%' }}>
            {/* 缩略图区域 */}
            {layer.image_path && (
                <div style={{ marginBottom: 16, textAlign: 'center' }}>
                    <div
                        className="checkerboard-bg-small"
                        style={{
                            width: '100%',
                            maxWidth: 200,
                            height: 120,
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
                                border: '1px solid var(--border-color)'
                            }}
                        />
                    </div>
                    <div style={{ marginTop: 8, fontSize: 12, color: 'var(--text-secondary)' }}>
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

            <Title level={5}>代码片段</Title>
            <Tabs
                defaultActiveKey="css"
                items={[
                    { label: 'CSS', key: 'css', children: <CodeBlock code={CodeGenerator.generateCSS(layer)} language="css" /> },
                    { label: 'SCSS', key: 'scss', children: <CodeBlock code={CodeGenerator.generateSCSS(layer)} language="scss" /> },
                    { label: 'Less', key: 'less', children: <CodeBlock code={CodeGenerator.generateLess(layer)} language="less" /> },
                    { label: 'Vue', key: 'vue', children: <CodeBlock code={CodeGenerator.generateVue(layer)} language="html" /> },
                    { label: 'React', key: 'react', children: <CodeBlock code={CodeGenerator.generateReact(layer)} language="jsx" /> },
                    { label: 'JS', key: 'js', children: <CodeBlock code={JSON.stringify(CodeGenerator.generateJS(layer), null, 2)} language="javascript" /> },
                ]}
            />

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
