import React, { useState } from 'react';
import { Button, Modal, Checkbox } from 'antd';
import { SettingOutlined } from '@ant-design/icons';

interface ExportConfigButtonProps {
    value: string[];
    onChange: (value: string[]) => void;
    trimTransparent?: boolean;
    onTrimTransparentChange?: (value: boolean) => void;
}

const ExportConfigButton: React.FC<ExportConfigButtonProps> = ({
    value,
    onChange,
    trimTransparent = false,
    onTrimTransparentChange
}) => {
    const [visible, setVisible] = useState(false);
    const [tempValue, setTempValue] = useState<string[]>(value);
    const [tempTrimTransparent, setTempTrimTransparent] = useState(trimTransparent);

    const handleOpen = () => {
        setTempValue(value);
        setTempTrimTransparent(trimTransparent);
        setVisible(true);
    };

    const handleOk = () => {
        onChange(tempValue);
        if (onTrimTransparentChange) {
            onTrimTransparentChange(tempTrimTransparent);
        }
        setVisible(false);
    };

    const handleCancel = () => {
        setVisible(false);
    };

    const options = ['1x', '2x', '4x'];

    return (
        <>
            <Button icon={<SettingOutlined />} onClick={handleOpen}>
                导出设置 ({value.join(', ')}{trimTransparent ? ', 去透明' : ''})
            </Button>
            <Modal
                title="导出配置"
                open={visible}
                okText='确认'
                cancelText='取消'
                onOk={handleOk}
                onCancel={handleCancel}
                width={300}
            >
                <div style={{ padding: '20px 0' }}>
                    <p style={{ marginBottom: 10 }}>选择导出倍率：</p>
                    <Checkbox.Group
                        options={options}
                        value={tempValue}
                        onChange={(vals) => setTempValue(vals as string[])}
                    />

                    <div style={{ marginTop: 20, paddingTop: 20, borderTop: '1px solid #f0f0f0' }}>
                        <Checkbox
                            checked={tempTrimTransparent}
                            onChange={(e) => setTempTrimTransparent(e.target.checked)}
                        >
                            去除透明背景
                        </Checkbox>
                        <div style={{ marginTop: 8, fontSize: 12, color: '#666', marginLeft: 24 }}>
                            自动裁剪图片周围的透明区域，保留最小尺寸
                        </div>
                    </div>
                </div>
            </Modal>
        </>
    );
};

export default ExportConfigButton;
