import React, { useState } from 'react';
import { Button, Modal, Checkbox } from 'antd';
import { SettingOutlined } from '@ant-design/icons';

interface ExportConfigButtonProps {
    value: string[];
    onChange: (value: string[]) => void;
}

const ExportConfigButton: React.FC<ExportConfigButtonProps> = ({ value, onChange }) => {
    const [visible, setVisible] = useState(false);
    const [tempValue, setTempValue] = useState<string[]>(value);

    const handleOpen = () => {
        setTempValue(value);
        setVisible(true);
    };

    const handleOk = () => {
        onChange(tempValue);
        setVisible(false);
    };

    const handleCancel = () => {
        setVisible(false);
    };

    const options = ['1x', '2x', '4x'];

    return (
        <>
            <Button icon={<SettingOutlined />} onClick={handleOpen}>
                导出设置 ({value.join(', ')})
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
                </div>
            </Modal>
        </>
    );
};

export default ExportConfigButton;
