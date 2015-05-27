# Represents a transformation from a source table to a destination table.
class DatabaseTransform::SchemaTable
  # Initialises the table definition for a particular schema
  #
  # @param [Class] source The model class to map source records from
  # @param [Class] destination The model class to map destination records to
  # @param [nil, Proc] default_scope The default scope for querying the source table.
  def initialize(source, destination, default_scope)
    @source = source
    @destination = destination
    @default_scope = default_scope
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

    # Get the source columns
    if args[args.length - 1].is_a?(Hash)
      source_columns = args.take(args.length - 1)
      args = args.extract_options!
    else
      source_columns = args
      args = {}
    end

    raise ArgumentError.new unless args[:to].nil? || args[:to].is_a?(Symbol)

    # Store the mapping
    @columns << {
        from: source_columns,
        to: args[:to],
        null: args[:null].nil? ? true : args[:null],
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
end
