class DatabaseTransform::Schema
  extend DatabaseTransform::ModelStore

  class_attribute :tables
  self.tables = {}

  # Migrates a table from the source database to the new database.
  #
  # Specify the source table to get entries from; a proc with the migration steps can be specified.
  #
  # @option args [String, Symbol, Class] to The name of the destination table; if this is not specified, no tables are
  #    copied. This can be a class, or a symbol which will be constantised; each column mapping proc will have access to
  #    one instance of this table when performing a migration.
  # @option args [Array<String, Symbol>] depends An array of symbols (source tables) which must be migrated before the
  #    specified source table can be migrated.
  # @option args [Proc] default_scope The default scope of the old table to use when migrating.
  def self.migrate_table(source_table, args = {}, &proc)
    raise DatabaseTransform::DuplicateError if tables.has_key?(source_table)

    tables[source_table] = {}
  end

  # Runs the transform.
  def transform!
  end
end
