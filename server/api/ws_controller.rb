# frozen_string_literal: true

require 'mongo'
require 'json'
require 'securerandom'

# WebSocket controller - handles real-time communication
class WSController < ApiController
  configure do
    set :server, 'thin'
    set :sockets, []
    set :prompt_id, nil
    set :client_id, nil
  end
  
  def initialize
    super
    @execution_queue = []
    @current_execution = nil
    @outputs = {}
  end

  def load_workflow_from_mongo(workflow_id = nil)
    collection = M[:workflows]
    if workflow_id
      collection.query(_id: workflow_id).first
    else
      collection.query.first # Load default workflow if no ID specified
    end
  end

  def handle_client_message(ws, msg)
    data = JSON.parse(msg)
    case data['type']
    when 'execute'
      handle_execute(ws, data)
    when 'interrupt'
      handle_interrupt
    when 'load_workflow'
      handle_load_workflow(ws, data)
    when 'save_workflow' 
      handle_save_workflow(data)
    when 'get_status'
      send_status(ws)
    end
  end

  def handle_execute(ws, data)
    prompt = data['prompt']
    client_id = data['client_id']
    prompt_id = SecureRandom.uuid

    # Store execution details
    @current_execution = {
      prompt: prompt,
      client_id: client_id,
      prompt_id: prompt_id,
      status: 'running',
      outputs: {}
    }

    # Add to queue
    @execution_queue << @current_execution

    # Send status update
    send_status(ws)

    # Process queue if not already processing
    process_queue unless @execution_queue.empty?
  end

  def handle_interrupt
    # Stop current execution
    @current_execution = nil
    @execution_queue.clear
    
    broadcast_to_clients({
      type: 'execution_interrupted',
      data: { status: 'interrupted' }
    })
  end

  def handle_load_workflow(ws, data)
    workflow = load_workflow_from_mongo(data['workflow_id'])
    if workflow
      ws.send({
        type: 'workflow',
        data: workflow
      }.to_json)
    end
  end

  def handle_save_workflow(data)
    workflow = data['workflow']
    workflow_id = data['workflow_id']
    
    collection = M[:workflows]
    if workflow_id
      collection.update_one(
        { _id: workflow_id },
        { '$set' => workflow },
        upsert: true
      )
    else
      collection.insert_one(workflow)
    end
  end

  def send_status(ws)
    status = {
      prompt_id: @current_execution&.[](:prompt_id),
      number: @execution_queue.size,
      node_errors: [],
      exec_info: {
        queue_remaining: @execution_queue.size
      }
    }

    ws.send({
      type: 'status',
      data: status
    }.to_json)
  end

  def broadcast_to_clients(msg)
    settings.sockets.each do |ws|
      ws.send(msg.to_json)
    end
  end

  def process_queue
    return if @execution_queue.empty? || @current_execution

    @current_execution = @execution_queue.shift
    
    # Execute the workflow
    begin
      execute_workflow(@current_execution[:prompt])
    rescue => e
      broadcast_to_clients({
        type: 'execution_error',
        data: {
          error: e.message,
          details: e.backtrace.join("\n")
        }
      })
    ensure
      @current_execution = nil
      process_queue
    end
  end

  def execute_workflow(prompt)
    # Send execution start event
    broadcast_to_clients({
      type: 'execution_start',
      data: { timestamp: Time.now.to_i }
    })

    # TODO: Implement actual workflow execution logic
    # This is where you would process the nodes and their connections
    
    # For now just simulate some progress
    10.times do |i|
      sleep 0.5 # Simulate work
      broadcast_to_clients({
        type: 'progress',
        data: { value: i + 1, max: 10 }
      })
    end

    # Send execution complete
    broadcast_to_clients({
      type: 'execution_complete',
      data: { 
        timestamp: Time.now.to_i,
        outputs: @current_execution[:outputs]
      }
    })
  end
  
  get '/' do
    if !request.websocket?
      halt 400, 'WebSocket connection required'
    end
    
    request.websocket do |ws|
      ws.onopen do
        settings.sockets << ws
        
        # Generate unique client ID
        settings.client_id = SecureRandom.uuid
        
        # Send initial status
        send_status(ws)
        
        # Load and send workflow data
        workflow = load_workflow_from_mongo
        if workflow
          ws.send({
            type: 'workflow',
            data: workflow
          }.to_json)
        end
      end
      
      ws.onmessage do |msg|
        begin
          handle_client_message(ws, msg)
        rescue JSON::ParserError => e
          puts "Error parsing message: #{e}"
        rescue => e
          puts "Error handling message: #{e}"
          puts e.backtrace
        end
      end
      
      ws.onclose do
        settings.sockets.delete(ws)
      end
    end
  end
end
