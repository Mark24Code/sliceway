import React, { useEffect, useState, useCallback, useMemo } from 'react';
import { Table, Button, Modal, Form, Input, Upload, message, Tag, Select, DatePicker, Space, Tooltip, Descriptions, Typography } from 'antd';
import { InboxOutlined, PlusOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import { useAtom } from 'jotai';
import { debounce } from 'lodash';
import dayjs, { Dayjs } from 'dayjs';
import { globalLoadingAtom } from '../../store/atoms';
import client from '../../api/client';
import type { Project } from '../../types';
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
    }, []);

    const handleCreate = useCallback(async (values: any) => {
        const formData = new FormData();
        formData.append('name', values.name);
        if (values.export_path) formData.append('export_path', values.export_path);
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

    const handleDelete = useCallback(async (id: number) => {
        Modal.confirm({
            title: '确认删除',
            content: '确定要删除此项目吗？此操作将删除项目及其相关文件。',
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

    // 防抖处理函数
    const debouncedProcess = useCallback(
        debounce((id: number) => {
            handleProcess(id);
        }, 500),
        [handleProcess]
    );

    // 防抖删除函数
    const debouncedDelete = useCallback(
        debounce((id: number) => {
            handleDelete(id);
        }, 500),
        [handleDelete]
    );

    const getStatusTagClass = (status: string) => {
        return `project-list__status-tag--${status}`;
    };

    const getStatusText = (status: string) => {
        const statusMap: Record<string, string> = {
            ready: '就绪',
            processing: '处理中',
            error: '错误',
            pending: '待处理'
        };
        return statusMap[status] || status;
    };

    const handleViewDetail = useCallback((project: Project) => {
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
                let color = 'default';
                if (status === 'ready') color = 'success';
                if (status === 'processing') color = 'processing';
                if (status === 'error') color = 'error';
                return (
                    <Tag
                        color={color}
                        className={getStatusTagClass(status)}
                    >
                        {getStatusText(status)}
                    </Tag>
                );
            },
        },
        {
            title: 'PSD路径',
            dataIndex: 'psd_path',
            key: 'psd_path',
            render: (path: string) => path ? (
                <Tooltip title={path} placement="topLeft">
                    <span style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'inline-block' }}>
                        {path}
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
                    <span style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'inline-block' }}>
                        {path}
                    </span>
                </Tooltip>
            ) : '-',
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
                        type="primary"
                        className="project-list__action-button--process"
                        onClick={() => debouncedProcess(record.id)}
                        disabled={record.status === 'processing' || record.status === 'ready'}
                    >
                        开始处理
                    </Button>
                    <Button
                        type="default"
                        className="project-list__action-button--view"
                        onClick={() => handleViewDetail(record)}
                    >
                        查看
                    </Button>
                    <Button
                        danger
                        className="project-list__action-button--delete"
                        onClick={() => debouncedDelete(record.id)}
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
                <Space wrap>
                    <Input
                        placeholder="按项目名称搜索"
                        value={nameFilter}
                        onChange={e => setNameFilter(e.target.value)}
                        style={{ width: 200 }}
                    />
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
                    <DatePicker.RangePicker
                        placeholder={['开始时间', '结束时间']}
                        value={dateRangeFilter}
                        onChange={(dates) => setDateRangeFilter(dates as [Dayjs, Dayjs] | null)}
                        style={{ width: 240 }}
                    />
                    <Button
                        onClick={() => {
                            setNameFilter('');
                            setStatusFilter('');
                            setDateRangeFilter(null);
                        }}
                    >
                        清除筛选
                    </Button>
                </Space>
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
                    <Form.Item name="export_path" label="导出路径">
                        <Input placeholder="可选：导出的绝对路径" />
                    </Form.Item>
                    <Form.Item name="file" label="PSD文件" valuePropName="fileList" getValueFromEvent={(e: any) => {
                        if (Array.isArray(e)) return e;
                        return e?.fileList;
                    }} rules={[{ required: true, message: '请上传PSD文件' }]}>
                        <Dragger maxCount={1} accept=".psd" beforeUpload={() => false}>
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
                {currentProject && (
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
                    </Descriptions>
                )}
            </Modal>
        </div>
    );
};

export default ProjectList;