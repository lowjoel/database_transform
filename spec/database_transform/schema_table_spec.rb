require 'spec_helper'

RSpec.describe DatabaseTransform::SchemaTable do
  class DummyTableSchema < DatabaseTransform::Schema; end
  subject { DatabaseTransform::SchemaTable.new(DummyTableSchema, source_table, default_scope) }
  let(:source_table) { nil }
  let(:default_scope) { nil }
end
