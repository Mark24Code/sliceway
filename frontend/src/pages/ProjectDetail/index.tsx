import React, { useEffect, useState } from "react";
import { Layout, Menu, Spin, message, Tag, Button } from "antd";
import { useParams, useNavigate, useLocation, Outlet } from "react-router-dom";
import { useAtom } from "jotai";
import {
  AppstoreOutlined,
  ScanOutlined,
  ArrowLeftOutlined,
} from "@ant-design/icons";
import { projectAtom, layersAtom } from "../../store/atoms";
import client from "../../api/client";
import "./ProjectDetail.scss";

const { Sider, Content } = Layout;

const ProjectDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const location = useLocation();
  const [project, setProject] = useAtom(projectAtom);
  const [, setLayers] = useAtom(layersAtom);
  const [loading, setLoading] = useState(true);

  // Determine current view based on URL
  const currentView = location.pathname.includes("/list")
    ? "list"
    : "interactive";

  useEffect(() => {
    const fetchData = async () => {
      if (!id) return;
      try {
        const pRes = await client.get(`/projects/${id}`);
        setProject(pRes.data);

        const lRes = await client.get(`/projects/${id}/layers`);
        setLayers(lRes.data);
      } catch (error) {
        message.error("加载项目数据失败");
      } finally {
        setLoading(false);
      }
    };
    fetchData();

    // WebSocket connection
    const ws = new WebSocket("ws://localhost:4567/ws");

    ws.onopen = () => {
      console.log("Connected to WebSocket");
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.type === "status_update" && String(data.project_id) === id) {
          setProject((prev) =>
            prev ? { ...prev, status: data.status } : null
          );
        }
      } catch (e) {
        console.error("Failed to parse WebSocket message", e);
      }
    };

    return () => {
      ws.close();
    };
  }, [id, setProject, setLayers]);

  if (loading) {
    return (
      <div className="project-detail__loading">
        <Spin size="large" />
      </div>
    );
  }

  if (!project) {
    return <div className="project-detail__not-found">项目未找到</div>;
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case "ready":
        return "success";
      case "processing":
        return "processing";
      case "error":
        return "error";
      default:
        return "default";
    }
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case "ready":
        return "已就绪";
      case "processing":
        return "处理中";
      case "error":
        return "错误";
      case "pending":
        return "等待中";
      default:
        return status;
    }
  };

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return "0 B";
    const k = 1024;
    const sizes = ["B", "KB", "MB", "GB", "TB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
  };

  return (
    <div className="project-detail">
      <Layout className="project-detail__layout">
        <Sider theme="light" width={200}>
          {/* Logo 区域 */}
          <div className="project-detail__logo-area">
            <img src="/logo.svg" alt="Logo" className="project-detail__logo" />
          </div>

          {/* 返回按钮 */}
          <div className="project-detail__back-section">
            <Button
              type="text"
              icon={<ArrowLeftOutlined />}
              onClick={() => navigate("/projects")}
              className="project-detail__back-btn"
            >
              返回列表
            </Button>
          </div>

          <div className="project-detail__layout-title">
            <h3>项目：{project.name}</h3>
            <div style={{ marginTop: 8 }}>
              状态：
              <Tag
                color={
                  getStatusColor(project.status) === "success"
                    ? "success"
                    : getStatusColor(project.status) === "processing"
                    ? "processing"
                    : getStatusColor(project.status) === "error"
                    ? "error"
                    : "default"
                }
              >
                {getStatusText(project.status)}
              </Tag>
            </div>
            {/* 新增页面尺寸信息 */}
            {project.width && project.height && (
              <div style={{ marginTop: 8, fontSize: 12, color: "#666" }}>
                尺寸：{project.width} × {project.height} px
              </div>
            )}
            {project.file_size !== undefined && (
              <div style={{ marginTop: 4, fontSize: 12, color: "#666" }}>
                大小：{formatFileSize(project.file_size)}
              </div>
            )}
            {/* 导出倍率信息 */}
            {project.export_scales && project.export_scales.length > 0 && (
              <div style={{ marginTop: 4, fontSize: 12, color: "#666" }}>
                导出倍率：{project.export_scales.join(", ")}
              </div>
            )}
          </div>
          <Menu
            mode="inline"
            selectedKeys={[currentView]}
            onClick={({ key }) => navigate(key)}
            items={[
              {
                key: "list",
                icon: <AppstoreOutlined />,
                label: "完整列表",
              },
              {
                key: "interactive",
                icon: <ScanOutlined />,
                label: "交互视图",
              },
            ]}
          />
        </Sider>
        <Layout>
          <Content>
            <div
              className={`project-detail__view-container project-detail__view-container--${currentView}`}
            >
              <Outlet />
            </div>
          </Content>
        </Layout>
      </Layout>
    </div>
  );
};

export default ProjectDetail;
