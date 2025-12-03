import React, { useEffect, useState } from 'react';
import { Space, Typography, Tooltip } from 'antd';
import { InfoCircleOutlined } from '@ant-design/icons';
import client from '../api/client';

const { Text } = Typography;

interface VersionInfo {
  version: string;
  name: string;
  description: string;
}

const VersionInfo: React.FC = () => {
  const [versionInfo, setVersionInfo] = useState<VersionInfo | null>(null);

  useEffect(() => {
    const fetchVersion = async () => {
      try {
        const response = await client.get('/version');
        setVersionInfo(response.data);
      } catch (error) {
        console.error('Failed to fetch version info:', error);
      }
    };

    fetchVersion();
  }, []);

  const frontendVersion = '1.5.0';

  return (
    <Space size="small" style={{ marginLeft: 'auto' }}>
      <Text type="secondary" style={{ fontSize: '12px' }}>
        前端: v{frontendVersion}
      </Text>
      {versionInfo && (
        <>
          <Text type="secondary" style={{ fontSize: '12px' }}>
            后端: v{versionInfo.version}
          </Text>
          <Tooltip
            title={
              <div>
                <div><strong>{versionInfo.name}</strong></div>
                <div>{versionInfo.description}</div>
                <div>前端版本: v{frontendVersion}</div>
                <div>后端版本: v{versionInfo.version}</div>
              </div>
            }
            placement="topLeft"
          >
            <InfoCircleOutlined style={{ color: '#8c8c8c', cursor: 'pointer' }} />
          </Tooltip>
        </>
      )}
    </Space>
  );
};

export default VersionInfo;