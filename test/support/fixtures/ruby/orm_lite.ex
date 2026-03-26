defmodule Test.Fixtures.Ruby.OrmLite do
  @moduledoc false
  use Test.LanguageFixture, language: "ruby orm_lite"

  @code ~S'''
  module OrmLite
    module Persistence
      def self.included(base)
        base.extend(ClassMethods)
        base.instance_variable_set(:@columns, [])
        base.instance_variable_set(:@validations, [])
      end

      module ClassMethods
        def column(name, type = :string)
          @columns << { name: name, type: type }
          attr_accessor name
        end

        def validates(name, **rules)
          @validations << { name: name, rules: rules }
        end

        def columns
          @columns
        end

        def validations
          @validations
        end

        def find(id)
          new(id: id)
        end
      end

      def initialize(attrs = {})
        attrs.each do |key, value|
          send(:"#{key}=", value) if respond_to?(:"#{key}=")
        end
      end

      def valid?
        @errors = []
        self.class.validations.each do |v|
          value = send(v[:name])
          @errors << "#{v[:name]} can't be blank" if v[:rules][:presence] && (value.nil? || value.to_s.empty?)
          @errors << "#{v[:name]} is too short" if v[:rules][:min_length] && value.to_s.length < v[:rules][:min_length]
        end
        @errors.empty?
      end

      def errors
        @errors ||= []
      end

      def save
        return false unless valid?
        true
      end
    end

    module Associations
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def has_many(name)
          define_method(name) do
            []
          end
        end

        def belongs_to(name)
          attr_accessor :"#{name}_id"
          define_method(name) do
            nil
          end
        end
      end
    end
  end

  class User
    include OrmLite::Persistence
    include OrmLite::Associations
    column :name, :string
    column :email, :string
    column :age, :integer
    has_many :posts
    validates :name, presence: true, min_length: 2
    validates :email, presence: true
  end

  class Post
    include OrmLite::Persistence
    include OrmLite::Associations
    column :title, :string
    column :body, :text
    belongs_to :user
    validates :title, presence: true
    validates :body, presence: true
  end
  '''
end
