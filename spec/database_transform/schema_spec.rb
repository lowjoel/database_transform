require 'spec_helper'

RSpec.describe DatabaseTransform::Schema do
  class DummySchema < DatabaseTransform::Schema
    migrate_table :source, to: 'destination' do
    end
  end

  subject { DummySchema.new }

  context 'when inheriting from DatabaseTransform::Schema' do
    it 'has a tables class method' do
      expect(DummySchema).to respond_to(:tables)
    end

    it 'has a Source module' do
      expect(DummySchema.const_defined?(:Source)).to be_truthy
    end

    it 'has a Destination module' do
      expect(DummySchema.const_defined?(:Destination)).to be_truthy
    end

    context 'when inheriting from a subclass of DatabaseTransform::Schema' do
      class DummySchema2 < DummySchema
      end

      it "contains the parent class's tables" do
        expect(DummySchema2.tables).to include(DummySchema.tables)
      end
    end
  end

  describe '.migrate_table' do
    it 'defines models for symbol source tables' do
      expect(DummySchema::Source.const_defined?(:Source)).to be_truthy
    end

    it 'defines models for string destination tables' do
      expect(DummySchema::Source.const_defined?(:Destination)).to be_truthy
    end
  end
end
