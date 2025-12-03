import React, { useState, useCallback, useEffect } from 'react';
import { Table, Button, Input, Space, message, Select } from 'antd';
import { ReloadOutlined } from '@ant-design/icons';
import { useAtom } from 'jotai';
import { debounce } from 'lodash';
import { layersAtom, projectAtom, globalLoadingAtom } from '../../store/atoms';
import client from '../../api/client';
import type { Layer } from '../../types';
import { LAYER_TYPE_MAP } from '../../types';
import { ImagePreviewThumbnail, ImagePreviewModal, ImagePreviewHover } from '../ImagePreview';
import { IMAGE_BASE_URL } from '../../config';
import ExportConfigButton from '../ExportConfigButton';

const FullListView: React.FC = () => {
    const [layers, setLayers] = useAtom(layersAtom);
    const [project] = useAtom(projectAtom);
    const [, setGlobalLoading] = useAtom(globalLoadingAtom);
    const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([]);
    const [searchText, setSearchText] = useState('');
    const [typeFilter, setTypeFilter] = useState<string[]>([]);
    const [sizeFilter, setSizeFilter] = useState<string[]>([]);
    const [ratioFilter, setRatioFilter] = useState<string[]>([]);
    const [refreshing, setRefreshing] = useState(false);
    const [exportScales, setExportScales] = useState<string[]>(['1x']);
    const [trimTransparent, setTrimTransparent] = useState<boolean>(false);

    // 分页状态
    const [currentPage, setCurrentPage] = useState(1);
    const [pageSize, setPageSize] = useState(10);

    // 图片预览模态框状态
    const [previewVisible, setPreviewVisible] = useState(false);
    const [previewImage, setPreviewImage] = useState<string>('');
    const [previewLayerInfo, setPreviewLayerInfo] = useState<any>(null);

    const handleExport = useCallback(async (ids: number[]) => {
        if (!project) return;

        setGlobalLoading(true);
        try {
            const res = await client.post(`/projects/${project.id}/export`, {
                layer_ids: ids,
                scales: exportScales,
                trim_transparent: trimTransparent
            });
            message.success(`已导出 ${res.data.count} 个文件到 ${res.data.path}`);
        } catch (error) {
            message.error('导出失败');
        } finally {
            setGlobalLoading(false);
        }
    }, [project, exportScales, trimTransparent, setGlobalLoading]);

    const handleRefresh = useCallback(async () => {
        if (!project) return;
        setRefreshing(true);
        try {
            const res = await client.get(`/projects/${project.id}/layers`);
            setLayers(res.data);
            message.success('列表已刷新');
        } catch (error) {
            message.error('刷新失败');
        } finally {
            setRefreshing(false);
        }
    }, [project, setLayers]);


    // 防抖导出函数
    const debouncedExport = useCallback(
        debounce((ids: number[]) => {
            handleExport(ids);
        }, 500),
        [handleExport]
    );

    // 分页改变处理
    const handlePageChange = useCallback((page: number, newPageSize: number) => {
        setCurrentPage(page);
        if (newPageSize !== pageSize) {
            setPageSize(newPageSize);
            setCurrentPage(1); // 改变每页条数时重置到第一页
        }
    }, [pageSize]);

    // 筛选条件改变时重置到第一页
    useEffect(() => {
        setCurrentPage(1);
    }, [searchText, typeFilter, sizeFilter, ratioFilter]);

    const filteredLayers = layers.filter(l => {
        // Search Filter
        if (searchText) {
            const searchLower = searchText.toLowerCase();
            if (!(l.name?.toLowerCase().includes(searchLower) || l.resource_id?.includes(searchText))) {
                return false;
            }
        }

        // Type Filter
        if (typeFilter.length > 0) {
            if (!typeFilter.includes(l.layer_type)) return false;
        }

        // Size Filter
        if (sizeFilter.length > 0) {
            const maxDimension = Math.max(l.width, l.height);
            const sizeMatch = sizeFilter.some(size => {
                if (size === 'small') return maxDimension <= 100;
                if (size === 'medium') return maxDimension > 100 && maxDimension <= 500;
                if (size === 'large') return maxDimension > 500;
                return false;
            });
            if (!sizeMatch) return false;
        }

        // Ratio Filter
        if (ratioFilter.length > 0) {
            const ratio = l.width / l.height;
            const ratioMatch = ratioFilter.some(ratioType => {
                if (ratioType === 'square') return ratio >= 0.9 && ratio <= 1.1;
                if (ratioType === 'horizontal') return ratio > 1.1;
                if (ratioType === 'vertical') return ratio < 0.9;
                return false;
            });
            if (!ratioMatch) return false;
        }

        return true;
    });

    const columns = [
        {
            title: 'ID',
            dataIndex: 'id',
            key: 'id',
        },
        {
            title: '预览',
            key: 'preview',
            render: (_: any, record: Layer) => (
                record.image_path ?
                    <ImagePreviewHover
                        src={`${IMAGE_BASE_URL}/${record.image_path}`}
                        alt={record.name}
                        maxWidth={500}
                        maxHeight={400}
                        layerInfo={{
                            id: record.id,
                            name: record.name,
                            layer_type: record.layer_type,
                            width: record.width,
                            height: record.height
                        }}
                    >
                        <ImagePreviewThumbnail
                            src={`${IMAGE_BASE_URL}/${record.image_path}`}
                            alt={record.name}
                            onClick={() => {
                                setPreviewImage(`${IMAGE_BASE_URL}/${record.image_path}`);
                                setPreviewLayerInfo({
                                    id: record.id,
                                    name: record.name,
                                    layer_type: record.layer_type,
                                    width: record.width,
                                    height: record.height
                                });
                                setPreviewVisible(true);
                            }}
                        />
                    </ImagePreviewHover> :
                    <span>无图片</span>
            ),
        },
        {
            title: '名称',
            dataIndex: 'name',
            key: 'name',
        },
        {
            title: '类型',
            dataIndex: 'layer_type',
            key: 'layer_type',
            render: (_: any, record: Layer) => LAYER_TYPE_MAP[record.layer_type] || record.layer_type,
        },
        {
            title: '尺寸',
            key: 'dim',
            render: (_: any, record: Layer) => `${record.width}x${record.height}`,
        },
        {
            title: '操作',
            key: 'action',
            render: (_: any, record: Layer) => (
                <Button size="small" onClick={() => debouncedExport([record.id])}>导出</Button>
            ),
        },
    ];

    return (
        <div style={{ padding: 24, height: '100%', overflow: 'auto' }}>
            <Space style={{ marginBottom: 16 }} wrap>
                <Input
                    placeholder="按名称或ID搜索"
                    value={searchText}
                    onChange={e => setSearchText(e.target.value)}
                    style={{ width: 200 }}
                />
                <Select
                    mode="multiple"
                    placeholder="类型"
                    value={typeFilter}
                    onChange={setTypeFilter}
                    style={{ width: 150 }}
                    allowClear
                    maxTagCount="responsive"
                >
                    <Select.Option value="slice">切片</Select.Option>
                    <Select.Option value="layer">图层</Select.Option>
                    <Select.Option value="group">组</Select.Option>
                    <Select.Option value="text">文本</Select.Option>
                </Select>
                <Select
                    mode="multiple"
                    placeholder="尺寸"
                    value={sizeFilter}
                    onChange={setSizeFilter}
                    style={{ width: 150 }}
                    allowClear
                    maxTagCount="responsive"
                >
                    <Select.Option value="small">小 (0-100px)</Select.Option>
                    <Select.Option value="medium">中 (101-500px)</Select.Option>
                    <Select.Option value="large">大 (501px+)</Select.Option>
                </Select>
                <Select
                    mode="multiple"
                    placeholder="比例"
                    value={ratioFilter}
                    onChange={setRatioFilter}
                    style={{ width: 150 }}
                    allowClear
                    maxTagCount="responsive"
                >
                    <Select.Option value="square">正方形</Select.Option>
                    <Select.Option value="horizontal">横向</Select.Option>
                    <Select.Option value="vertical">纵向</Select.Option>
                </Select>
                <ExportConfigButton
                    value={exportScales}
                    onChange={setExportScales}
                    trimTransparent={trimTransparent}
                    onTrimTransparentChange={setTrimTransparent}
                />
                <Button
                    type="primary"
                    disabled={selectedRowKeys.length === 0}
                    onClick={() => debouncedExport(selectedRowKeys as number[])}
                >
                    导出选中项 ({selectedRowKeys.length})
                </Button>
                <Button
                    type="default"
                    disabled={selectedRowKeys.length === 0}
                    onClick={() => setSelectedRowKeys([])}
                >
                    清除导出
                </Button>
                <Button
                    icon={<ReloadOutlined />}
                    onClick={handleRefresh}
                    loading={refreshing}
                >
                    刷新
                </Button>
            </Space>
            <Table
                rowSelection={{
                    selectedRowKeys,
                    onChange: (keys) => setSelectedRowKeys(keys),
                }}
                dataSource={filteredLayers}
                columns={columns}
                rowKey="id"
                pagination={{
                    current: currentPage,
                    pageSize: pageSize,
                    total: filteredLayers.length,
                    showTotal: (total) => `共 ${total} 条数据`,
                    showSizeChanger: true,
                    showQuickJumper: true,
                    pageSizeOptions: ['10', '20', '50', '100'],
                    onChange: handlePageChange,
                    onShowSizeChange: handlePageChange
                }}
            />

            {/* 图片预览模态框 */}
            <ImagePreviewModal
                visible={previewVisible}
                imageUrl={previewImage}
                onClose={() => {
                    setPreviewVisible(false);
                    setPreviewLayerInfo(null);
                }}
                layerInfo={previewLayerInfo}
            />
        </div>
    );
};

export default FullListView;
