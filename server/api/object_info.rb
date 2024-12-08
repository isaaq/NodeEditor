# frozen_string_literal: true

require 'json'
require 'find'
require 'mongo'

# 处理 /api/object_info 端点
class TaheController < ApiController

  # 获取所有节点信息
  get '/object_info' do
    content_type :json
    
    # 获取节点定义从 MongoDB
    nodes = M[:nodes].query.to_a

    # 转换为预期格式
    result = {}
    nodes.each do |node|
      result[node['name']] = {
        'name' => node['name'],
        'display_name' => node['display_name'] || node['name'],
        'description' => node['description'],
        'category' => node['category'],
        'input' => {
          'required' => node['input_required'] || {},
          'optional' => node['input_optional'] || {}
        },
        'output' => node['output'] || [],
        'output_name' => node['output_name'] || [],
        'output_is_list' => node['output_is_list'] || []
      }
    end
result
    # 如果没有找到节点定义在数据库中，返回一些默认节点定义
    if result.empty?
      result = {
        'LoadImage' => {
          'input' => {
            'required' => {
              'image' => {
                'type' => 'STRING',
                'filetypes' => ['png', 'jpg', 'jpeg']
              }
            }
          },
          'output' => ['IMAGE'],
          'output_is_list' => [false],
          'output_name' => ['IMAGE'],
          'name' => 'LoadImage',
          'display_name' => 'Load Image',
          'description' => 'Load an image from disk',
          'category' => 'image'
        },
        'SaveImage' => {
          'input' => {
            'required' => {
              'images' => {
                'type' => 'IMAGE'
              },
              'filename_prefix' => {
                'type' => 'STRING'
              }
            },
            'optional' => {
              'compress' => {
                'type' => 'INT',
                'default' => 8,
                'min' => 0,
                'max' => 9
              }
            }
          },
          'output' => ['STRING'],
          'output_is_list' => [false],
          'output_name' => ['filename'],
          'name' => 'SaveImage',
          'display_name' => 'Save Image',
          'description' => 'Save an image to disk',
          'category' => 'image'
        },
        'CLIPTextEncode' => {
          'input' => {
            'required' => {
              'text' => { 'type' => 'STRING' },
              'clip' => { 'type' => 'CLIP' }
            }
          },
          'output' => ['CONDITIONING'],
          'output_is_list' => [false],
          'output_name' => ['CONDITIONING'],
          'name' => 'CLIPTextEncode',
          'display_name' => 'CLIP Text Encode',
          'description' => 'Encode text into CLIP embeddings',
          'category' => 'conditioning'
        }
      }

      # 存储默认节点定义在 MongoDB
      result.each do |name, node_def|
        M[:nodes].add(node_def.merge('name' => name))
      end
    end

    result.to_json
  end

  # 获取特定节点信息
  get '/object_info/:node_class' do |node_class|
    content_type :json
    nodes = {
      'LoadImage' => {
        'input' => {
          'required' => {
            'image' => {
              'type': 'STRING',
              'filetypes': ['png', 'jpg', 'jpeg']
            }
          }
        },
        'output' => ['IMAGE'],
        'output_is_list' => [false],
        'output_name' => ['IMAGE'],
        'name' => 'LoadImage',
        'display_name' => 'Load Image',
        'description' => 'Load an image from disk',
        'category' => 'image'
      },
      'SaveImage' => {
        'input' => {
          'required' => {
            'images' => {
              'type': 'IMAGE'
            },
            'filename_prefix' => {
              'type': 'STRING'
            }
          },
          'optional' => {
            'compress' => {
              'type': 'INT',
              'default': 8,
              'min': 0,
              'max': 9
            }
          }
        },
        'output' => ['STRING'],
        'output_is_list' => [false],
        'output_name' => ['filename'],
        'name' => 'SaveImage',
        'display_name' => 'Save Image',
        'description' => 'Save an image to disk',
        'category' => 'image'
      }
    }
    
    if nodes.key?(node_class)
      { node_class => nodes[node_class] }.to_json
    else
      status 404
      { error: "Node class '#{node_class}' not found" }.to_json
    end
  end

  # 获取工作流历史
  get '/history' do
    content_type :json
    
    workflows = M[:workflows].query.sort(created_at: -1).limit(10).to_a
    workflows.map do |w|
      {
        'id' => w['_id'].to_s,
        'name' => w['name'],
        'created_at' => w['created_at'],
        'updated_at' => w['updated_at']
      }
    end.to_json
  end

  # 获取系统信息
  get '/system_stats' do
    content_type :json
    
    {
      'system' => {
        'os' => RUBY_PLATFORM,
        'ruby_version' => RUBY_VERSION,
        'memory_usage' => `ps -o rss= -p #{Process.pid}`.to_i / 1024, # MB
        'cpu_usage' => `ps -o %cpu= -p #{Process.pid}`.to_f
      },
      'database' => {
        'workflows_count' => M[:workflows].count_documents({}),
        'nodes_count' => M[:nodes].count_documents({})
      }
    }.to_json
  end

  # 获取书签设置 V1
  get '/settings/Comfy.NodeLibrary.Bookmarks' do
    content_type :json
    {
      "bookmarks": []
    }.to_json
  end

  # 保存书签设置 V1
  post '/settings/Comfy.NodeLibrary.Bookmarks' do
    content_type :json
    request_payload = JSON.parse(request.body.read)
    # 在实际应用中，你需要将书签保存到数据库或文件中
    {
      "success": true,
      "message": "Bookmarks saved successfully"
    }.to_json
  end

  # 获取书签设置 V2
  get '/settings/Comfy.NodeLibrary.Bookmarks.V2' do
    content_type :json
    []
  end

  # 保存书签设置 V2
  post '/settings/Comfy.NodeLibrary.Bookmarks.V2' do
    content_type :json
    request_payload = JSON.parse(request.body.read)
    # 在实际应用中，你需要将书签保存到数据库或文件中
    {
      "success": true,
      "message": "Bookmarks V2 saved successfully"
    }.to_json
  end

  # 获取书签自定义设置
  get '/settings/Comfy.NodeLibrary.BookmarksCustomization' do
    content_type :json
    {}
  end

  # 保存书签自定义设置
  post '/settings/Comfy.NodeLibrary.BookmarksCustomization' do
    content_type :json
    request_payload = JSON.parse(request.body.read)
    # 在实际应用中，你需要将设置保存到数据库或文件中
    {
      "success": true,
      "message": "Bookmarks customization saved successfully"
    }.to_json
  end

  # 获取用户数据文件列表
  get '/userdata' do
    content_type :json
    dir = params['dir']
    recurse = params['recurse'] == 'true'
    split = params['split'] == 'true'
    full_info = params['full_info'] == 'true'

    # 工作流目录的绝对路径
    workflows_dir = File.join(File.dirname(__FILE__), '..', 'workflows')
    
    if dir == 'workflows'
      files = []
      client = Mongo::Client.new('mongodb://localhost:27017')
      db = client['mydatabase']
      workflows = db['workflows'].find
      workflows.each do |wf|
        files << {
          "name": wf['Name'],
          "path": "workflows/#{wf['Name']}",
          "type": "file",
          "size": wf['Content'].to_s.size,
          "modified": wf['UpdateTime'] || (Time.now.to_i * 1000)
        }
      end
      client.close
      files.to_json
    else
      [].to_json
    end
  end
end
