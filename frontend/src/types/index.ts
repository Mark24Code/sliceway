export interface Project {
  id: number;
  name: string;
  psd_path: string;
  export_path: string;
  status: 'pending' | 'processing' | 'ready' | 'error';
  created_at: string;
  updated_at: string;
}

export interface Layer {
  id: number;
  project_id: number;
  resource_id: string;
  name: string;
  layer_type: 'slice' | 'layer' | 'group' | 'text';
  x: number;
  y: number;
  width: number;
  height: number;
  content?: string;
  image_path?: string;
  metadata?: any;
  parent_id?: number;
}

export interface ProjectListResponse {
  projects: Project[];
  total: number;
}

// 图层类型映射配置
export const LAYER_TYPE_MAP: Record<string, string> = {
  'slice': '切片',
  'layer': '图层',
  'group': '组',
  'text': '文本'
};
