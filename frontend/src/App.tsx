import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import ProjectList from './pages/ProjectList';
import ProjectDetail from './pages/ProjectDetail';
import About from './pages/About';
import GlobalLoading from './components/GlobalLoading';
import InteractiveView from './components/InteractiveView/InteractiveView';
import FullListView from './components/ListView/FullListView';
import 'antd/dist/reset.css';
import './styles/main.scss';

const App: React.FC = () => {
  return (
    <>
      <Router>
        <Routes>
          <Route path="/" element={<Navigate to="/projects" replace />} />
          <Route path="/projects" element={<ProjectList />} />
          <Route path="/projects/:id" element={<ProjectDetail />}>
            <Route index element={<Navigate to="interactive" replace />} />
            <Route path="interactive" element={<InteractiveView />} />
            <Route path="list" element={<FullListView />} />
          </Route>
          <Route path="/about" element={<About />} />
        </Routes>
      </Router>
      <GlobalLoading />
    </>
  );
};

export default App;
