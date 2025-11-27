import React, { useState, useCallback } from 'react';
import { Table, Button, Input, Space, message } from 'antd';
import { useAtom } from 'jotai';
import { debounce } from 'lodash';
import { layersAtom, projectAtom, globalLoadingAtom } from '../../store/atoms';
import client from '../../api/client';
import type { Layer } from '../../types';

const FullListView: React.FC = () => {
    const [layers] = useAtom(layersAtom);
    const [project] = useAtom(projectAtom);
    const [, setGlobalLoading] = useAtom(globalLoadingAtom);
    const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([]);
    const [searchText, setSearchText] = useState('');

    const handleExport = useCallback(async (ids: number[]) => {
        if (!project) return;

        setGlobalLoading(true);
        try {
            const res = await client.post(`/projects/${project.id}/export`, { layer_ids: ids });
            message.success(`已导出 ${res.data.count} 个文件到 ${res.data.path}`);
        } catch (error) {
            message.error('导出失败');
        } finally {
            setGlobalLoading(false);
        }
    }, [project, setGlobalLoading]);

    // 防抖导出函数
    const debouncedExport = useCallback(
        debounce((ids: number[]) => {
            handleExport(ids);
        }, 500),
        [handleExport]
    );

    const filteredLayers = layers.filter(l => {
        if (!searchText) return true;

        const searchLower = searchText.toLowerCase();
        return (
            l.name?.toLowerCase().includes(searchLower) ||
            l.resource_id?.includes(searchText)
        );
    });

    const columns = [
        {
            title: '预览',
            key: 'preview',
            render: (_: any, record: Layer) => (
                record.image_path ?
                    <img src={`http://localhost:4567/${record.image_path}`} alt={record.name} style={{ maxHeight: 40, maxWidth: 40 }} /> :
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
            <Space style={{ marginBottom: 16 }}>
                <Input
                    placeholder="按名称或ID搜索"
                    value={searchText}
                    onChange={e => setSearchText(e.target.value)}
                    style={{ width: 300 }}
                />
                <Button
                    type="primary"
                    disabled={selectedRowKeys.length === 0}
                    onClick={() => debouncedExport(selectedRowKeys as number[])}
                >
                    导出选中项 ({selectedRowKeys.length})
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
                pagination={{ pageSize: 20 }}
            />
        </div>
    );
};

export default FullListView;
