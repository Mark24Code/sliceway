import React, { useState, useEffect } from 'react';
import { Modal, List, Input, Avatar, Checkbox } from 'antd';
import type { Layer } from '../../types';
import { IMAGE_BASE_URL } from '../../config';

interface RenameExportModalProps {
  visible: boolean;
  onCancel: () => void;
  onConfirm: (renames: Record<number, string>, clearDirectory: boolean) => void;
  layers: Layer[];
  loading?: boolean;
}

const RenameExportModal: React.FC<RenameExportModalProps> = ({
  visible,
  onCancel,
  onConfirm,
  layers,
  loading = false
}) => {
  const [renames, setRenames] = useState<Record<number, string>>({});
  const [clearDirectory, setClearDirectory] = useState(false);

  // Initialize renames with current layer names when modal opens or layers change
  useEffect(() => {
    if (visible) {
      const initialRenames: Record<number, string> = {};
      layers.forEach(layer => {
        // Default to just the name, user can modify
        // Note: Backend default is name_id, but here we probably want to let user edit the base name
        initialRenames[layer.id] = layer.name;
      });
      setRenames(initialRenames);
      setClearDirectory(false); // Reset checkbox
    }
  }, [visible, layers]);

  const handleNameChange = (id: number, value: string) => {
    setRenames(prev => ({
      ...prev,
      [id]: value
    }));
  };

  const handleOk = () => {
    if (clearDirectory) {
      Modal.confirm({
        title: '确认清空目录？',
        content: '此操作将删除导出目录下的所有文件，且不可恢复。确定要继续吗？',
        okText: '确定清空并导出',
        cancelText: '取消',
        okType: 'danger',
        onOk: () => {
          onConfirm(renames, clearDirectory);
        }
      });
    } else {
      onConfirm(renames, clearDirectory);
    }
  };

  return (
    <Modal
      title="导出并重命名"
      open={visible}
      onCancel={onCancel}
      onOk={handleOk}
      confirmLoading={loading}
      width={600}
      okText="确认导出"
      cancelText="取消"
    >
      <div style={{ marginBottom: 16 }}>
        <Checkbox
          checked={clearDirectory}
          onChange={e => setClearDirectory(e.target.checked)}
        >
          清除导出目录 (清空目标文件夹中的所有文件)
        </Checkbox>
      </div>
      <div style={{ maxHeight: '60vh', overflowY: 'auto' }}>
        <List
          dataSource={layers}
          renderItem={layer => (
            <List.Item>
              <List.Item.Meta
                avatar={
                  <Avatar
                    src={layer.image_path ? `${IMAGE_BASE_URL}/${layer.image_path}` : undefined}
                    shape="square"
                    size={48}
                  />
                }
                title={
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ width: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', color: '#888' }}>
                      原名: {layer.name}
                    </span>
                    <Input
                      value={renames[layer.id]}
                      onChange={e => handleNameChange(layer.id, e.target.value)}
                      placeholder="输入新文件名"
                      style={{ flex: 1 }}
                    />
                  </div>
                }
                description={`ID: ${layer.id} | 尺寸: ${layer.width}x${layer.height}`}
              />
            </List.Item>
          )}
        />
      </div>
    </Modal>
  );
};

export default RenameExportModal;
