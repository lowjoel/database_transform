class DatabaseTransform::DuplicateError < StandardError
  def initialize(column)
    super
    @column = column
  end

  def to_s
    "The column #{@column} had multiple transforms."
  end
end
