require 'spec_helper'

RSpec.describe DatabaseTransform::Schema do
  class DummySchema < DatabaseTransform::Schema
    migrate_table :source, to: :destination do
    end
  end

  subject { DummySchema.new }

  context 'when inheriting from DatabaseTransform::Schema' do
    it 'has a tables class method' do
      expect(DummySchema).to respond_to(:tables)
    end

    context 'when inheriting from a subclass of DatabaseTransform::Schema' do
      class DummySchema2 < DummySchema
      end

      it "contains the parent class's tables" do
        expect(DummySchema2.tables).to include(DummySchema.tables)
      end
    end
  end
end
