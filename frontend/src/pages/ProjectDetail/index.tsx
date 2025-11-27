import React, { useEffect, useState } from 'react';
import { Layout, Menu, Spin, message } from 'antd';
import { useParams } from 'react-router-dom';
import { useAtom } from 'jotai';
import { AppstoreOutlined, ScanOutlined } from '@ant-design/icons';
import { projectAtom, layersAtom } from '../../store/atoms';
import client from '../../api/client';
import FullListView from '../../components/ListView/FullListView';
import InteractiveView from '../../components/InteractiveView/InteractiveView';
import './ProjectDetail.scss';

const { Sider, Content } = Layout;

const ProjectDetail: React.FC = () => {
    const { id } = useParams<{ id: string }>();
    const [project, setProject] = useAtom(projectAtom);
    const [, setLayers] = useAtom(layersAtom);
    const [loading, setLoading] = useState(true);
    const [view, setView] = useState<'list' | 'interactive'>('list');

    useEffect(() => {
        const fetchData = async () => {
            if (!id) return;
            try {
                const pRes = await client.get(`/projects/${id}`);
                setProject(pRes.data);

                const lRes = await client.get(`/projects/${id}/layers`);
                setLayers(lRes.data);
            } catch (error) {
                message.error('加载项目数据失败');
            } finally {
                setLoading(false);
            }
        };
        fetchData();
    }, [id, setProject, setLayers]);

    if (loading) {
        return (
            <div className="project-detail__loading">
                <Spin size="large" />
            </div>
        );
    }

    if (!project) {
        return (
            <div className="project-detail__not-found">
                项目未找到
            </div>
        );
    }

    return (
        <div className="project-detail">
            <Layout className="project-detail__layout">
                <Sider theme="light" width={200}>
                    <div className="project-detail__layout-title">
                        <h3>项目：{project.name}</h3>
                    </div>
                    <Menu
                        mode="inline"
                        selectedKeys={[view]}
                        onClick={({ key }) => setView(key as 'list' | 'interactive')}
                        items={[
                            {
                                key: 'list',
                                icon: <AppstoreOutlined />,
                                label: '完整列表'
                            },
                            {
                                key: 'interactive',
                                icon: <ScanOutlined />,
                                label: '交互视图'
                            },
                        ]}
                    />
                </Sider>
                <Layout>
                    <Content>
                        <div className={`project-detail__view-container project-detail__view-container--${view}`}>
                            {view === 'list' ? <FullListView /> : <InteractiveView />}
                        </div>
                    </Content>
                </Layout>
            </Layout>
        </div>
    );
};

export default ProjectDetail;