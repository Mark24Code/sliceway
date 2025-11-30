import React, { useState, useEffect } from 'react';
import { Modal, List, Button, Spin, message, Empty } from 'antd';
import { FolderOutlined, ArrowUpOutlined, HomeOutlined } from '@ant-design/icons';
import client from '../../api/client';

interface ServerFolderSelectorProps {
  visible: boolean;
  onCancel: () => void;
  onSelect: (path: string) => void;
  initialPath?: string;
}

interface DirectoryData {
  current_path: string;
  parent_path: string;
  directories: string[];
  sep: string;
}

const ServerFolderSelector: React.FC<ServerFolderSelectorProps> = ({
  visible,
  onCancel,
  onSelect,
  initialPath
}) => {
  const [currentPath, setCurrentPath] = useState<string>('');
  const [directories, setDirectories] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const [parentPath, setParentPath] = useState<string>('');

  const fetchDirectories = async (path?: string) => {
    setLoading(true);
    try {
      const params = path ? { path } : {};
      const res = await client.get('/system/directories', { params });
      const data: DirectoryData = res.data;

      setCurrentPath(data.current_path);
      setParentPath(data.parent_path);
      setDirectories(data.directories);
    } catch (error) {
      console.error('Failed to fetch directories', error);
      message.error('无法获取目录列表');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (visible) {
      fetchDirectories(initialPath);
    }
  }, [visible, initialPath]);

  const handleNavigate = (dirName: string) => {
    // Construct new path based on separator (simple join for now, backend handles normalization)
    // Actually, we should just send the full path of the child
    // Since we don't have the separator easily available in the list item click without passing it down
    // Let's just rely on the backend to handle paths if we construct them,
    // OR we can ask the backend to return full paths.
    // But standard is usually joining currentPath + sep + dirName

    // A safer way is to let the backend handle path joining, but here we need to send the next path.
    // We can assume '/' for now or use the one returned by backend.
    const sep = '/'; // Default fallback, but we should use data.sep if we stored it.
    // Let's just use a simple join and let backend normalize.
    const nextPath = currentPath.endsWith(sep)
      ? `${currentPath}${dirName}`
      : `${currentPath}${sep}${dirName}`;

    fetchDirectories(nextPath);
  };

  const handleGoUp = () => {
    if (parentPath && parentPath !== currentPath) {
      fetchDirectories(parentPath);
    }
  };

  return (
    <Modal
      title="选择服务器目录"
      open={visible}
      onCancel={onCancel}
      width={600}
      footer={[
        <Button key="cancel" onClick={onCancel}>
          取消
        </Button>,
        <Button key="select" type="primary" onClick={() => onSelect(currentPath)}>
          选择当前目录: {currentPath.split('/').pop() || currentPath}
        </Button>
      ]}
    >
      <div className="server-folder-selector">
        <div className="server-folder-selector__header" style={{ marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
          <Button
            icon={<ArrowUpOutlined />}
            onClick={handleGoUp}
            disabled={!parentPath || parentPath === currentPath}
          >
            上级目录
          </Button>
          <div style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', background: '#f5f5f5', padding: '4px 8px', borderRadius: 4 }}>
            <HomeOutlined style={{ marginRight: 8 }} />
            {currentPath}
          </div>
        </div>

        <div className="server-folder-selector__content" style={{ height: 400, overflowY: 'auto', border: '1px solid #f0f0f0', borderRadius: 4 }}>
          {loading ? (
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%' }}>
              <Spin tip="加载中..." />
            </div>
          ) : (
            <List
              dataSource={directories}
              locale={{ emptyText: <Empty description="无子目录" /> }}
              renderItem={item => (
                <List.Item
                  className="server-folder-selector__item"
                  onClick={() => handleNavigate(item)}
                  style={{ cursor: 'pointer', padding: '8px 16px', transition: 'background 0.3s' }}
                >
                  <div style={{ display: 'flex', alignItems: 'center' }}>
                    <FolderOutlined style={{ marginRight: 8, color: '#1890ff', fontSize: 18 }} />
                    {item}
                  </div>
                </List.Item>
              )}
            />
          )}
        </div>
      </div>
    </Modal>
  );
};

export default ServerFolderSelector;
