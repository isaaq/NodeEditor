require 'sinatra'
require 'sinatra/base'
require 'sinatra/content_for'
require 'sinatra/cookies'
require 'sinatra/flash'
require 'sinatra/reloader' if development?
require 'sinatra/namespace'
require 'sinatra-websocket'
require 'sinatra/cross_origin'
require 'redis'

require 'opal'
require 'opal-jquery'
require 'opal-sprockets'
require 'faraday'

require 'jwt'
require 'thin'

require_relative './_system'
require_relative "#{libfolder}/lib/util/common"
require_relative "#{libfolder}/lib/model/_config"
require_relative "#{libfolder}/lib/biz/_config"

Dir.glob(["#{libfolder}/api/_config.rb"]).each do |file|
  p "装载配置#{file}" if dev
  require_relative file
end

Dir.glob(['./api/_config.rb']).each do |file|
  p "装载配置2#{file}" if dev
  require_relative file
end

# 添加 WebSocket 支持

map('/api') { run TaheController }
map('/ws') { run WSController }