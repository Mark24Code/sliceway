import React, { useEffect, useState, useCallback, useMemo } from 'react';
import { Table, Button, Modal, Form, Input, Upload, message, Tag, Select, DatePicker, Space, Tooltip, Descriptions, Typography } from 'antd';
import { InboxOutlined, PlusOutlined } from '@ant-design/icons';
import FolderSelector from '../../components/FolderSelector';
import { useNavigate } from 'react-router-dom';
import { useAtom } from 'jotai';
import { debounce } from 'lodash';
import dayjs, { Dayjs } from 'dayjs';
import { globalLoadingAtom } from '../../store/atoms';
import client from '../../api/client';
import type { Project } from '../../types';
import { truncatePathFromStart } from '../../utils/string';
import { API_BASE_URL } from '../../config';
import './ProjectList.scss';

const { Dragger } = Upload;

const ProjectList: React.FC = () => {
    const [projects, setProjects] = useState<Project[]>([]);
    const [loading, setLoading] = useState(false);
    const [isModalVisible, setIsModalVisible] = useState(false);
    const [form] = Form.useForm();
    const navigate = useNavigate();
    const [, setGlobalLoading] = useAtom(globalLoadingAtom);

    // 筛选状态
    const [nameFilter, setNameFilter] = useState('');
    const [statusFilter, setStatusFilter] = useState<string>('');
    const [dateRangeFilter, setDateRangeFilter] = useState<[Dayjs, Dayjs] | null>(null);

    // 查看详情状态
    const [detailModalVisible, setDetailModalVisible] = useState(false);
    const [currentProject, setCurrentProject] = useState<Project | null>(null);

    const fetchProjects = async () => {
        setLoading(true);
        try {
            const res = await client.get('/projects');
            setProjects(res.data.projects);
        } catch (error) {
            message.error('获取项目列表失败');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchProjects();

        // WebSocket connection - use same base URL as API
        const wsUrl = API_BASE_URL.replace(/^http/, 'ws') + '/ws';
        const ws = new WebSocket(wsUrl);

        ws.onopen = () => {
            console.log('Connected to WebSocket');
        };

        ws.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                if (data.type === 'status_update') {
                    const projectId = Number(data.project_id);
                    setProjects(prevProjects =>
                        prevProjects.map(p =>
                            p.id === projectId ? { ...p, status: data.status } : p
                        )
                    );
                } else if (data.type === 'project_created') {
                    // 当有新项目创建时，重新获取项目列表
                    fetchProjects();
                }
            } catch (e) {
                console.error('Failed to parse WebSocket message', e);
            }
        };

        ws.onclose = () => {
            console.log('Disconnected from WebSocket');
        };

        return () => {
            ws.close();
        };
    }, []);

    const handleCreate = useCallback(async (values: any) => {
        const formData = new FormData();
        formData.append('name', values.name);
        if (values.export_path) formData.append('export_path', values.export_path);
        if (values.export_scales) formData.append('export_scales', JSON.stringify(values.export_scales));
        if (values.file && values.file.length > 0) {
            formData.append('file', values.file[0].originFileObj);
        } else {
            message.error('请上传PSD文件');
            return;
        }

        setGlobalLoading(true);
        try {
            await client.post('/projects', formData, {
                headers: { 'Content-Type': 'multipart/form-data' },
            });
            message.success('项目创建成功');
            setIsModalVisible(false);
            form.resetFields();
            fetchProjects();
        } catch (error) {
            message.error('创建项目失败');
        } finally {
            setGlobalLoading(false);
        }
    }, [form, setGlobalLoading]);

    // 防抖创建函数
    const debouncedCreate = useCallback(
        debounce((values: any) => {
            handleCreate(values);
        }, 500),
        [handleCreate]
    );

    const handleDelete = useCallback(async (id: number, status: string) => {
        let content = '确定要删除此项目吗？此操作将删除项目及其相关文件。';

        // 根据项目状态显示不同的提示信息
        if (status === 'processing') {
            content = '确定要删除此项目吗？此操作将先停止正在进行的处理任务，然后删除项目及其相关文件。';
        } else if (status === 'ready') {
            content = '确定要删除此项目吗？此操作将清理所有已生成的文件，然后删除项目记录。';
        }

        Modal.confirm({
            title: '确认删除',
            content: content,
            okText: '确认',
            cancelText: '取消',
            onOk: async () => {
                setGlobalLoading(true);
                try {
                    await client.delete(`/projects/${id}`);
                    message.success('项目删除成功');
                    fetchProjects();
                } catch (error) {
                    message.error('删除项目失败');
                } finally {
                    setGlobalLoading(false);
                }
            }
        });
    }, [setGlobalLoading]);

    const handleProcess = useCallback(async (id: number) => {
        Modal.confirm({
            title: '确认处理',
            content: '确定要开始处理此项目吗？这将启动PSD文件的切图处理。',
            okText: '确认',
            cancelText: '取消',
            onOk: async () => {
                setGlobalLoading(true);
                try {
                    await client.post(`/projects/${id}/process`);
                    message.success('项目处理已开始');
                    fetchProjects();
                } catch (error) {
                    message.error('处理项目失败');
                } finally {
                    setGlobalLoading(false);
                }
            }
        });
    }, [setGlobalLoading]);

    const handleStopProcess = useCallback(async (id: number) => {
        Modal.confirm({
            title: '停止处理',
            content: '确定要停止处理此项目吗？这将中断正在进行的处理任务并清理已生成的文件。',
            okText: '确认',
            cancelText: '取消',
            onOk: async () => {
                setGlobalLoading(true);
                try {
                    await client.post(`/projects/${id}/stop`);
                    message.success('项目处理已停止');
                    fetchProjects();
                } catch (error) {
                    message.error('停止处理失败');
                } finally {
                    setGlobalLoading(false);
                }
            }
        });
    }, [setGlobalLoading]);

    // 防抖处理函数
    const debouncedProcess = useCallback(
        debounce((id: number) => {
            handleProcess(id);
        }, 500),
        [handleProcess]
    );

    // 防抖停止处理函数
    const debouncedStopProcess = useCallback(
        debounce((id: number) => {
            handleStopProcess(id);
        }, 500),
        [handleStopProcess]
    );

    // 防抖删除函数
    const debouncedDelete = useCallback(
        debounce((id: number, status: string) => {
            handleDelete(id, status);
        }, 500),
        [handleDelete]
    );


    const getStatusText = (status: string) => {
        const statusMap: Record<string, string> = {
            ready: '就绪',
            processing: '处理中',
            error: '错误',
            pending: '待处理'
        };
        return statusMap[status] || status;
    };

    const getStatusTagClass = (status: string) => {
        const statusMap: Record<string, string> = {
            'ready': 'project-list__status--ready',
            'processing': 'project-list__status--processing',
            'error': 'project-list__status--error',
            'pending': 'project-list__status--pending'
        };
        return statusMap[status] || 'project-list__status--default';
    };

    const handleViewDetail = useCallback((project: Project) => {
        if (!project || !project.id) {
            message.error('无效的项目数据');
            return;
        }
        setCurrentProject(project);
        setDetailModalVisible(true);
    }, []);

    const handleCopyPath = useCallback(async (path: string) => {
        try {
            await navigator.clipboard.writeText(path);
            message.success('路径已复制到剪贴板');
        } catch (error) {
            message.error('复制失败');
        }
    }, []);

    // 筛选后的项目列表
    const filteredProjects = useMemo(() => {
        return projects.filter(project => {
            // 名称筛选
            if (nameFilter && !project.name.toLowerCase().includes(nameFilter.toLowerCase())) {
                return false;
            }

            // 状态筛选
            if (statusFilter && project.status !== statusFilter) {
                return false;
            }

            // 时间筛选
            if (dateRangeFilter) {
                const [start, end] = dateRangeFilter;
                const projectDate = dayjs(project.created_at);
                if (projectDate.isBefore(start) || projectDate.isAfter(end)) {
                    return false;
                }
            }

            return true;
        });
    }, [projects, nameFilter, statusFilter, dateRangeFilter]);

    const columns = [
        {
            title: 'ID',
            dataIndex: 'id',
            key: 'id',
        },
        {
            title: '名称',
            dataIndex: 'name',
            key: 'name',
            render: (text: string, record: Project) => (
                <a
                    className="project-list__project-link"
                    onClick={() => navigate(`/projects/${record.id}`)}
                >
                    {text}
                </a>
            ),
        },
        {
            title: '状态',
            dataIndex: 'status',
            key: 'status',
            render: (status: string) => {
                return (
                    <div className="project-list__status-indicator">
                        <div className={`project-list__status-icon project-list__status-icon--${status}`}></div>
                        <span className="project-list__status-text">{getStatusText(status)}</span>
                    </div>
                );
            },
        },
        {
            title: 'PSD路径',
            dataIndex: 'psd_path',
            key: 'psd_path',
            render: (path: string) => path ? (
                <Tooltip title={path} placement="topLeft">
                    <span style={{ maxWidth: 200, overflow: 'hidden', whiteSpace: 'nowrap', textAlign: 'right' }}>
                        {truncatePathFromStart(path, 20)}
                    </span>
                </Tooltip>
            ) : '-',
        },
        {
            title: '导出路径',
            dataIndex: 'export_path',
            key: 'export_path',
            render: (path: string) => path ? (
                <Tooltip title={path} placement="topLeft">
                    <span style={{ maxWidth: 200, overflow: 'hidden', whiteSpace: 'nowrap', textAlign: 'right' }}>
                        {truncatePathFromStart(path, 20)}
                    </span>
                </Tooltip>
            ) : '-',
        },
        {
            title: '导出倍率',
            dataIndex: 'export_scales',
            key: 'export_scales',
            render: (scales: string[]) => (
                <Space size={4}>
                    {scales && scales.length > 0 ? scales.map(scale => (
                        <Tag key={scale} color="blue">{scale}</Tag>
                    )) : <Tag>1x</Tag>}
                </Space>
            ),
        },
        {
            title: '创建时间',
            dataIndex: 'created_at',
            key: 'created_at',
            render: (date: string) => new Date(date).toLocaleString(),
        },
        {
            title: '操作',
            key: 'action',
            render: (_: any, record: Project) => (
                <Space>
                    <Button
                        type="default"
                        className="project-list__action-button--view"
                        onClick={() => handleViewDetail(record)}
                    >
                        摘要
                    </Button>
                    <Button
                        type="primary"
                        className="project-list__action-button--view"
                        onClick={() => navigate(`/projects/${record.id}`)}
                    >
                        进入
                    </Button>
                    {record.status === 'processing' ? (
                        <Button
                            type="primary"
                            danger
                            className="project-list__action-button--stop"
                            onClick={() => debouncedStopProcess(record.id)}
                        >
                            停止处理
                        </Button>
                    ) : (
                        <Button
                            type="primary"
                            className="project-list__action-button--process"
                            onClick={() => debouncedProcess(record.id)}
                            disabled={record.status === 'ready'}
                        >
                            开始处理
                        </Button>
                    )}
                    <Button
                        danger
                        className="project-list__action-button--delete"
                        onClick={() => debouncedDelete(record.id, record.status)}
                    >
                        删除
                    </Button>
                </Space>
            ),
        },
    ];

    return (
        <div className="project-list">
            <div className="project-list__header">
                <h1 className="project-list__header-title">项目列表</h1>
                <div className="project-list__header-actions">
                    <Button
                        type="primary"
                        icon={<PlusOutlined />}
                        onClick={() => setIsModalVisible(true)}
                    >
                        新建项目
                    </Button>
                </div>
            </div>

            {/* 筛选表单 */}
            <div className="project-list__filters" style={{ marginBottom: 16, padding: 16, background: '#fafafa', borderRadius: 6 }}>
                <Form layout="inline" className="project-list__filter-form">
                    <Form.Item label="项目名称">
                        <Input
                            placeholder="按项目名称搜索"
                            value={nameFilter}
                            onChange={e => setNameFilter(e.target.value)}
                            style={{ width: 200 }}
                        />
                    </Form.Item>
                    <Form.Item label="项目状态">
                        <Select
                            placeholder="选择状态"
                            value={statusFilter}
                            onChange={setStatusFilter}
                            style={{ width: 120 }}
                            allowClear
                        >
                            <Select.Option value="ready">就绪</Select.Option>
                            <Select.Option value="processing">处理中</Select.Option>
                            <Select.Option value="error">错误</Select.Option>
                            <Select.Option value="pending">待处理</Select.Option>
                        </Select>
                    </Form.Item>
                    <Form.Item label="创建时间">
                        <DatePicker.RangePicker
                            placeholder={['开始时间', '结束时间']}
                            value={dateRangeFilter}
                            onChange={(dates) => setDateRangeFilter(dates as [Dayjs, Dayjs] | null)}
                            style={{ width: 240 }}
                        />
                    </Form.Item>
                    <Form.Item>
                        <Button
                            onClick={() => {
                                setNameFilter('');
                                setStatusFilter('');
                                setDateRangeFilter(null);
                            }}
                        >
                            清除筛选
                        </Button>
                    </Form.Item>
                </Form>
            </div>

            <Table
                className="project-list__table"
                dataSource={filteredProjects}
                columns={columns}
                rowKey="id"
                loading={loading}
                locale={{
                    emptyText: '暂无数据'
                }}
            />

            <Modal
                className="project-list__modal"
                title="创建新项目"
                open={isModalVisible}
                onCancel={() => setIsModalVisible(false)}
                onOk={() => form.submit()}
                okText="确定"
                cancelText="取消"
            >
                <Form form={form} layout="vertical" onFinish={debouncedCreate}>
                    <Form.Item name="name" label="项目名称" rules={[{ required: true, message: '请输入项目名称' }]}>
                        <Input placeholder="请输入项目名称" />
                    </Form.Item>
                    <Form.Item
                      name="export_path"
                      label="导出路径"
                      rules={[
                        {
                          validator: (_, value) => {
                            if (!value) return Promise.resolve();
                            // 基本路径格式验证
                            if (value.includes('..') || value.includes('//')) {
                              return Promise.reject(new Error('路径格式不正确'));
                            }
                            return Promise.resolve();
                          }
                        }
                      ]}
                    >
                        <FolderSelector placeholder="可选：选择导出文件夹或输入绝对路径" />
                    </Form.Item>
                    <Form.Item name="export_scales" label="导出倍率" initialValue={['1x']}>
                        <Select mode="multiple" placeholder="选择导出倍率">
                            <Select.Option value="1x">1x</Select.Option>
                            <Select.Option value="2x">2x</Select.Option>
                            <Select.Option value="4x">4x</Select.Option>
                        </Select>
                    </Form.Item>
                    <Form.Item name="file" label="PSD/PSB文件" valuePropName="fileList" getValueFromEvent={(e: any) => {
                        if (Array.isArray(e)) return e;
                        return e?.fileList;
                    }} rules={[{ required: true, message: '请上传PSD/PSB文件' }]}>
                        <Dragger maxCount={1} accept=".psd,.psb" beforeUpload={() => false}>
                            <p className="ant-upload-drag-icon">
                                <InboxOutlined />
                            </p>
                            <p className="ant-upload-text">点击或拖拽文件到此区域上传</p>
                        </Dragger>
                    </Form.Item>
                </Form>
            </Modal>

            {/* 项目详情Modal */}
            <Modal
                title="项目详情"
                open={detailModalVisible}
                onCancel={() => setDetailModalVisible(false)}
                footer={[
                    <Button key="close" onClick={() => setDetailModalVisible(false)}>
                        关闭
                    </Button>
                ]}
                width={600}
            >
                {currentProject ? (
                    <Descriptions column={1} bordered>
                        <Descriptions.Item label="项目名称">
                            {currentProject.name}
                        </Descriptions.Item>
                        <Descriptions.Item label="项目状态">
                            <Tag
                                color={currentProject.status === 'ready' ? 'success' :
                                    currentProject.status === 'processing' ? 'processing' :
                                        currentProject.status === 'error' ? 'error' : 'default'}
                                className={getStatusTagClass(currentProject.status)}
                            >
                                {getStatusText(currentProject.status)}
                            </Tag>
                        </Descriptions.Item>
                        <Descriptions.Item label="PSD文件路径">
                            <Space>
                                <Typography.Text
                                    style={{ maxWidth: 400, wordBreak: 'break-all' }}
                                    copyable={{ text: currentProject.psd_path, tooltips: ['复制路径', '已复制'] }}
                                >
                                    {currentProject.psd_path}
                                </Typography.Text>
                                <Button
                                    type="link"
                                    size="small"
                                    onClick={() => handleCopyPath(currentProject.psd_path)}
                                >
                                    复制
                                </Button>
                            </Space>
                        </Descriptions.Item>
                        <Descriptions.Item label="导出路径">
                            {currentProject.export_path ? (
                                <Space>
                                    <Typography.Text
                                        style={{ maxWidth: 400, wordBreak: 'break-all' }}
                                        copyable={{ text: currentProject.export_path, tooltips: ['复制路径', '已复制'] }}
                                    >
                                        {currentProject.export_path}
                                    </Typography.Text>
                                    <Button
                                        type="link"
                                        size="small"
                                        onClick={() => handleCopyPath(currentProject.export_path)}
                                    >
                                        复制
                                    </Button>
                                </Space>
                            ) : '未设置'}
                        </Descriptions.Item>
                        <Descriptions.Item label="创建时间">
                            {new Date(currentProject.created_at).toLocaleString()}
                        </Descriptions.Item>
                        <Descriptions.Item label="更新时间">
                            {currentProject.updated_at ? new Date(currentProject.updated_at).toLocaleString() : '暂无'}
                        </Descriptions.Item>
                        <Descriptions.Item label="页面尺寸">
                            {currentProject.width && currentProject.height
                                ? `${currentProject.width} × ${currentProject.height} px`
                                : '未设置'
                            }
                        </Descriptions.Item>
                    </Descriptions>
                ) : (
                    <div style={{ textAlign: 'center', padding: '40px 0' }}>
                        <p>项目信息加载中...</p>
                    </div>
                )}
            </Modal>
        </div>
    );
};

export default ProjectList;