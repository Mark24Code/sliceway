import React from 'react';
import { Card, Typography, Space, Button, Divider, Row, Col } from 'antd';
import { GithubOutlined, BookOutlined, UserOutlined, BugOutlined, QuestionCircleOutlined } from '@ant-design/icons';
import './About.scss';

const { Title, Paragraph, Text, Link } = Typography;

const About: React.FC = () => {
    return (
        <div className="about-page">
            <div className="about-page__header">
                <Title level={1} className="about-page__title">
                    <QuestionCircleOutlined style={{ marginRight: 12 }} />
                    关于 & 帮助
                </Title>
                <Paragraph className="about-page__subtitle">
                    现代化的 Photoshop 文件处理和导出工具
                </Paragraph>
            </div>

            <Row gutter={[24, 24]} className="about-page__content">
                {/* 项目信息 */}
                <Col xs={24} lg={12}>
                    <Card
                        title="项目信息"
                        className="about-page__card"
                        bordered={false}
                    >
                        <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                            <div>
                                <Text strong>Sliceway</Text>
                            </div>
                            <div>
                                <Paragraph style={{ margin: '8px 0' }}>
                                    一个现代化的 Photoshop 文件处理和导出工具，支持智能 PSD 解析、批量导出和项目管理。
                                </Paragraph>
                            </div>
                            <div>
                                <Text strong>作者:</Text>
                                <Paragraph style={{ margin: '8px 0' }}>Mark24</Paragraph>
                            </div>
                            <div>
                                <Text strong>GitHub:</Text>
                                <Paragraph style={{ margin: '8px 0' }}>
                                    <Link
                                        href="https://github.com/mark24code"
                                        target="_blank"
                                        rel="noopener noreferrer"
                                    >
                                        <UserOutlined style={{ marginRight: 8 }} />
                                        github.com/mark24code
                                    </Link>
                                </Paragraph>
                            </div>
                        </Space>
                    </Card>
                </Col>

                {/* 快速链接 */}
                <Col xs={24}>
                    <Card
                        title="快速链接"
                        className="about-page__card"
                        bordered={false}
                    >
                        <Row gutter={[16, 16]}>
                            <Col xs={24} sm={24} md={24}>
                                <Button
                                    type="primary"
                                    icon={<GithubOutlined />}
                                    size="large"
                                    block
                                    href="https://github.com/mark24code/sliceway"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                >
                                    GitHub 仓库
                                </Button>
                            </Col>
                            <Col xs={24} sm={12} md={8}>
                                <Button
                                    icon={<BookOutlined />}
                                    size="large"
                                    block
                                    href="https://github.com/mark24code/sliceway/blob/main/README.md"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                >
                                    中文文档
                                </Button>
                            </Col>
                            <Col xs={24} sm={12} md={8}>
                                <Button
                                    icon={<BookOutlined />}
                                    size="large"
                                    block
                                    href="https://github.com/mark24code/sliceway/blob/main/README_EN.md"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                >
                                    English Docs
                                </Button>
                            </Col>
                            <Col xs={24} sm={12} md={8}>
                                <Button
                                    icon={<BugOutlined />}
                                    size="large"
                                    block
                                    href="https://github.com/mark24code/sliceway/issues"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                >
                                    提交 Issue
                                </Button>
                            </Col>
                        </Row>
                    </Card>
                </Col>

                {/* 功能特性 */}
                <Col xs={24}>
                    <Card
                        title="功能特性"
                        className="about-page__card"
                        bordered={false}
                    >
                        <Row gutter={[16, 16]}>
                            <Col xs={24} sm={12} md={8}>
                                <div className="about-page__feature">
                                    <Title level={4}>智能 PSD 解析</Title>
                                    <Paragraph>
                                        自动解析 Photoshop 文件中的图层、切片、组和文字
                                    </Paragraph>
                                </div>
                            </Col>
                            <Col xs={24} sm={12} md={8}>
                                <div className="about-page__feature">
                                    <Title level={4}>批量导出</Title>
                                    <Paragraph>
                                        支持多倍率导出 (1x, 2x, 4x)
                                    </Paragraph>
                                </div>
                            </Col>
                            <Col xs={24} sm={12} md={8}>
                                <div className="about-page__feature">
                                    <Title level={4}>项目管理</Title>
                                    <Paragraph>
                                        完整的项目生命周期管理
                                    </Paragraph>
                                </div>
                            </Col>
                            <Col xs={24} sm={12} md={8}>
                                <div className="about-page__feature">
                                    <Title level={4}>实时预览</Title>
                                    <Paragraph>
                                        图层预览和属性查看
                                    </Paragraph>
                                </div>
                            </Col>
                            <Col xs={24} sm={12} md={8}>
                                <div className="about-page__feature">
                                    <Title level={4}>增量更新</Title>
                                    <Paragraph>
                                        基于内容哈希的智能导出
                                    </Paragraph>
                                </div>
                            </Col>
                            <Col xs={24} sm={12} md={8}>
                                <div className="about-page__feature">
                                    <Title level={4}>Docker 支持</Title>
                                    <Paragraph>
                                        支持 Docker 容器化部署
                                    </Paragraph>
                                </div>
                            </Col>
                        </Row>
                    </Card>
                </Col>
            </Row>

            <Divider />

            <div className="about-page__footer">
                <Paragraph style={{ textAlign: 'center', color: '#666' }}>
                    Made with ❤️ for designers and developers
                </Paragraph>
            </div>
        </div>
    );
};

export default About;
