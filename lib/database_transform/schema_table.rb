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
    @columns = {}
  end
end
