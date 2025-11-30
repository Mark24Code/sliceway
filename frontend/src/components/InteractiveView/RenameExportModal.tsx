import React, { useState, useEffect } from 'react';
import { Modal, List, Input, Avatar } from 'antd';
import type { Layer } from '../../types';
import { IMAGE_BASE_URL } from '../../config';

interface RenameExportModalProps {
  visible: boolean;
  onCancel: () => void;
  onConfirm: (renames: Record<number, string>) => void;
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
    }
  }, [visible, layers]);

  const handleNameChange = (id: number, value: string) => {
    setRenames(prev => ({
      ...prev,
      [id]: value
    }));
  };

  const handleOk = () => {
    onConfirm(renames);
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
