require "json"
require 'date'
require "erb"
require "fileutils"

ACTUAL_TEMPLATE = <<-EOF
---
layout: post
date: <%= date.strftime("%F") %>
title: "<%= title %>"
image: <%= image %>
<%- unless location.nil? -%>
location: "<%= location %>"
<%- end -%>
---

<%= content %>
EOF


TEMPLATE = ERB.new(ACTUAL_TEMPLATE, trim_mode: '-')

def sys_or_fail(*args)
  unless system(*args)
    raise "Failed to execute #{args}"
  end
end

def clone_or_pull(path, remote)
  sys_or_fail "git","clone", remote, path
end

def get_files(path, rev)
  `git -C #{path} diff-tree --no-commit-id --name-only -r #{rev}`.split("\n")
end

def get_message(path, rev)
  lines = `git -C #{path} rev-list --format=%B --max-count=1 #{rev}`.split("\n")
  lines.shift
  lines.join("\n")
end

def get_size(image)
  `convert '#{image}' -format '%[w]x%[h]' info:`.strip.split('x').map(&:to_i)
end

def calculate_size(w, h, size)
  if w > h
    height = size
    width = (size.to_f / h) * w
  else
    height = (size.to_f / w) * h
    width = size
  end
  [width.to_i, height.to_i]
end

def convert_image(image, size, quality, output)
  w, h = get_size(image)
  width, height = calculate_size w, h, size
  sys_or_fail('convert', image, '-resize', "#{width}x#{height}", '-quality',
              quality.to_s, '-strip', output)
end

def do_image(repo, image_file, message, config)
  location = nil
  content = ''
  date = Date.parse(image_file.split('/')[-1]) rescue Date.today

  message.split("\n").each do |line|
    if line.start_with? 'DATE='
      date = Date.parse(line.split('=')[1])
      next
    end
    if line.start_with? 'LOCATION='
      location = line.split('=')[1]
      next
    end
    content += line + "\n"
  end

  content = content.strip

  if location
    title = "Pic at #{location}"
  else
    title = "Pic on #{date}"
  end

  date_str = date.strftime('%F')
  image = "#{date_str}.jpeg"

  md = TEMPLATE.result(binding)
  File.write("#{repo}/_posts/#{date_str}-post.md", md)
  convert_image(image_file, config['thumbnail_size'].to_i,
                config['thumbnail_compression'].to_i, "#{repo}/thumbnail/#{image}")
  convert_image(image_file, config['image_size'].to_i,
                config['image_compression'].to_i, "#{repo}/photos/#{image}")
end

config = JSON.parse(File.read(ARGV[0]))
repo_path = config['repo_path']
repo_remote = config['repo_remote']
working_repo = config['watch_repo']

# clone_or_pull repo_path, repo_remote

image = get_files(working_repo, 'HEAD').find { |file| file.match?(/\.jpe?g/) }
image_path = working_repo + '/' + image
message = get_message working_repo, 'HEAD'

puts do_image(repo_path, image_path, message, config)

