class DatabaseTransform::Schema
  extend DatabaseTransform::SchemaModelStore
  extend DatabaseTransform::SchemaTables

  # Transforms a table from the source database to the new database.
  #
  # Specify the source table to get entries from; a proc with the transform steps can be specified.
  #
  # @option args [String, Symbol, Class] to The name of the destination table; if this is not specified, no tables are
  #    copied. This can be a class, or a symbol which will be constantised; each column mapping proc will have access to
  #    one instance of this table when performing a transformation.
  # @option args [Array<String, Symbol>] depends An array of symbols (source tables) which must be transformed before
  #    the specified source table can be transformed.
  # @option args [Proc] default_scope The default scope of the old table to use when transforming.
  def self.transform_table(source_table, args = {}, &proc)
    raise ArgumentError.new if source_table.nil?
    raise DatabaseTransform::DuplicateError.new(source_table) if tables.has_key?(source_table)

    source_table, args[:to] = prepare_models(source_table, args[:to])

    transform = DatabaseTransform::SchemaTable.new(source_table, args[:to], args.slice(:default_scope, :batch_size))
    tables[source_table] = { depends: args[:depends] || [], transform: transform }
    transform.instance_eval(&proc) if proc
  end

  class << self
    private

    def prepare_models(source_table, destination_table)
      source_table = generate_model(const_get(:Source), source_table) unless source_table.is_a?(Class)
      set_connection_for_model(source_table, deduce_connection_name)

      if !destination_table.nil? && !destination_table.is_a?(Class)
        destination_table = generate_model(const_get(:Destination), destination_table)
      end

      [source_table, destination_table]
    end

    def generate_model(within, table_name)
      class_name = ActiveSupport::Inflector.camelize(ActiveSupport::Inflector.singularize(table_name.to_s))
      within.module_eval <<-EndCode, __FILE__, __LINE__ + 1
        class #{class_name} < ActiveRecord::Base
          self.table_name = '#{table_name.to_s}'
        end
        #{class_name.to_s.singularize.camelize}
      EndCode
    end

    # Deduces the connection name from the name of the schema class.
    #
    # @return [String] The name of the connection to use.
    def deduce_connection_name
      deduced_connection_name = ActiveSupport::Inflector.underscore(name)
      return deduced_connection_name if connection_name_exists?(deduced_connection_name)

      deduced_connection_name << '_production'
    end

    # Checks if the given connection name exists
    #
    # @param [String] name The name of the connection to check.
    # @return [Boolean] True if the connection exists.
    def connection_name_exists?(name)
      ActiveRecord::Base.configurations.has_key?(name)
    end

    # Sets the connection for the given model, using the given connection name.
    #
    # @param [Class] model The model to set the connection on.
    # @param [String] connection_name The name of the connection to set.
    # @return [Void]
    def set_connection_for_model(model, connection_name)
      model.establish_connection(connection_name.to_sym)
    end
  end

  # Runs the transform.
  #
  # @raise [DatabaseTransform::UnsatisfiedDependencyError] When the dependencies for a table cannot be satisfied, and no
  #   progress can be made.
  # @return [Void]
  def transform!
    # The tables have dependencies; we must run them in order.
    transformed = Set.new
    queue = Set.new(tables.keys)

    # We try to run all the transforms we can until no more can be run.
    # If no more can run and the input queue is empty, we are done.
    # If no more can run and the input queue is not empty, we have a dependency cycle.
    begin
      transformed_this_pass = transform_pass(transformed, queue)
      fail DatabaseTransform::UnsatisfiedDependencyError.new(queue.to_a) if transformed_this_pass.empty? && !queue.empty?

      queue -= transformed_this_pass
      transformed += transformed_this_pass
    end until queue.empty?
  end

  private

  # Performs a transform over all elements of the queue who has its dependencies satisfied.
  #
  # @param [Array<Symbol>] transformed The models which have been transformed.
  # @param [Array<Symbol>] queue The models which need to be transformed.
  # @return [Set<Symbol>] The set of models which were transformed this pass.
  def transform_pass(transformed, queue)
    transformed_this_pass = Set.new
    queue.each do |table|
      # Check that all dependencies are satisfied
      table_config = tables[table]
      unmet_dependencies = table_config[:depends].select do |s|
        !transformed.include?(s) && !transformed_this_pass.include?(s)
      end
      next unless unmet_dependencies.empty?

      table_config[:transform].run_transform(self)
      transformed_this_pass << table
    end

    transformed_this_pass
  end
end
