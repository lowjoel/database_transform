require 'database_transform/version'

module DatabaseTransform
  extend ActiveSupport::Autoload

  autoload :DuplicateError
  autoload :UnsatisfiedDependencyError

  autoload :SchemaTables
  autoload :SchemaModelStore
  autoload :Schema

  autoload :SchemaTableRecordMapping
  autoload :SchemaTable

  autoload :ThreadPool

  require 'database_transform/railtie' if defined?(Rails)
end
