def dev
  true
end

def libfolder
  '/Users/isaac/codes/tahe/tahe_new_gen'
end

def load_all_files(path)
  # dev = false
  Dir["#{path}/**/*.rb"].sort.each do |f|
    unless f.include?('_config.rb')
      (p "装载文件#{f}" if dev
       require(f))
    end
  end
end

def load_files(path)
  # dev = false
  Dir["#{path}/*.rb"].each do |f|
    next if f.include?('_config.rb')

    (p "装载文件#{f}" if dev
     require(f)
     yield(f) if block_given?)
  end
end
require 'singleton'
class Global
  include Singleton
  # class << Global
  attr_accessor :_record_inherited_flag, :_sys_models, :_user_models
  # end
end

class Object
  def self.inherited(subclass)
    return unless Global.instance._record_inherited_flag

    (@classes ||= []) << subclass
  end

  def self.fetch_loaded_classes
    out = @classes.dup
    @classes = []
    out
  end
end
