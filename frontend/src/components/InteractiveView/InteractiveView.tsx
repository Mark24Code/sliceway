import React from 'react';
import { Layout } from 'antd';
import ScannerPreview from './ScannerPreview';
import FilterList from './FilterList';
import DetailPanel from './DetailPanel';
import PreviewControls from './PreviewControls';

const { Content, Sider } = Layout;

const InteractiveView: React.FC = () => {
    return (
        <Layout className="interactive-view-container">
            <Layout>
                <Content style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
                    <div className="scanner-section">
                        <ScannerPreview />
                        <PreviewControls />
                    </div>
                    <div className="filter-section">
                        <FilterList />
                    </div>
                </Content>
            </Layout>
            <Sider width={300} theme="light" style={{ borderLeft: '1px solid #ddd' }}>
                <DetailPanel />
            </Sider>
        </Layout>
    );
};

export default InteractiveView;
