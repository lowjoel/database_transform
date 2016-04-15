require 'spec_helper'

RSpec.describe DatabaseTransform::Schema do
  class DummySchema < DatabaseTransform::Schema
    transform_table :source, to: 'destination' do
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

    context 'when two subclasses of DatabaseTransform::Schema exists' do
      class DummySchema3 < DatabaseTransform::Schema; end
      it 'contains separate tables' do
        expect(DummySchema3.tables.size).not_to eq(DummySchema.tables.size)
      end
    end
  end

  describe 'configurations' do
    class DummySchemaWithConfiguration < DatabaseTransform::Schema
      concurrency 4

      transform_table :source, to: 'destination' do
      end
    end
    let(:schema) { DummySchemaWithConfiguration.new }

    describe '.concurrency' do
      subject { schema.concurrency }

      it { is_expected.to eq(4) }
    end
  end

  describe '.transform_table' do
    it 'defines models for symbol source tables' do
      expect(DummySchema::Source.const_defined?(:Source)).to be_truthy
    end

    it 'defines models for string destination tables' do
      expect(DummySchema::Source.const_defined?(:Destination)).to be_truthy
    end
  end

  describe '.deduce_connection_name' do
    class DummySchema4 < DummySchema; end
    it 'checks the underscored schema name' do
      expect(DummySchema4.send(:deduce_connection_name)).to eq('dummy_schema4')
    end

    it 'uses the _production suffix if the normal name does not exist' do
      # The dummy_schema configuration we use has the _production suffix deliberately added
      expect(DummySchema.send(:deduce_connection_name)).to eq('dummy_schema_production')
    end
  end

  describe '#transform!' do
    context 'when the dependencies cannot be met' do
      class DummyCyclicDependencySchema < DatabaseTransform::Schema
        transform_table :a, to: :b, depends: [:a] do
        end
      end

      subject { DummyCyclicDependencySchema.new }

      it 'raises DatabaseTransform::UnsatisfiedDependencyError' do
        expect { subject.transform! }.to raise_error(DatabaseTransform::UnsatisfiedDependencyError)
      end
    end
  end
end
