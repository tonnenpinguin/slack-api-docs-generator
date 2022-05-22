require 'mechanize'
require "reverse_markdown"
require "pry"
require "json"

target_dir = ARGV[0] || "../slack-api-docs"
agent = Mechanize.new
ReverseMarkdown.config do |config|
  config.unknown_tags     = :pass_through
  config.github_flavored  = true
end
module ReverseMarkdown
  module Converters
    class P < Base
      def convert(node)
        if node.parent.name == "td"
          treat_children(node).strip
        else
          "\n" << treat_children(node).strip << "\n"
        end
      end

      def convert(node, other)
        "\n" << treat_children(node, other).strip << "\n"
      end
    end

    register :p, P.new
  end
end

# page  = agent.get 'https://api.slack.com/methods'
# methods = page.search(".apiReferenceFilterableList__listItemLink").map(&:text)
methods = ["admin.analytics.getFile"]
methods.each do |name|
  sleep 1
  puts name

  page = agent.get "https://api.slack.com/methods/#{name}"

  # markdown
  source = page.search("section[@data-tab=docs]")[0].children.to_s
  markdown = ReverseMarkdown.convert(source,  unknown_tags: :drop)
  File.write("#{target_dir}/methods/#{name}.md", markdown)

  # json
  args = page.search(".apiMethodPage__argumentRow").each_with_object({}){|arg, o|
    argName = arg.search(".apiMethodPage__argument").text
    example = arg.search(".apiReference__exampleCode").inner_html
    desc = arg.search(".apiMethodPage__argumentDesc > p").inner_html
    o[argName] = {
      required: arg.search(".apiMethodPage__argumentOptionality--required").size == 1,
      example: ReverseMarkdown.convert(example).strip,
      desc: ReverseMarkdown.convert(desc).strip,
    }
  }

  errors = page.search(".apiReference__errors > table")[0]
  errors = errors.nil? ? {} : errors.search("tr").each_with_object({}){|tr, o|
    tds = tr.search("td")
    next if tds.size == 0
    o[tds[0].text] = ReverseMarkdown.convert(tds[1].inner_html).strip
  }

  response = page.search(".apiReference__response > .apiReference__example")
  response = response.nil? || response.empty? ? {} : 
    response.each_with_object({}){|resp, o|
      kind = resp.text.include?("success") ? "success" : "error"
      codeResp = resp.search("pre > code")
      o[kind] = codeResp.empty? ?
        resp.search("p").text :
        JSON.parse(codeResp.text)
    }

  mainDesc = page.search(".apiReference__mainDescription").inner_html
  extendedDesc = page.search(".apiDocsPage__markdownOutput").inner_html

  File.write("#{target_dir}/methods/#{name}.json", JSON.pretty_generate({
    desc: ReverseMarkdown.convert(mainDesc << "\n\n" << extendedDesc).strip, 
    args: args,
    response: response,
    errors: errors,
  }))

end
