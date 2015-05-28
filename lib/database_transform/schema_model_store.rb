# Implements a model namespace for database tables without an explicit model.
module DatabaseTransform::SchemaModelStore
  def inherited(class_)
    class_.const_set(:Source, Module.new)
    class_.const_set(:Destination, Module.new)
  end
end
