import React from 'react';
import { Layout } from 'antd';
import ScannerPreview from './ScannerPreview';
import FilterList from './FilterList';
import DetailPanel from './DetailPanel';
import PreviewControls from './PreviewControls';
import { useTheme } from '../../contexts/ThemeContext';

const { Content, Sider } = Layout;

const InteractiveView: React.FC = () => {
    const { theme } = useTheme();

    return (
        <Layout className="interactive-view-container">
            <Layout>
                <Content style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
                    <div className="middle-section">
                        <div className="preview-area">
                            <ScannerPreview />
                            <PreviewControls />
                        </div>
                        <div className="filter-section">
                            <FilterList />
                        </div>
                    </div>
                </Content>
            </Layout>
            <Sider
                width={300}
                theme={theme === 'dark' ? 'dark' : 'light'}
                style={{
                    borderLeft: `1px solid ${theme === 'dark' ? '#303030' : '#ddd'}`,
                    background: theme === 'dark' ? '#141414' : '#fff'
                }}
            >
                <DetailPanel />
            </Sider>
        </Layout>
    );
};

export default InteractiveView;
