import React, { useState, useMemo, useCallback } from 'react';
import { Tabs, Card, Checkbox, Button, message, Select, Space } from 'antd';
import { useAtom } from 'jotai';
import { debounce } from 'lodash';
import { layersAtom, scannerPositionAtom, hoverLayerIdAtom, selectedLayerIdsAtom, projectAtom, globalLoadingAtom } from '../../store/atoms';
import client from '../../api/client';
import { IMAGE_BASE_URL } from '../../config';

const { TabPane } = Tabs;

const FilterList: React.FC = () => {
    const [layers] = useAtom(layersAtom);
    const [scannerY] = useAtom(scannerPositionAtom);
    const [project] = useAtom(projectAtom);
    const [, setHoverLayerId] = useAtom(hoverLayerIdAtom);
    const [selectedLayerIds, setSelectedLayerIds] = useAtom(selectedLayerIdsAtom);
    const [, setGlobalLoading] = useAtom(globalLoadingAtom);
    const [activeTab, setActiveTab] = useState('all');
    const [typeFilter, setTypeFilter] = useState<string[]>([]);
    const [sizeFilter, setSizeFilter] = useState<string[]>([]);
    const [ratioFilter, setRatioFilter] = useState<string[]>([]);

    // Filter logic based on Scanner Position
    // The scanner is roughly at the center of the viewport.
    // We need to know the viewport height to calculate the exact "scan line" Y in the image.
    // For now, let's assume the scanner line is at `scannerY + viewportHeight / 2`.
    // Since we don't have exact viewport height here easily without ResizeObserver, 
    // let's just use a range around `scannerY`.
    // Actually, `scannerY` is `scrollTop`. The line is at `scrollTop + containerHeight/2`.
    // Let's approximate containerHeight as 600px (2/3 of screen). So offset ~300px.
    const scanLineY = scannerY + 300;
    // const range = 100; // Show items within +/- 100px of the line?
    // Requirement: "Filter exported images where reference line passes through".

    const visibleLayers = useMemo(() => {
        return layers.filter(l => {
            const layerTop = l.y;
            const layerBottom = l.y + l.height;
            // Check intersection with scanLineY
            return scanLineY >= layerTop && scanLineY <= layerBottom;
        });
    }, [layers, scanLineY]);

    const filteredLayers = useMemo(() => {
        let list = visibleLayers;

        // 类型筛选
        if (typeFilter.length > 0) {
            list = list.filter(l => typeFilter.includes(l.layer_type));
        }

        // 尺寸筛选
        if (sizeFilter.length > 0) {
            list = list.filter(l => {
                const maxDimension = Math.max(l.width, l.height);
                return sizeFilter.some(size => {
                    if (size === 'small') return maxDimension <= 100;
                    if (size === 'medium') return maxDimension > 100 && maxDimension <= 500;
                    if (size === 'large') return maxDimension > 500;
                    return false;
                });
            });
        }

        // 比例筛选
        if (ratioFilter.length > 0) {
            list = list.filter(l => {
                const ratio = l.width / l.height;
                return ratioFilter.some(ratioType => {
                    if (ratioType === 'square') return ratio >= 0.9 && ratio <= 1.1;
                    if (ratioType === 'horizontal') return ratio > 1.1;
                    if (ratioType === 'vertical') return ratio < 0.9;
                    return false;
                });
            });
        }

        // 标签页筛选
        if (activeTab === 'equidistant') {
            list = list.filter(l => Math.abs(l.width - l.height) < 2); // Width approx equal Height
        } else if (activeTab === 'text') {
            list = list.filter(l => l.layer_type === 'text');
        } else if (activeTab === 'no_text') {
            list = list.filter(l => l.layer_type !== 'text'); // Rough approx
        } else if (activeTab === 'has_text') {
            list = list.filter(l => l.layer_type === 'group' || l.layer_type === 'text'); // Groups might have text
        }
        return list;
    }, [visibleLayers, typeFilter, sizeFilter, ratioFilter, activeTab]);

    const handleExport = useCallback(async () => {
        if (!project || selectedLayerIds.length === 0) return;

        setGlobalLoading(true);
        try {
            const res = await client.post(`/projects/${project.id}/export`, { layer_ids: selectedLayerIds });
            message.success(`已导出 ${res.data.count} 个文件`);
        } catch (error) {
            message.error('导出失败');
        } finally {
            setGlobalLoading(false);
        }
    }, [project, selectedLayerIds, setGlobalLoading]);

    // 防抖导出函数
    const debouncedExport = useCallback(
        debounce(() => {
            handleExport();
        }, 500),
        [handleExport]
    );

    const toggleSelection = (id: number) => {
        setSelectedLayerIds(prev =>
            prev.includes(id) ? prev.filter(i => i !== id) : [...prev, id]
        );
    };

    return (
        <div className="filter-list">
            <div className="header">
                <Space wrap style={{ marginBottom: 8 }}>
                    <div style={{ display: 'flex', alignItems: 'center' }}>
                        <span style={{ marginRight: 8 }}>类型:</span>
                        <Select
                            mode="multiple"
                            placeholder="选择图层类型"
                            value={typeFilter}
                            onChange={setTypeFilter}
                            style={{ width: 200 }}
                            allowClear
                        >
                            <Select.Option value="slice">切片</Select.Option>
                            <Select.Option value="layer">图层</Select.Option>
                            <Select.Option value="group">组</Select.Option>
                            <Select.Option value="text">文本</Select.Option>
                        </Select>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center' }}>
                        <span style={{ marginRight: 8 }}>尺寸:</span>
                        <Select
                            mode="multiple"
                            placeholder="选择尺寸范围"
                            value={sizeFilter}
                            onChange={setSizeFilter}
                            style={{ width: 200 }}
                            allowClear
                        >
                            <Select.Option value="small">小 (0-100px)</Select.Option>
                            <Select.Option value="medium">中 (101-500px)</Select.Option>
                            <Select.Option value="large">大 (501px+)</Select.Option>
                        </Select>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center' }}>
                        <span style={{ marginRight: 8 }}>比例:</span>
                        <Select
                            mode="multiple"
                            placeholder="选择比例类型"
                            value={ratioFilter}
                            onChange={setRatioFilter}
                            style={{ width: 200 }}
                            allowClear
                        >
                            <Select.Option value="square">正方形</Select.Option>
                            <Select.Option value="horizontal">横向</Select.Option>
                            <Select.Option value="vertical">纵向</Select.Option>
                        </Select>
                    </div>
                </Space>
                <Tabs activeKey={activeTab} onChange={setActiveTab} style={{ marginBottom: 0 }}>
                    <TabPane tab="全部" key="all" />
                    <TabPane tab="等距" key="equidistant" />
                    <TabPane tab="文本" key="text" />
                    <TabPane tab="无文本" key="no_text" />
                    <TabPane tab="有文本" key="has_text" />
                </Tabs>
                <Button type="primary" disabled={selectedLayerIds.length === 0} onClick={debouncedExport}>
                    导出 ({selectedLayerIds.length})
                </Button>
            </div>

            <div className="list-content">
                {filteredLayers.map(layer => (
                    <Card
                        key={layer.id}
                        hoverable
                        className="layer-card"
                        style={{
                            border: selectedLayerIds.includes(layer.id) ? '2px solid #1890ff' : undefined
                        }}
                        cover={
                            <div
                                className="cover"
                                onClick={() => toggleSelection(layer.id)}
                                onMouseEnter={() => setHoverLayerId(layer.id)}
                                onMouseLeave={() => setHoverLayerId(null)}
                            >
                                {layer.image_path ? (
                                    <img
                                        alt={layer.name}
                                        src={`${IMAGE_BASE_URL}/${layer.image_path}`}
                                    />
                                ) : (
                                    <span>无图片</span>
                                )}
                            </div>
                        }
                    >
                        <Card.Meta
                            title={layer.name}
                            description={`${layer.width}x${layer.height}`}
                        />
                        <Checkbox
                            className="checkbox"
                            checked={selectedLayerIds.includes(layer.id)}
                            onChange={() => toggleSelection(layer.id)}
                        />
                    </Card>
                ))}
                {filteredLayers.length === 0 && <div style={{ padding: 20, color: '#999' }}>在此扫描位置未找到图层。请滚动顶部视图！</div>}
            </div>
        </div>
    );
};

export default FilterList;
