import type { ComfyWorkflowJSON } from '@/types/comfyWorkflow'

// Empty default graph - workflow data will be loaded from MongoDB
export const defaultGraph: ComfyWorkflowJSON = {
  last_node_id: 0,
  last_link_id: 0,
  nodes: [],
  links: [],
  groups: [],
  config: {},
  extra: {},
  version: 0.4
}
