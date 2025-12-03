import React, { useState } from 'react';
import { Input, Button, Tooltip, message, Space } from 'antd';
import { FolderOpenOutlined, CloseOutlined } from '@ant-design/icons';
import ServerFolderSelector from '../ServerFolderSelector';
import './FolderSelector.scss';

interface FolderSelectorProps {
  value?: string;
  onChange?: (value: string) => void;
  placeholder?: string;
  disabled?: boolean;
}

const FolderSelector: React.FC<FolderSelectorProps> = ({
  value,
  onChange,
  placeholder = '输入导出文件夹的绝对路径',
  disabled = false
}) => {
  const [isSelectorVisible, setIsSelectorVisible] = useState(false);

  const handleClear = () => {
    if (onChange) {
      onChange('');
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (onChange) {
      onChange(e.target.value);
    }
  };

  const handleFolderSelect = (path: string) => {
    if (onChange) {
      onChange(path);
    }
    setIsSelectorVisible(false);
    message.success(`已选择文件夹: ${path}`);
  };

  return (
    <div className="folder-selector">
      <Space.Compact className="folder-selector__group" style={{ width: '100%' }}>
        <Input
          className="folder-selector__input"
          value={value}
          onChange={handleInputChange}
          placeholder={placeholder}
          disabled={disabled}
          allowClear={false}
        />
        <Tooltip title="选择服务器文件夹">
          <Button
            className="folder-selector__button"
            icon={<FolderOpenOutlined />}
            onClick={() => setIsSelectorVisible(true)}
            disabled={disabled}
          />
        </Tooltip>
        {value && (
          <Tooltip title="清除">
            <Button
              className="folder-selector__clear-button"
              icon={<CloseOutlined />}
              onClick={handleClear}
              disabled={disabled}
            />
          </Tooltip>
        )}
      </Space.Compact>

      <ServerFolderSelector
        visible={isSelectorVisible}
        onCancel={() => setIsSelectorVisible(false)}
        onSelect={handleFolderSelect}
        initialPath={value}
      />
    </div>
  );
};

export default FolderSelector;