# frozen_string_literal: true

class TaheController < ApiController
  
  # 获取用户信息
  get '/users' do
    content_type :json
    {
      users: [
        {
          id: 1,
          name: 'Default User',
          role: 'admin'
        }
      ]
    }.to_json
  end

  # Get user data
  get '/userdata' do
    content_type :json
    
    dir = params[:dir] || ''  # Directory to list
    recurse = params[:recurse] == 'true'  # Whether to recursively list subdirectories
    full_info = params[:full_info] == 'true'  # Whether to include full file info
    
    begin
      # Build MongoDB query based on directory and recursion
      query = {}
      if dir.empty?
        query = { path: /^workflows\// }
      else
        if recurse
          query = { path: /^#{Regexp.escape(dir)}/ }
        else
          # For non-recursive, only get files directly in this directory
          query = { path: /^#{Regexp.escape(dir)}\/[^\/]+$/ }
        end
      end
      
      # Get files from MongoDB
      files = M[:sys_files].query(query).to_a
      
      if full_info
        # Return detailed file information
        files_info = files.map do |file|
          {
            path: file['path'],
            name: file['name'],
            modified: file['modified'],
            size: file['size']
          }
        end
        files_info.to_json
      else
        # Return just file paths
        files.map { |f| f['path'] }.to_json
      end
      
    rescue => e
      status 500
      { error: "Error accessing user data: #{e.message}" }.to_json
    end
  end

  # Get specific user data file
  get '/userdata/*' do
    content_type :json
    file_path = params[:splat].first
    
    begin
      if file_path == 'workflows/.index.json'
        # Special handling for workflow index
        {
          favorites: [],
          customizations: {}
        }.to_json
      else
        # Get file from MongoDB
        file = M[:sys_files].query(path: file_path).first
        
        if file
          file['content']
        else
          status 404
          { error: 'File not found' }.to_json
        end
      end
      
    rescue => e
      status 500
      { error: "Error reading file: #{e.message}" }.to_json
    end
  end

  # Store user data file
  post '/userdata/*' do
    content_type :json
    file_path = params[:splat].first
    overwrite = params[:overwrite] == 'true'
    
    begin
      # Check if file exists
      existing_file = M[:sys_files].query(path: file_path).first
      
      if existing_file && !overwrite
        status 409
        return { error: 'File already exists' }.to_json
      end
      
      # Prepare file document
      file_doc = {
        path: file_path,
        name: File.basename(file_path),
        modified: Time.now.to_i,
        size: request.body.length,
        content: request.body.read,
        type: file_path.start_with?('workflows/') ? 'workflow' : 'file'
      }
      
      if existing_file
        # Update existing file
        M[:sys_files].update_one(
          { path: file_path },
          { '$set' => file_doc }
        )
      else
        # Insert new file
        M[:sys_files].insert_one(file_doc)
      end
      
      { success: true }.to_json
      
    rescue => e
      status 500
      { error: "Error saving file: #{e.message}" }.to_json
    end
  end

  # Move/rename user data file
  post '/userdata/*/move/*' do
    content_type :json
    source_path = params[:splat][0]
    dest_path = params[:splat][1]
    overwrite = params[:overwrite] == 'true'
    
    begin
      # Check if source exists
      source_file = M[:sys_files].query(path: source_path).first
      unless source_file
        status 404
        return { error: 'Source file not found' }.to_json
      end
      
      # Check if destination exists
      dest_file = M[:sys_files].query(path: dest_path).first
      if dest_file && !overwrite
        status 409
        return { error: 'Destination file already exists' }.to_json
      end
      
      # Update the file path
      source_file['path'] = dest_path
      source_file['name'] = File.basename(dest_path)
      source_file['modified'] = Time.now.to_i
      
      if dest_file
        # Update existing destination
        M[:sys_files].update_one(
          { path: dest_path },
          { '$set' => source_file }
        )
        # Remove source
        M[:sys_files].delete_one(path: source_path)
      else
        # Just update the source document
        M[:sys_files].update_one(
          { path: source_path },
          { '$set' => source_file }
        )
      end
      
      { success: true }.to_json
      
    rescue => e
      status 500
      { error: "Error moving file: #{e.message}" }.to_json
    end
  end

  # 获取设置
  get '/settings' do
    content_type :json
    {
      'Comfy.Graph.CanvasMenu': true,
      'Comfy.Graph.CanvasInfo': true,
      'Comfy.Graph.ZoomSpeed': 1.0,
      'Comfy.Node.ShowDeprecated': false,
      'Comfy.Node.ShowExperimental': true,
      'Comfy.TextareaWidget.Spellcheck': false,
      'Comfy.UseNewMenu': 'Enabled'
    }.to_json
  end

  # 获取特定设置
  get '/settings/:id' do
    content_type :json
    settings = {
      'Comfy.Graph.CanvasMenu' => true,
      'Comfy.Graph.CanvasInfo' => true,
      'Comfy.Graph.ZoomSpeed' => 1.0,
      'Comfy.Node.ShowDeprecated' => false,
      'Comfy.Node.ShowExperimental' => true,
      'Comfy.TextareaWidget.Spellcheck' => false,
      'Comfy.UseNewMenu' => 'Enabled'
    }
    
    if settings.key?(params[:id])
      { value: settings[params[:id]] }.to_json
    else
      status 404
      { error: 'Setting not found' }.to_json
    end
  end

  # 获取所有可用的节点类型
  get '/node-types' do
    content_type :json
    {
      types: ['PROCESS', 'SERVICE', 'GATEWAY', 'EVENT']
    }.to_json
  end

  # 获取特定节点类型的定义
  get '/node-def/:type' do
    type = params[:type]
    content_type :json
    {
      type: type,
      name: "Sample #{type}",
      description: "This is a sample #{type} node",
      inputs: {
        input1: {
          type: 'string',
          description: 'Sample input',
          required: true
        }
      },
      outputs: {
        output1: {
          type: 'string',
          description: 'Sample output'
        }
      }
    }.to_json
  end

  # Get available extensions
  get '/extensions' do
    content_type :json
    # 返回扩展路径数组
    # 这里我们先返回一些示例扩展路径
    [
      'extensions/core/index',
      'extensions/core/nodeTemplates',
      'extensions/core/widgetInputs',
      'extensions/core/uploadAudio'
    ].to_json
  end

  # 保存工作流
  post '/workflow' do
    workflow = JSON.parse(request.body.read)
    # TODO: 实现工作流保存逻辑
    content_type :json
    { status: 'success', id: SecureRandom.uuid }.to_json
  end

  # 加载工作流
  get '/workflow' do
    content_type :json
    recurse = params[:recurse] == 'true'
    full_info = params[:full_info] == 'true'
    
    workflow = M[:sys_files].query(Type: 'workflow', Name: params[:name]).to_a[0]
    return workflow ? workflow['Content'].to_json : {}.to_json
  end

  # 执行工作流
  post '/workflow/:id/execute' do
    id = params[:id]
    # TODO: 实现工作流执行逻辑
    content_type :json
    { status: 'running' }.to_json
  end

  # 获取工作流状态
  get '/workflow/:id/status' do
    id = params[:id]
    # TODO: 实现工作流状态查询逻辑
    content_type :json
    {
      status: 'running',
      progress: 50
    }.to_json
  end

  # Get embeddings list
  get '/embeddings' do
    content_type :json
    # 返回可用的嵌入列表
    ['embedding1.pt', 'embedding2.pt'].to_json
  end

  # Get node definitions
  get '/node_defs' do
    content_type :json
    # 返回节点定义，包括输入和输出规范
    {
      'LoadImage': {
        'name': 'LoadImage',
        'display_name': 'Load Image',
        'category': 'image',
        'description': 'Load an image from disk',
        'input': {
          'required': {
            'image': ['STRING', {
              'default': '',
              'multiline': false,
              'dynamicPrompts': false
            }]
          }
        },
        'output': ['IMAGE'],
        'output_name': ['IMAGE'],
        'output_is_list': [false]
      },
      'SaveImage': {
        'name': 'SaveImage', 
        'display_name': 'Save Image',
        'category': 'image',
        'description': 'Save an image to disk',
        'input': {
          'required': {
            'images': ['IMAGE', {}],
            'filename_prefix': ['STRING', {
              'default': 'ComfyUI',
              'multiline': false
            }]
          }
        },
        'output': [],
        'output_name': [],
        'output_is_list': []
      },
      'IntegerNode': {
        'name': 'IntegerNode',
        'display_name': 'Integer',
        'category': 'number',
        'description': 'Input an integer value',
        'input': {
          'required': {
            'value': ['INT', {
              'default': 0,
              'min': -100,
              'max': 100,
              'step': 1
            }]
          }
        },
        'output': ['INT'],
        'output_name': ['Value'],
        'output_is_list': [false]
      }
    }.to_json
  end

  # Get model folders
  get '/model_folders' do
    content_type :json
    # 返回模型文件夹列表
    ['checkpoints', 'loras', 'embeddings', 'vae'].to_json
  end

  # Get models in a folder
  get '/models/:folder' do
    content_type :json
    folder = params[:folder]
    # 返回指定文件夹中的模型列表
    case folder
    when 'checkpoints'
      ['model1.ckpt', 'model2.ckpt'].to_json
    when 'loras'
      ['lora1.pt', 'lora2.pt'].to_json
    else
      [].to_json
    end
  end

  # Get model metadata
  get '/metadata/:folder/:model' do
    content_type :json
    folder = params[:folder]
    model = params[:model]
    # 返回模型元数据
    {
      'modelName': model,
      'folder': folder,
      'type': 'Stable-Diffusion',
      'size': '7.0GB'
    }.to_json
  end

  # Get queue status and history
  get '/prompt' do
    content_type :json
    {
      prompt_id: nil,
      number: 0,
      node_errors: [],
      exec_info: {
        queue_remaining: 0
      }
    }.to_json
  end

  # Queue a new prompt
  post '/prompt' do
    content_type :json
    data = JSON.parse(request.body.read)
    prompt_id = SecureRandom.uuid
    
    # 处理提示请求
    {
      'prompt_id': prompt_id,
      'number': data['number'] || 0,
      'node_errors': {},
      'status': {
        'exec_info': {
          'queue_remaining': 1
        }
      }
    }.to_json
  end

  # Get system stats
  get '/system_stats' do
    content_type :json
    # 返回系统状态，包括 Python 版本、操作系统和设备信息
    {
      'system': {
        'os': RbConfig::CONFIG['host_os'],
        'python_version': '3.10',
        'version': '1.0.0'
      },
      'devices': {
        'cpu': {
          'name': 'CPU',
          'type': 'cpu',
          'available': true,
          'total_memory': 8589934592,  # 8GB in bytes
          'free_memory': 4294967296    # 4GB in bytes
        }
      }
    }.to_json
  end

  # Get workflow by ID
  get '/workflow/:id' do
    content_type :json
    
    
    workflow = M[:workflows].query(_id: params[:id]).first
    halt 404, { error: 'Workflow not found' }.to_json unless workflow
    
    workflow.to_json
  end

  # Create new workflow
  post '/workflow' do
    content_type :json
    
    
    data = JSON.parse(request.body.read)
    data['created_at'] = Time.now
    data['updated_at'] = Time.now
    
    result = M[:workflows].insert_one(data)
    
    { id: result.inserted_id.to_s }.to_json
  end

  # Update workflow
  put '/workflow/:id' do
    content_type :json
    
    
    data = JSON.parse(request.body.read)
    data['updated_at'] = Time.now
    
    result = M[:workflows].update_one(
      { _id: params[:id] },
      { '$set' => data }
    )
    
    halt 404, { error: 'Workflow not found' }.to_json if result.modified_count.zero?
    
    { success: true }.to_json
  end

  # Delete workflow
  delete '/workflow/:id' do
    content_type :json
    
    
    result = M[:workflows].delete_one(_id: params[:id])
    
    halt 404, { error: 'Workflow not found' }.to_json if result.deleted_count.zero?
    
    { success: true }.to_json
  end

  # Execute workflow
  post '/workflow/:id/execute' do
    content_type :json
    
    
    workflow = M[:workflows].query(_id: params[:id]).first
    halt 404, { error: 'Workflow not found' }.to_json unless workflow
    
    # Create execution record
    execution = {
      workflow_id: params[:id],
      status: 'pending',
      created_at: Time.now,
      updated_at: Time.now
    }
    
    result = M[:executions].insert_one(execution)
    
    # Send execution request via WebSocket
    settings.sockets.each do |ws|
      ws.send({
        type: 'execute',
        data: {
          execution_id: result.inserted_id.to_s,
          workflow: workflow
        }
      }.to_json)
    end
    
    { execution_id: result.inserted_id.to_s }.to_json
  end

  # Get execution status
  get '/execution/:id' do
    content_type :json
    
    
    execution = M[:executions].query(_id: params[:id]).first
    halt 404, { error: 'Execution not found' }.to_json unless execution
    
    execution.to_json
  end

  # Get workflow execution history
  get '/workflow/:id/executions' do
    content_type :json
    
    
    executions = M[:executions]
      .find(workflow_id: params[:id])
      .sort(created_at: -1)
      .limit(10)
      .to_a
      
    executions.to_json
  end

  # Export workflow
  get '/workflow/:id/export' do
    content_type :json
    
    
    workflow = M[:workflows].query(_id: params[:id]).first
    halt 404, { error: 'Workflow not found' }.to_json unless workflow
    
    # Remove internal fields
    workflow.delete('_id')
    workflow.delete('created_at')
    workflow.delete('updated_at')
    
    workflow.to_json
  end

  # Import workflow
  post '/workflow/import' do
    content_type :json
    
    
    data = JSON.parse(request.body.read)
    data['created_at'] = Time.now
    data['updated_at'] = Time.now
    
    result = M[:workflows].insert_one(data)
    
    { id: result.inserted_id.to_s }.to_json
  end

  # Get workflow metadata
  get '/workflow/:id/metadata' do
    content_type :json
    
    
    workflow = M[:workflows].query(_id: params[:id]).first
    halt 404, { error: 'Workflow not found' }.to_json unless workflow
    
    {
      id: workflow['_id'].to_s,
      name: workflow['name'],
      description: workflow['description'],
      created_at: workflow['created_at'],
      updated_at: workflow['updated_at'],
      node_count: workflow['nodes']&.length || 0,
      edge_count: workflow['edges']&.length || 0
    }.to_json
  end

  # Clone workflow
  post '/workflow/:id/clone' do
    content_type :json

    workflow = M[:workflows].query(_id: params[:id]).first
    halt 404, { error: 'Workflow not found' }.to_json unless workflow
    
    # Remove ID and update timestamps
    workflow.delete('_id')
    workflow['name'] = "#{workflow['name']} (Copy)"
    workflow['created_at'] = Time.now
    workflow['updated_at'] = Time.now
    
    result = M[:workflows].insert_one(workflow)
    
    { id: result.inserted_id.to_s }.to_json
  end
end
