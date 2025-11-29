import React, { useState, useRef } from 'react';
import { Input, Button, Tooltip, message } from 'antd';
import { FolderOpenOutlined, CloseOutlined } from '@ant-design/icons';
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
  const [isSelecting, setIsSelecting] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // 检查浏览器是否支持 showDirectoryPicker API
  const supportsDirectoryPicker = () => {
    return 'showDirectoryPicker' in window;
  };

  // 现代浏览器文件夹选择 - 返回文件夹名称
  const handleModernFolderSelect = async () => {
    if (disabled) return;

    setIsSelecting(true);
    try {
      // @ts-ignore - showDirectoryPicker API 类型定义可能不存在
      const directoryHandle = await window.showDirectoryPicker();
      const selectedPath = directoryHandle.name;

      if (onChange) {
        onChange(selectedPath);
      }
      message.success(`已选择文件夹: ${selectedPath}`);
      message.info('提示：由于浏览器安全限制，请手动输入完整的绝对路径');
    } catch (error) {
      // 用户取消选择或其他错误
      if (error instanceof Error && error.name !== 'AbortError') {
        console.error('Folder selection error:', error);
        message.error('文件夹选择失败');
      }
    } finally {
      setIsSelecting(false);
    }
  };

  // 传统浏览器文件夹选择（降级方案）
  const handleLegacyFolderSelect = () => {
    if (disabled) return;

    if (fileInputRef.current) {
      fileInputRef.current.click();
    }
  };

  const handleFileInputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const files = event.target.files;
    if (files && files.length > 0) {
      // 使用 webkitRelativePath 获取文件夹路径
      const relativePath = files[0].webkitRelativePath;
      const folderName = relativePath.split('/')[0];

      if (onChange) {
        onChange(folderName);
      }
      message.success(`已选择文件夹: ${folderName}`);
      message.info('提示：由于浏览器安全限制，请手动输入完整的绝对路径');
    }

    // 重置文件输入，允许重复选择同一文件夹
    if (event.target) {
      event.target.value = '';
    }
  };

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

  const handleFolderSelect = () => {
    if (supportsDirectoryPicker()) {
      handleModernFolderSelect();
    } else {
      handleLegacyFolderSelect();
    }
  };

  return (
    <div className="folder-selector">
      <Input.Group compact className="folder-selector__group">
        <Input
          className="folder-selector__input"
          value={value}
          onChange={handleInputChange}
          placeholder={placeholder}
          disabled={disabled}
          allowClear={false}
        />
        <Tooltip title="选择文件夹（仅获取文件夹名称，请手动输入完整路径）">
          <Button
            className="folder-selector__button"
            icon={<FolderOpenOutlined />}
            onClick={handleFolderSelect}
            loading={isSelecting}
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
      </Input.Group>

      {/* 隐藏的文件输入元素，用于传统浏览器支持 */}
      <input
        ref={fileInputRef}
        type="file"
        style={{ display: 'none' }}
        // @ts-ignore - webkitdirectory is a non-standard attribute
        webkitdirectory=""
        multiple
        onChange={handleFileInputChange}
      />
    </div>
  );
};

export default FolderSelector;