#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'pathname'

module YamlValidator
  ROOT = Pathname.new(__dir__).join('..').expand_path
  PLACEHOLDER = 'PLACEHOLDER'

  CONTROL_LINE = /\A\{\{-?\s*(?:if|else|end|with|range|define|template|toYaml|nindent|indent|tpl|\$|\/\*|#|block|include).*?\}\}\s*\z/
  TEMPLATE_EXPR = /\{\{-?\s*[^\{\}]+?-?\}\}/

  module_function

  def placeholder_for(before, after)
    trimmed_before = before.rstrip
    last_char = trimmed_before[-1]
    next_char = after.lstrip[0]

    if ['"', "'", '`'].include?(last_char) && next_char == last_char
      PLACEHOLDER
    elsif last_char == ':' || last_char == '-'
      " #{PLACEHOLDER}"
    else
      PLACEHOLDER
    end
  end

  def sanitize(content)
    content.each_line.map do |line|
      stripped = line.strip
      if stripped.empty?
        line
      elsif stripped.match?(CONTROL_LINE)
        ""
      else
        replaced = line.gsub(TEMPLATE_EXPR) do
          match = Regexp.last_match
          before = match.pre_match
          after = match.post_match
          placeholder_for(before, after)
        end
        replaced
      end
    end.join
  end

  def validate!(path)
    content = File.read(path)
    sanitized = sanitize(content)
    YAML.safe_load(sanitized, aliases: true)
  end

  def run
    errors = []

    Dir.chdir(ROOT) do
      Dir.glob('**/*.{yml,yaml}').each do |path|
        next if File.directory?(path)
        begin
          validate!(path)
          puts "Validated #{path}"
        rescue Psych::SyntaxError => e
          errors << [path, e.message]
        rescue StandardError => e
          errors << [path, "Unexpected error: #{e.message}"]
        end
      end
    end

    if errors.empty?
      puts 'All YAML files are valid.'
    else
      errors.each { |path, message| warn "#{path}: #{message}" }
      exit 1
    end
  end
end

if $PROGRAM_NAME == __FILE__
  YamlValidator.run
end
