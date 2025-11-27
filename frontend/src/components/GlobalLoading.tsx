import React from 'react';
import { Spin } from 'antd';
import { useAtom } from 'jotai';
import { globalLoadingAtom } from '../store/atoms';

const GlobalLoading: React.FC = () => {
  const [loading] = useAtom(globalLoadingAtom);

  if (!loading) {
    return null;
  }

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
        backgroundColor: 'rgba(0, 0, 0, 0.3)',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        zIndex: 9999,
      }}
    >
      <Spin size="large" tip="处理中..." />
    </div>
  );
};

export default GlobalLoading;