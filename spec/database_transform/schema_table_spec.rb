require 'spec_helper'

RSpec.describe DatabaseTransform::SchemaTable do
  subject { DatabaseTransform::SchemaTable.new(source_model, destination_model, options) }
  let(:source_model) { Source }
  let(:destination_model) { Destination }
  let(:options) { {} }
  let(:dummy_records) do
    Source.transaction do
      (0..3).each do |i|
        Source.create(val: i, content: format('%d counts!', i.to_f))
      end
    end
  end

  describe '#primary_key' do
    it 'sets the primary key for the source table' do
      subject.primary_key :id
      expect(subject.instance_variable_get(:@primary_key)).to eq(:id)
    end
  end

  describe '#column' do
    it 'declares the mapping for the given column' do
      subject.column :name
      expect(subject.instance_variable_get(:@columns).find { |c| c[:from] == [:name] }).to be_truthy
    end

    context 'when a null attribute is given but no to column is specified' do
      it 'raises an error' do
        expect { subject.column :name, null: false do end }.to raise_error(ArgumentError)
      end
    end

    context 'when multiple columns are specified and a to column is specified without a block' do
      it 'raises an error' do
        expect { subject.column :uid, :name, to: :name }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#save' do
    it 'declares a conditional save for the given column' do
      subject.save if: proc { c.dirty? }
      expect(subject.instance_variable_get(:@save)).to be_truthy
    end

    context 'when #save is called twice' do
      it 'raises an error' do
        subject.save if: proc { c.dirty? }
        expect { subject.save if: proc { c.dirty? } }.to raise_error(ArgumentError)
      end
    end

    context 'when #save is given an unless block' do
      it 'inverts the condition' do
        subject.save unless: proc { c.destroyed? }
        expect(subject.instance_variable_get(:@save)[:if]).to be_truthy
      end
    end

    context 'when #save is given a validate clause' do
      it 'follows the value' do
        subject.save validate: false
        expect(subject.instance_variable_get(:@save)[:validate]).to eq(false)
      end
    end

    context 'when #save is not given a validate clause' do
      it 'defaults to true' do
        subject.save
        expect(subject.instance_variable_get(:@save)[:validate]).to be_truthy
      end
    end
  end

  describe '#transform!' do
    before { dummy_records }

    context 'before a transformation' do
      class Source2 < ActiveRecord::Base
        self.table_name = 'sources'
      end
      let(:source_model) { Source2 }
      before { subject }

      it 'does not have any transformed records' do
        expect(source_model.transformed?(source_model.first.id)).to be_falsey
      end

      it 'raises an error when trying to transform a record' do
        expect { source_model.transform(source_model.first.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when a default scope is specified' do
      let(:options) { { default_scope: proc { where('id % 2 = 0') } } }
      before do
        subject.column :id, to: :id
      end

      it 'all records match the default scope' do
        destination_model.delete_all
        subject.run_transform
        expect(destination_model.count).not_to be(0)
        destination_model.all.each do |row|
          expect(row.id % 2).to eq(0)
        end
      end
    end

    context 'when collection does not respond to #find_in_batches' do
      let(:options) { { default_scope: proc { all.to_a } } }
      before do
        subject.column :id, to: :id
      end

      it 'transforms all the records' do
        destination_model.delete_all
        subject.run_transform
        expect(destination_model.count).not_to be(0)
      end
    end

    context 'when a mapping transform is specified' do
      class DummySchema < DatabaseTransform::Schema
        class_attribute :magic_cookie
        self.magic_cookie = 42
      end

      it 'allows access to the schema' do
        subject.column :val, to: :val do |val|
          fail unless schema.magic_cookie == 42
          val
        end
        subject.run_transform(DummySchema.new)
      end

      it 'allows access to the source record' do
        subject.column :val do |val|
          fail if val != source_record.val
        end
        subject.run_transform
      end

      context 'when multiple source columns are specified' do
        before do
          subject.column :val
          subject.column :val, :content, to: :content do |val, content|
            format('%d%s', val, content)
          end
        end

        it 'provides all columns to the block' do
          destination_model.delete_all
          subject.run_transform
          expect(destination_model.count).not_to be(0)
          destination_model.all.each do |row|
            expect(row.content).to eq(format('%d%d counts!', row.val, row.val))
          end
        end
      end

      context 'when a destination column is specified' do
        before do
          subject.column :id, to: :id do |id|
            id * 2 + 1
          end
        end

        it 'sets the corresponding column with the result of the transform' do
          destination_model.delete_all
          subject.run_transform
          expect(destination_model.count).not_to be(0)
          destination_model.all.each do |row|
            expect(row.id % 2).to eq(1)
          end
        end
      end

      context 'when a destination column is not specified' do
        before do
          subject.column :val do
            0
          end
        end

        it 'does not modify the record' do
          destination_model.delete_all
          subject.run_transform
          expect(destination_model.count).not_to be(0)
          destination_model.all.each do |row|
            expect(row.val).to be_nil
          end
        end
      end

      context 'when no destination model is specified' do
        let(:destination_model) { nil }
        before do
          subject.column :val
          subject.column :val, :content, to: :content do |val, content|
            Destination.create(val: val, content: content)
          end
        end

        it 'provides all columns to the block' do
          Destination.delete_all
          subject.run_transform
          expect(Destination.count).not_to be(0)
          Destination.all.each do |row|
            expect(row.content).to eq(format('%d counts!', row.val))
          end
        end
      end
    end

    context 'when a mapping transform is not specified' do
      context 'when a destination column is specified' do
        before do
          subject.column :val, to: :val
          subject.column :val, to: :content
        end

        it 'sets the corresponding column' do
          destination_model.delete_all
          subject.run_transform
          expect(destination_model.count).not_to be(0)
          destination_model.all.each do |row|
            expect(row.val.to_s).to eq(row.content)
          end
        end

        context 'when multiple source columns are specified' do
          it 'fails' do
            expect { subject.column :val, :content, to: :content }.to raise_error(ArgumentError)
          end
        end
      end

      context 'when a destination column is not specified' do
        before do
          subject.column :content
        end
        it 'sets the corresponding column with the same name in the destination' do
          destination_model.delete_all
          subject.run_transform
          expect(destination_model.count).not_to be(0)
          destination_model.all.each do |row|
            expect(row.content).not_to be_nil
          end
        end
      end
    end

    context 'when a primary key is specified' do
      before do
        subject.primary_key :id
        subject.column :val
        subject.column :val, :content, to: :content do |val, content|
          format('%d%s', val, content)
        end
      end

      it 'can find every new model object created' do
        destination_model.delete_all
        subject.run_transform
        expect(destination_model.count).not_to be(0)
        source_model.all.each do |row|
          expect(source_model.transform(row.id)).to_not be_nil
        end
      end
    end

    context 'when a column is declared to be null: false' do
      before do
        subject.column :id
        subject.column :val, to: :val, null: false do
          nil
        end
      end

      it 'raises an exception' do
        expect { subject.run_transform }.to raise_error(ArgumentError)
      end

      context 'when the column does not have a destination column' do
        it 'raises an error' do
          expect { subject.column :val, null: false do end }.to raise_error(ArgumentError)
        end
      end
    end

    context 'when a column transform freezes the object' do
      before do
        subject.column :id do |id|
          freeze
          id
        end
        subject.column :val do
          fail
        end
      end

      it 'stops the transform' do
        subject.run_transform
      end
    end

    context 'when a transform specifies the save behaviour' do
      class TrueError < StandardError; end
      class FalseError < StandardError; end

      before do
        subject.column :id do |id|
          define_singleton_method(:save!) do |options|
            raise TrueError.new if options[:validate]
            raise FalseError.new
          end
          id
        end
      end

      it 'saves without validation' do
        subject.save validate: false
        expect { subject.run_transform }.to raise_error(FalseError)
      end

      it 'saves with validation' do
        expect { subject.run_transform }.to raise_error(TrueError)
      end
    end
  end
end
