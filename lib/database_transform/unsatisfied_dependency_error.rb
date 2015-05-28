class DatabaseTransform::UnsatisfiedDependencyError < StandardError
  def initialize(tables)
    @tables = tables
    super(tables.join(', '))
  end
end
