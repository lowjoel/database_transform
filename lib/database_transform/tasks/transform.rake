# This class just loads the file containing the schema definition and hands off control to the schema.
class DatabaseTransform::Transform
  def initialize(args)
    @schema = args.schema_name
    @argv = args.extras
  end

  def run
    require_schema
    schema = @schema.camelize.constantize.new(*@argv)

    ActiveRecord::Base.logger = Logger.new('log/import.log')
    schema.transform!
  end

  private

  def require_schema
    schema_name = @schema.underscore
    schema_files = [
        File.join(Rails.root, 'db', 'transforms', schema_name),
        File.join(Rails.root, 'db', 'transforms', schema_name, schema_name)
    ]

    schema_file = schema_files.find { |f| File.exist?(f) } || schema_files.first
    require schema_file
  end
end

namespace :db do
  desc 'Transform old database schemas'
  task :transform, [:schema_name] => :environment do |_, args|
    DatabaseTransform::Transform.new(args).run
  end
end
