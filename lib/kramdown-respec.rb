# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2010 Thomas Leitner <t_leitner@gmx.at>
# Copyright (C) 2020 CoSMo Software, Ludovic Roux <ludovic.roux@cosmosoftware.io>
#
# This file was derived from a part of the kramdown gem which is licensed under the MIT license.
# This derived work is also licensed under the MIT license, see LICENSE.
#++
#

raise "sorry, 1.8 was last decade" unless RUBY_VERSION >= '1.9'

gem 'kramdown', '~> 1.14'
require 'kramdown'
require 'kramdown/parser'
require 'kramdown/converter'
require 'kramdown/utils'

module Kramdown

  # Re-open class Document
  #
  # The main interface to kramdown-respec.
  #
  # This class provides a one-stop-shop for using kramdown-respec to convert text into various output
  # formats. Use it like this:
  #
  #   require 'kramdown-respec'
  #   doc = KramdownRespec::Document.new('This *is* some kramdown-respec text')
  #   puts doc.to_html
  #
  # The #to_html method is a shortcut for using the Converter::Html class. See #method_missing for
  # more information.
  #
  # The second argument to the ::new method is an options hash for customizing the behaviour of the
  # used parser and the converter. See ::new for more information!
  class Document

    # Redfine method initialize()
    #
    # Create a new KramdownRespec document from the string +source+ and use the provided +options+.
    # The options that can be used are defined in the Options module.
    #
    # The special options key :input can be used to select the parser that should parse the
    # +source+. It has to be the name of a class in the KramdownRespec::Parser module. For example, to
    # select the kramdown-respec parser, one would set the :input key to +KramdownRespec+. If this key
    # is not set, it defaults to +KramdownRespec+.
    #
    # The +source+ is immediately parsed by the selected parser so that the root element is
    # immediately available and the output can be generated.
    def initialize(source, options = {})
      @options = Options.merge(options).freeze
      # parser = (@options[:input] || 'kramdown-respec').to_s
      parser = (@options[:input] || 'kramdown').to_s
      parser = parser[0..0].upcase + parser[1..-1]
      try_require('parser', parser)
      if Parser.const_defined?(parser)
        @root, @warnings = Parser.const_get(parser).parse(source, @options)
      else
        raise Kramdown::Error.new("kramdown-respec has no parser to handle the specified input format: #{@options[:input]}")
      end
    end

  end


  module Parser

    # class KramdownRespec < Kramdown::Parser::Kramdown

    class Kramdown < Base

      include ::Kramdown

      # List of possible annotations
      # If annotation is not in the list, then it should be a reference to a test
      RESPECTESTS_ANNOTATIONS = ["untestable", "informative", "note", "no-test-needed", "needs-test"]

      RESPECTESTS = /\{:&(.*)\}/
      RESPECTESTS_START = /^#{OPT_SPACE}#{RESPECTESTS}/

      # Parse one of the block extensions (ALD, block IAL or generic extension) at the current
      # location.
      def parse_block_extensions
        # Parse the string +str+ and extract the annotation or the list of tests
        if @src.scan(RESPECTESTS_START)
          last_child = @tree.children.last
          if last_child.type == :header
            parse_respec_tests_list(@src[1], last_child.options[:respec_section] ||= {})
            @tree.children << new_block_el(:eob, :respec_section)
          else
            parse_respec_tests_list(@src[1], last_child.options[:ial] ||= {})
            @tree.children << new_block_el(:eob, :ial)
          end
        # Original parser of block extensions
        elsif @src.scan(ALD_START)
          parse_attribute_list(@src[2], @alds[@src[1]] ||= Utils::OrderedHash.new)
          @tree.children << new_block_el(:eob, :ald)
          true
        elsif @src.check(EXT_BLOCK_START)
          parse_extension_start_tag(:block)
        elsif @src.scan(IAL_BLOCK_START)
          if @tree.children.last && @tree.children.last.type != :blank &&
              (@tree.children.last.type != :eob || [:link_def, :abbrev_def, :footnote_def].include?(@tree.children.last.value))
            parse_attribute_list(@src[1], @tree.children.last.options[:ial] ||= Utils::OrderedHash.new)
            @tree.children << new_block_el(:eob, :ial) unless @src.check(IAL_BLOCK_START)
          else
            parse_attribute_list(@src[1], @block_ial ||= Utils::OrderedHash.new)
          end
          true
        else
          false
        end
      end

      # Parse the string +str+ and extract the annotation or the list of tests
      def parse_respec_tests_list(str, opts)
        str = str.strip
        if RESPECTESTS_ANNOTATIONS.include?(str)
          opts['class'] = "#{str}"
        else
          opts['data-tests'] = "#{str}"
        end
      end

      def parse_respectests
        last_child = @tree.children.last
        if last_child.type == :header
          parse_respec_tests_list(@src[1], last_child.options[:respec_section] ||= {})
          @tree.children << new_block_el(:eob, :respec_section)
        else
          parse_respec_tests_list(@src[1], last_child.options[:ial] ||= {})
          @tree.children << new_block_el(:eob, :ial)
        end
      end


      define_parser(:respectests, RESPECTESTS_START, '{:&')

    end

  end

  module Converter

    # Converts an element tree to the kramdown-respec format.
    # class KramdownRespec < Kramdown
    # end


    # class HtmlRESPEC < Html
    class Html < Base

      # Initialize the HTML converter with the given Kramdown document +doc+.
      def initialize(root, options)
        super
        @footnote_counter = @footnote_start = @options[:footnote_nr]
        @footnotes = []
        @footnotes_by_name = {}
        @footnote_location = nil
        @toc = []
        @toc_code = nil
        @indent = 2
        @stack = []
        @respec_first_section = true
        @respec_last_header_level = 0
      end
      # Initialize the HTML converter with the given Kramdown document +doc+.
      # def initialize(root, options)
      #   super
      #   @respec_first_section = true
      #   @respec_last_header_level = 0
      # end

      def convert_root(el, indent)
        result = inner(el, indent)
        if @footnote_location
          result.sub!(/#{@footnote_location}/, footnote_content.gsub(/\\/, "\\\\\\\\"))
        else
          result << footnote_content
        end
        if @toc_code
          toc_tree = generate_toc_tree(@toc, @toc_code[0], @toc_code[1] || {})
          text = if toc_tree.children.size > 0
                   convert(toc_tree, 0)
                 else
                   ''
                 end
          result.sub!(/#{@toc_code.last}/, text.gsub(/\\/, "\\\\\\\\"))
        end
        # Close the last sections that remain opened
        current_header_level = 2
        while @respec_last_header_level > current_header_level
          result += "</section>\n\n"
          @respec_last_header_level -= 1
        end
        result + "</section>\n\n"
        result
      end
      # def convert_root(el, indent)
      #   result = super
      #   # Close the last sections that remain opened
      #   current_header_level = 2
      #   while @respec_last_header_level > current_header_level
      #     result += "</section>\n\n"
      #     @respec_last_header_level -= 1
      #   end
      #   result + "</section>\n\n"
      # end

      def convert_header(el, indent)
        res = ""
        current_header_level = el.options[:level]
        if @respec_first_section
          @respec_first_section = false
          @respec_last_header_level = current_header_level
        else
          if @respec_last_header_level < current_header_level
            @respec_last_header_level = current_header_level
          else
            while @respec_last_header_level > current_header_level
              res += "#{' ' * indent}</section>\n\n"
              @respec_last_header_level -= 1
            end
            res += "#{' ' * indent}</section>\n\n"
          end
        end
        if el.options[:respec_section]
          res += "#{' ' * indent}<section#{html_attributes(el.options[:respec_section])}>\n"
        else
          res += "#{' ' * indent}<section>\n"
        end
        # res + super

        attr = el.attr.dup
        if @options[:auto_ids] && !attr['id']
          attr['id'] = generate_id(el.options[:raw_text])
        end
        @toc << [el.options[:level], attr['id'], el.children] if attr['id'] && in_toc?(el)
        level = output_header_level(el.options[:level])
        res + format_as_block_html("h#{level}", attr, inner(el, indent), indent)
      end
      # def convert_header(el, indent)
      #   res = ""
      #   current_header_level = el.options[:level]
      #   if @respec_first_section
      #     @respec_first_section = false
      #     @respec_last_header_level = current_header_level
      #   else
      #     if @respec_last_header_level < current_header_level
      #       @respec_last_header_level = current_header_level
      #     else
      #       while @respec_last_header_level > current_header_level
      #         res += "#{' ' * indent}</section>\n\n"
      #         @respec_last_header_level -= 1
      #       end
      #       res += "#{' ' * indent}</section>\n\n"
      #     end
      #   end
      #   if el.options[:respec_section]
      #     res += "#{' ' * indent}<section#{html_attributes(el.options[:respec_section])}>\n"
      #   else
      #     res += "#{' ' * indent}<section>\n"
      #   end
      #   res + super
      # end

    end

  end

end