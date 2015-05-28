class DatabaseTransform::Schema
  extend DatabaseTransform::ModelStore
  extend DatabaseTransform::SchemaTables

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

    source_table = generate_model(Source, source_table) unless source_table.is_a?(Class)
    args[:to] = generate_model(Destination, args[:to]) unless args[:to].is_a?(Class)

    migration = DatabaseTransform::SchemaTable.new(source_table, args[:to], args[:default_scope])
    tables[source_table] = { depends: args[:depends] || [], migration: migration }
    migration.instance_eval(&proc) if proc
  end

  class << self
    def generate_model(within, table_name)
      class_name = ActiveSupport::Inflector.camelize(ActiveSupport::Inflector.singularize(table_name.to_s))
      within.module_eval <<-EndCode, __FILE__, __LINE__ + 1
        class #{class_name} < ActiveRecord::Base
          def self.map(old_primary_key)
            @map ||= {}
            unless @map.has_key?(old_primary_key)
              raise ActiveRecord::RecordNotFound.new("Key \#{old_primary_key} in #{table_name}")
            end

            @map[old_primary_key]
          end

          private

          # Called by TableMigration#run_migration
          def self.assign_result(old_primary_key, result)
            @map ||= {}
            @map[old_primary_key] = result
          end
        end
        #{class_name.to_s.singularize.camelize}
      EndCode
    end
    private :generate_model
  end

  # Runs the transform.
  def transform!
  end
end
