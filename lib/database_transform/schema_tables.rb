module DatabaseTransform::SchemaTables
  def self.extended(class_)
    class_.class_attribute :tables
    class_.tables = {}.freeze
  end

  def inherited(class_)
    def class_.tables
      @tables ||= ancestors[1].tables.dup
    end
    super
  end
end
