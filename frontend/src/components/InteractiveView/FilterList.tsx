import React, { useState, useMemo, useCallback, useRef } from 'react';
import { Tabs, Card, Checkbox, Button, message, Select, Space, Input, Dropdown } from 'antd';
import type { MenuProps } from 'antd';
import { DownOutlined, EyeInvisibleOutlined, AppstoreOutlined, UnorderedListOutlined } from '@ant-design/icons';
import { useAtom } from 'jotai';
import ExportConfigButton from '../ExportConfigButton';
import RenameExportModal from './RenameExportModal';
import { debounce } from 'lodash';
import { layersAtom, scannerPositionAtom, selectedLayerIdsAtom, projectAtom, globalLoadingAtom, hoverLayerIdAtom, filterViewModeAtom } from '../../store/atoms';
import client from '../../api/client';
import { IMAGE_BASE_URL } from '../../config';
import type { Layer } from '../../types';

const { TabPane } = Tabs;

const FilterList: React.FC = () => {
    const [layers] = useAtom(layersAtom);
    const [scannerY] = useAtom(scannerPositionAtom);
    const [project] = useAtom(projectAtom);
    const [selectedLayerIds, setSelectedLayerIds] = useAtom(selectedLayerIdsAtom);
    const [hoverLayerId, setHoverLayerId] = useAtom(hoverLayerIdAtom);
    const [, setGlobalLoading] = useAtom(globalLoadingAtom);
    const [viewMode, setViewMode] = useAtom(filterViewModeAtom);
    const [activeTab, setActiveTab] = useState('all');
    const [typeFilter, setTypeFilter] = useState<string[]>([]);
    const [sizeFilter, setSizeFilter] = useState<string[]>([]);
    const [ratioFilter, setRatioFilter] = useState<string[]>([]);
    const [hiddenFilter, setHiddenFilter] = useState<string[]>([]);
    const [nameFilter, setNameFilter] = useState('');
    const [renameModalVisible, setRenameModalVisible] = useState(false);
    const hoverTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

    // 树视图辅助函数
    const groupLayersByY = useCallback((layers: Layer[], tolerance = 10): Layer[][] => {
        const sorted = [...layers].sort((a, b) => a.y - b.y);
        const groups: Layer[][] = [];

        sorted.forEach(layer => {
            const lastGroup = groups[groups.length - 1];
            if (!lastGroup || Math.abs(layer.y - lastGroup[0].y) > tolerance) {
                groups.push([layer]);
            } else {
                lastGroup.push(layer);
            }
        });

        return groups;
    }, []);

    const calculateIndentLevel = useCallback((layer: Layer, maxWidth: number): number => {
        const widthRatio = layer.width / maxWidth;

        if (widthRatio < 0.3) return 3;
        if (widthRatio < 0.5) return 2;
        if (widthRatio < 0.8) return 1;
        return 0;
    }, []);

    // Filter logic based on Scanner Position
    // scannerY 已经是换算后的图片坐标位置
    const scanLineY = scannerY;
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

        // 名称筛选
        if (nameFilter) {
            const lowerName = nameFilter.toLowerCase();
            list = list.filter(l => l.name.toLowerCase().includes(lowerName));
        }

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

        // 隐藏状态筛选
        if (hiddenFilter.length > 0) {
            list = list.filter(l => {
                return hiddenFilter.some(status => {
                    if (status === 'hidden') return l.hidden === true;
                    if (status === 'visible') return l.hidden !== true;
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

        // 按图片宽度从低到高排序
        list = list.sort((a, b) => a.width - b.width);

        return list;
    }, [visibleLayers, typeFilter, sizeFilter, ratioFilter, hiddenFilter, activeTab, nameFilter]);

    const [exportScales, setExportScales] = useState<string[]>(['1x']);
    const [trimTransparent, setTrimTransparent] = useState<boolean>(false);

    const handleExport = useCallback(async (renames?: Record<number, string>, clearDirectory?: boolean) => {
        if (!project || selectedLayerIds.length === 0) return;

        setGlobalLoading(true);
        try {
            const res = await client.post(`/projects/${project.id}/export`, {
                layer_ids: selectedLayerIds,
                scales: exportScales,
                renames: renames,
                clear_directory: clearDirectory,
                trim_transparent: trimTransparent
            });
            message.success(`已导出 ${res.data.count} 个文件`);
            setRenameModalVisible(false);
        } catch (error) {
            message.error('导出失败');
        } finally {
            setGlobalLoading(false);
        }
    }, [project, selectedLayerIds, exportScales, trimTransparent, setGlobalLoading]);

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

    const handleMouseEnter = (layerId: number) => {
        // 清除之前的超时
        if (hoverTimeoutRef.current) {
            clearTimeout(hoverTimeoutRef.current);
        }

        // 设置新的 500ms 超时
        hoverTimeoutRef.current = setTimeout(() => {
            setHoverLayerId(layerId);
        }, 500);
    };

    const handleMouseLeave = () => {
        // 清除超时，防止延迟后触发悬停
        if (hoverTimeoutRef.current) {
            clearTimeout(hoverTimeoutRef.current);
        }
        // 注意：不重置 hoverLayerId，保持显示最后一个悬停元素
    };

    const exportMenuProps: MenuProps = {
        items: [
            {
                label: '导出并重命名',
                key: 'rename',
                onClick: () => setRenameModalVisible(true),
            },
        ],
    };

    // Get selected layer objects for the modal
    const selectedLayers = useMemo(() => {
        return layers.filter(l => selectedLayerIds.includes(l.id));
    }, [layers, selectedLayerIds]);

    return (
        <div className="filter-list">
            <div className="header">
                <Space wrap style={{ marginBottom: 8 }}>
                    <div style={{ display: 'flex', alignItems: 'center' }}>
                         <Input
                            placeholder="搜索图层名称"
                            value={nameFilter}
                            onChange={e => setNameFilter(e.target.value)}
                            style={{ width: 150 }}
                            allowClear
                        />
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center' }}>
                        {/* <span style={{ marginRight: 8 }}>类型:</span> */}
                        <Select
                            mode="multiple"
                            placeholder="选择图层类型"
                            value={typeFilter}
                            onChange={setTypeFilter}
                            style={{ width: 150 }}
                            allowClear
                        >
                            <Select.Option value="slice">切片</Select.Option>
                            <Select.Option value="layer">图层</Select.Option>
                            <Select.Option value="group">组</Select.Option>
                            <Select.Option value="text">文本</Select.Option>
                        </Select>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center' }}>
                        {/* <span style={{ marginRight: 8 }}>尺寸:</span> */}
                        <Select
                            mode="multiple"
                            placeholder="选择尺寸范围"
                            value={sizeFilter}
                            onChange={setSizeFilter}
                            style={{ width: 150 }}
                            allowClear
                        >
                            <Select.Option value="small">小 (0-100px)</Select.Option>
                            <Select.Option value="medium">中 (101-500px)</Select.Option>
                            <Select.Option value="large">大 (501px+)</Select.Option>
                        </Select>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center' }}>
                        {/* <span style={{ marginRight: 8 }}>比例:</span> */}
                        <Select
                            mode="multiple"
                            placeholder="选择比例类型"
                            value={ratioFilter}
                            onChange={setRatioFilter}
                            style={{ width: 150 }}
                            allowClear
                        >
                            <Select.Option value="square">正方形</Select.Option>
                            <Select.Option value="horizontal">横向</Select.Option>
                            <Select.Option value="vertical">纵向</Select.Option>
                        </Select>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center' }}>
                        {/* <span style={{ marginRight: 8 }}>状态:</span> */}
                        <Select
                            mode="multiple"
                            placeholder="选择可见状态"
                            value={hiddenFilter}
                            onChange={setHiddenFilter}
                            style={{ width: 150 }}
                            allowClear
                        >
                            <Select.Option value="visible">可见</Select.Option>
                            <Select.Option value="hidden">隐藏</Select.Option>
                        </Select>
                    </div>
                    <Space>
                        <Space size="small">
                            <Button
                                type={viewMode === 'list' ? 'primary' : 'default'}
                                size="small"
                                icon={<AppstoreOutlined />}
                                onClick={() => setViewMode('list')}
                                title="列表视图"
                            />
                            <Button
                                type={viewMode === 'tree' ? 'primary' : 'default'}
                                size="small"
                                icon={<UnorderedListOutlined />}
                                onClick={() => setViewMode('tree')}
                                title="树视图"
                            />
                        </Space>
                        <ExportConfigButton
                            value={exportScales}
                            onChange={setExportScales}
                            trimTransparent={trimTransparent}
                            onTrimTransparentChange={setTrimTransparent}
                            processingMode={project?.processing_mode}
                        />
                        <Dropdown.Button
                            type="primary"
                            disabled={selectedLayerIds.length === 0}
                            onClick={debouncedExport}
                            menu={exportMenuProps}
                            icon={<DownOutlined />}
                        >
                            导出 ({selectedLayerIds.length})
                        </Dropdown.Button>
                        <Button
                            type="default"
                            disabled={selectedLayerIds.length === 0}
                            onClick={() => setSelectedLayerIds([])}
                        >
                            清除导出
                        </Button>
                    </Space>
                </Space>
                <Tabs activeKey={activeTab} onChange={setActiveTab} style={{ marginBottom: 0 }}>
                    <TabPane tab="全部" key="all" />
                    <TabPane tab="等距" key="equidistant" />
                    <TabPane tab="文本" key="text" />
                    <TabPane tab="无文本" key="no_text" />
                    <TabPane tab="有文本" key="has_text" />
                </Tabs>
            </div>

            <RenameExportModal
                visible={renameModalVisible}
                onCancel={() => setRenameModalVisible(false)}
                onConfirm={(renames, clearDirectory) => handleExport(renames, clearDirectory)}
                layers={selectedLayers}
            />

            {viewMode === 'list' ? (
                <div className="list-content">
                    {filteredLayers.map(layer => (
                        <Card
                            key={layer.id}
                            hoverable
                            className="layer-card"
                            style={{
                                border: selectedLayerIds.includes(layer.id)
                                    ? '2px solid #1890ff'
                                    : hoverLayerId === layer.id
                                        ? '2px solid #52c41a'
                                        : `1px solid var(--border-color)`,
                                background: 'var(--card-bg)'
                            }}
                            onMouseEnter={() => handleMouseEnter(layer.id)}
                            onMouseLeave={handleMouseLeave}
                            cover={
                                <div
                                    className="cover"
                                    onClick={() => toggleSelection(layer.id)}
                                    style={{
                                        position: 'relative',
                                        opacity: layer.hidden ? 0.6 : 1,
                                        filter: layer.hidden ? 'grayscale(30%)' : 'none'
                                    }}
                                >
                                    {layer.hidden && (
                                        <span style={{
                                            position: 'absolute',
                                            top: 4,
                                            left: 4,
                                            fontSize: '20px',
                                            zIndex: 2,
                                            textShadow: '0 0 3px rgba(255,255,255,0.8)'
                                        }}>
                                            <EyeInvisibleOutlined />
                                        </span>
                                    )}
                                    {layer.hidden && (
                                        <div style={{
                                            position: 'absolute',
                                            top: 0,
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            backgroundColor: 'rgba(128, 128, 128, 0.2)',
                                            zIndex: 1
                                        }} />
                                    )}
                                    {layer.image_path ? (
                                        <img
                                            alt={layer.name}
                                            src={`${IMAGE_BASE_URL}/${layer.image_path}`}
                                        />
                                    ) : (
                                        <span style={{ color: 'var(--text-secondary)' }}>无图片</span>
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
                    {filteredLayers.length === 0 && <div style={{ padding: 20, color: 'var(--text-secondary)' }}>在此扫描位置未找到图层。请滚动顶部视图！</div>}
                </div>
            ) : (
                <div className="tree-content">
                    {(() => {
                        if (filteredLayers.length === 0) {
                            return <div style={{ padding: 20, color: 'var(--text-secondary)' }}>在此扫描位置未找到图层。请滚动顶部视图！</div>;
                        }

                        const maxWidth = Math.max(...filteredLayers.map(l => l.width));
                        const groupedLayers = groupLayersByY(filteredLayers);

                        return groupedLayers.flatMap(group => {
                            const sortedGroup = [...group].sort((a, b) => a.x - b.x);
                            return sortedGroup.map(layer => (
                                <div
                                    key={layer.id}
                                    className="tree-view-item"
                                    style={{
                                        paddingLeft: `${calculateIndentLevel(layer, maxWidth) * 20 + 8}px`,
                                        backgroundColor: selectedLayerIds.includes(layer.id) ? 'rgba(24, 144, 255, 0.1)' : 'transparent',
                                        border: hoverLayerId === layer.id ? '1px solid #52c41a' : '1px solid transparent'
                                    }}
                                    onClick={() => toggleSelection(layer.id)}
                                    onMouseEnter={() => handleMouseEnter(layer.id)}
                                    onMouseLeave={handleMouseLeave}
                                >
                                    <Checkbox
                                        checked={selectedLayerIds.includes(layer.id)}
                                        onChange={() => toggleSelection(layer.id)}
                                        onClick={(e) => e.stopPropagation()}
                                    />
                                    {layer.image_path ? (
                                        <img
                                            src={`${IMAGE_BASE_URL}/${layer.image_path}`}
                                            alt={layer.name}
                                            className="tree-view-thumbnail"
                                        />
                                    ) : (
                                        <div className="tree-view-thumbnail" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-secondary)' }}>无</div>
                                    )}
                                    {layer.hidden && (
                                        <EyeInvisibleOutlined style={{ color: 'var(--text-secondary)', fontSize: 14 }} />
                                    )}
                                    <span className="tree-view-name">{layer.name}</span>
                                    <span className="tree-view-size">{layer.width}×{layer.height}</span>
                                </div>
                            ));
                        });
                    })()}
                </div>
            )}
        </div>
    );
};

export default FilterList;
