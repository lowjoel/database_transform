# This class just loads the file containing the schema definition and hands off control to the schema.
class DatabaseTransform::Transform
  def initialize(args)
    @schema = args.schema_name
    @extra_args = args.extras
    run
  end

  def run
    import_schema
    schema = @schema.constantize.new

    ActiveRecord::Base.logger = Logger.new('log/import.log')
    schema.transform!
  end

  private

  def import_schema
    schema_file = @schema.underscore
    begin
      return require(File.join(Rails.root, 'db', 'transforms', schema_file))
    rescue LoadError
    end

    require (File.join(Rails.root, 'db', 'transforms', schema_file, schema_file))
  end
end

namespace :db do
  desc 'Transform old database schemas'
  task :transform, [:schema_name] => :environment do |_, args|
    DatabaseTransform::Transform.new(args)
  end
end
