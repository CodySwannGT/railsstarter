# frozen_string_literal: true

require 'ripper'

# Inspect a generated dump without executing database DDL or arbitrary Ruby.
class GeneratedSchemaTables
  # Raised when a dump cannot be read or does not match admitted generated Ruby schema syntax.
  class Error < StandardError; end

  # Non-table generated schema declarations ignored while collecting create_table names.
  DECLARATIONS = %w[add_foreign_key add_index add_check_constraint add_unique_constraint
                    add_exclusion_constraint create_schema enable_extension].freeze

  def initialize(path, format)
    @path = path
    @format = format
  end

  def tables
    raise Error, "Unsupported schema format #{@format}; configure Ruby schema_format: ruby and run bin/rails db:schema:dump" unless @format == :ruby

    statements.filter_map { |statement| table_name(statement) }.sort
  end

  private

  def statements
    invalid_schema('Configure schema_dump') unless @path
    case Ripper.sexp(File.read(@path))
    in [:program, [[:method_add_block,
                    [:method_add_arg,
                     [:call,
                      [:aref, [:const_path_ref, [:var_ref, [:@const, 'ActiveRecord', *]], [:@const, 'Schema', *]],
                       [:args_add_block, [[(:@float | :@int), _, _]], false]],
                      _, [:@ident, 'define', *]], *],
                    [:do_block, nil, [:bodystmt, body, nil, nil, nil]]]]]
      body
    else
      invalid_schema('Expected a generated Ruby schema')
    end
  rescue SystemCallError, IOError => error
    invalid_schema("Cannot read #{@path}: #{error.message}")
  end

  def table_name(statement)
    return if statement == [:void_stmt]

    case statement
    in [:method_add_block, command, _]
      table_name(command)
    in [:command, [:@ident, 'create_table', *], [:args_add_block, [argument, *], false]]
      literal_table_name(argument)
    in [:command, [:@ident, name, *], _] if DECLARATIONS.include?(name)
      nil
    else
      invalid_schema('Expected a generated Ruby schema declaration')
    end
  end

  def literal_table_name(argument)
    case argument
    in [:string_literal, [:string_content, [:@tstring_content, name, *]]]
      "\"#{name}\"".undump
    else
      invalid_schema('Expected a literal table name')
    end
  rescue ArgumentError
    invalid_schema('Expected a literal table name in a generated Ruby schema')
  end

  def invalid_schema(message)
    raise Error, "#{message} (#{@path || 'schema_dump is disabled'}); run bin/rails db:schema:dump"
  end
end
