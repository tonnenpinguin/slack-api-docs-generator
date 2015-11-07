require 'mechanize'
require "reverse_markdown"
require "pry"

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
    end

    register :p, P.new
  end
end

page  = agent.get 'https://api.slack.com/methods'
methods = page.search(".card table a").map(&:text)

methods.each do |name|
  sleep 1
  puts name

  page = agent.get "https://api.slack.com/methods/#{name}"

  # markdown
  source = page.search("section[@data-tab=docs]")[0].children.to_s
  markdown = ReverseMarkdown.convert source
  File.write("../slack-api-docs/methods/#{name}.md", markdown)

  # json
  args = page.search("section[@data-tab=docs]/*[text()=\"Arguments\"]~table")[0]
  args = args.search("tr").each_with_object({}){|tr, o|
    tds = tr.search("td")
    next if tds.size == 0
    o[tds[0].text] = {
      required: tds[2].text.strip == "Required",
      example: tds[1].text.strip,
      desc: tds[3].text.strip,
    }
  }

  errors = page.search("section[@data-tab=docs]/*[text()=\"Errors\"]~table")[0]
  errors = errors.nil? ? {} : errors.search("tr").each_with_object({}){|tr, o|
    tds = tr.search("td")
    next if tds.size == 0
    o[tds[0].text] = ReverseMarkdown.convert(tds[1].inner_html).strip
  }
  File.write("../slack-api-docs/methods/#{name}.json", JSON.pretty_generate({
    desc: page.search("section[@data-tab=docs]/p")[0].text, 
    args: args,
    errors: errors,
  }))

end
