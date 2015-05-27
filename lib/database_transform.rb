require 'database_transform/version'

module DatabaseTransform
  extend ActiveSupport::Autoload

  autoload :DuplicateError

  autoload :Schema
  autoload :ModelStore
  autoload :SchemaTable
end
