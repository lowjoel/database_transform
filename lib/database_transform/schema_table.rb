# Represents a transformation from a source table to a destination table.
class DatabaseTransform::SchemaTable
  # Initialises the table definition for a particular schema
  #
  # @param [Class] source The model class to map source records from
  # @param [Class] destination The model class to map destination records to
  # @param [nil, Proc] default_scope The default scope for querying the source table.
  def initialize(source, destination, default_scope)
    @source = source
    @source.extend(DatabaseTransform::SchemaTableRecordMapping)
    @destination = destination
    @destination.extend(DatabaseTransform::SchemaTableRecordMapping) if @destination
    @default_scope = default_scope

    @primary_key = nil
    @save = nil
    @columns = []
  end

  # Declare the primary key of the source table.
  #
  # @param [Symbol] id The name of the column in the source table which is the primary key.
  def primary_key(id)
    raise DatabaseTransform::DuplicateError.new(id) if @primary_key
    @primary_key = id
    @source.primary_key = id
  end

  # Declare the mapping for the source table to the new table.
  #
  # This function takes source columns to provide to the mapping proc as arguments.
  #
  # The destination column is specified as the to hash parameter.
  # If no mapping block is specified, the source column is copied to the destination column without modification. This
  # is not possible if more than one source column is specified.
  # If the mapping block is specified, if the destination column is specified, the result of the block is used as the
  # destination column's value.
  # Otherwise, the result is unused. This can be used to execute the block purely for side-effects
  #
  # @option options [Symbol] to The column to map to.
  # @option options [Boolean] null If to is specified, this can be false which enforces that nil is never added to the
  #   database.
  def column(*args, &block)
    raise ArgumentError if args.length < 1

    # Get the columns
    options = args.extract_options!
    source_columns = args
    to_column = options.delete(:to)
    to_column ||= source_columns.first unless block

    validate_column_options!(source_columns, to_column, options, block)

    # Store the mapping
    @columns << {
        from: source_columns,
        to: to_column,
        null: options[:null].nil? ? true : options[:null],
        block: block
    }
  end

  # Specifies a save clause.
  #
  # @option options [Proc] unless The record will be saved if the proc returns a false value. This cannot be used
  #   together with if.
  # @option options [Proc] if A proc to call. The record will be saved if the proc returns a true value. This cannot be
  #   used together with unless.
  def save(options = {})
    raise ArgumentError.new('unless and if cannot be both specified') if options[:unless] && options[:if]
    raise ArgumentError.new('Cannot specify a save clause twice for the same table') if @save

    if options[:unless]
      clause = options.delete(:unless)
      options[:if] = ->(*callback_args) { !self.instance_exec(*callback_args, &clause) }
    end

    @save = options
  end

  # @api private
  #   To be called only by Schema#run_transform
  def run_transform(schema = nil)
    before_message =
      if @destination
        format("-- transforming '%s' to '%s'\n", @source.table_name, @destination.table_name)
      else
        format("-- transforming '%s'\n", @source.table_name)
      end

    time_block(before_message, "   -> %fs\n") do
      transform!(schema)
    end
  end

  private

  # Validates the options given to the #column method.
  def validate_column_options!(source_columns, to_column, options, block)
    raise ArgumentError.new unless to_column.nil? || to_column.is_a?(Symbol)
    raise ArgumentError.new if !block && source_columns.length > 1
    raise ArgumentError.new if options[:null] == false && !to_column
  end

  # Performs the given operation, timing it and printing before and after messages for executing the block.
  #
  # @param [String] before The message to print before the operation.
  # @param [String] after The message to print after the operation. One floating point format argument is available,
  #   which is the time taken for the operation.
  # @return The result of executing the block.
  # @yield The block to time.
  def time_block(before, after, &proc)
    start = Time.now
    $stderr.puts(before)

    result = proc.call

    complete = Time.now - start
    $stderr.printf(after, complete)

    result
  end

  # Performs the transform with the given parameters.
  #
  # @param [DatabaseTransform::Schema] schema The schema being transformed.
  # @return [Void]
  def transform!(schema)
    # For each item in the old model
    default_scope = @default_scope || @source.method(:all)
    @source.instance_exec(&default_scope).each do |record|
      transform_record!(schema, record)
    end
  end

  # Transforms one record from the source model to the destination.
  #
  # @param [DatabaseTransform::Schema] schema The schema being transformed.
  # @param [ActiveRecord::Base] old The record to map.
  # @return [Void]
  def transform_record!(schema, old)
    # Instantiate a new model record
    new = @destination.new if @destination

    # Map the columns over
    transform_record_columns!(schema, old, new)
    return if new.nil? || new.frozen?

    save_transformed_record(old, new)
  end

  # Applies the column transforms over the old record to the new record.
  #
  # @param [DatabaseTransform::Schema] schema The schema being transformed.
  # @param [ActiveRecord::Base] old The record to map.
  # @param [ActiveRecord::Base] new The record to map to.
  # @return [Void]
  def transform_record_columns!(schema, old, new)
    @columns.each do |column|
      fail ArgumentError.new unless column.is_a?(Hash)

      new_value = transform_record_field!(schema, old, new, column[:from], column[:block])

      unless new.nil?
        break if new.frozen?
        next if column[:to].nil?

        assign_record_field!(old, new, column, new_value)
      end
    end
  end

  # Transforms one record's field.
  #
  # @param [DatabaseTransform::Schema] schema The schema being transformed.
  # @param [ActiveRecord::Base] source The source row to map the values for.
  # @param [ActiveRecord::Base] destination The destination row to map the values to.
  # @param [Array<Symbol>] from The source columns to be used to map to the destination column.
  # @param [Proc, nil] block The block to transform the source values to the destination value.
  # @return The result of applying the transform over the input values.
  def transform_record_field!(schema, source, destination, from = nil, block = nil)
    # Get the old record column values (can be a block taking multiple arguments)
    new_values = from.map { |k| source.send(k) }

    if block.nil?
      # We have to ensure the value is a scalar
      new_values.first
    elsif destination
      # Map the value if necessary.
      execute_transform_block!(schema, source, destination, block, new_values)
    else
      # Call the proc
      execute_transform_block!(schema, source, Object.new, block, new_values)
    end
  end

  # Executes the given transform block.
  #
  # This allows the transform to be given an appropriate value of self such that it can access the old record and the schema being used.
  #
  # @param [DatabaseTransform::Schema] schema The schema being transformed.
  # @param [ActiveRecord::Base] source_record The old record being transformed.
  # @param self_ The object to use as self in the context of the block.
  # @param [Proc] block The block to execute.
  # @param [Array] args The arguments to give to the block.
  # @return The result of applying the block.
  def execute_transform_block!(schema, source_record, self_, block, args)
    self_.define_singleton_method(:source_record) { source_record }
    self_.define_singleton_method(:schema) { schema }
    self_.instance_exec(*args, &block)
  end

  # Assigns the transformed value to the new record, raising an argument error if the field was declared to not be
  # nullable and the value is null.
  #
  # @param [ActiveRecord::Base] old The source row to map the values for.
  # @param [ActiveRecord::Base] new The destination row to map the values to.
  # @param [Hash] column The column mapping definition being used.
  # @param new_value The new value to assign to the field.
  # @return [Void]
  def assign_record_field!(old, new, column, new_value)
    if new_value.nil? && column[:null] == false
      old_value = @primary_key ? old.send(@primary_key) : old.inspect
      raise ArgumentError.new("Key #{column[:from]} for row #{old_value} in #{@source.table_name} maps to null for "\
            'non-nullable column')
    end

    new.send("#{column[:to]}=", new_value)
  end

  # Saves the newly transformed record, and then memoizes the transformed value.
  #
  # @param [ActiveRecord::Base] old The source row to map the values for.
  # @param [ActiveRecord::Base] new The destination row to map the values to.
  # @return [Void]
  def save_transformed_record(old, new)
    # Save. Skip if the conditional callback is given
    return if @save && @save[:if] && !new.instance_exec(&@save[:if])

    # TODO: Make validation optional using the save clause.
    new.save!(validate: false) unless new.destroyed?
    @source.memoize_transform(old.send(@primary_key), new) if @primary_key
  end
end
