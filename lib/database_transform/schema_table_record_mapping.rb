module DatabaseTransform::SchemaTableRecordMapping
  # Obtains the result of transforming the record with the given primary key.
  #
  # @param old_primary_key The primary key of the record to obtain the result for.
  # @raise [ActiveRecord::RecordNotFound] When the primary has not been transformed, or the primary key does not exist.
  # @return The new record after transformation.
  def transform(old_primary_key)
    @transformed ||= {}
    unless @transformed.has_key?(old_primary_key)
      raise ActiveRecord::RecordNotFound.new("Key #{old_primary_key} in #{table_name}")
    end

    @transformed[old_primary_key]
  end

  # Checks if the given primary key has been transformed.
  #
  # @param old_primary_key The primary key of the record to obtain the result for.
  # @return [Boolean] True if the record has been transformed.
  def transformed?(old_primary_key)
    @transformed ||= {}
    @transformed.has_key?(old_primary_key)
  end

  # @api private
  #   Called by TableTransform#run_transform
  def memoize_transform(old_primary_key, result)
    @transformed ||= {}
    @transformed[old_primary_key] = result
  end
end
