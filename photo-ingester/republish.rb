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
  if Dir.exists? path
    Dir.chdir(path)
    sys_or_fail "git", "-C", path, "pull"
  else
    sys_or_fail "git","clone", remote, path
  end
end

def get_files(path, rev)
  `git -C #{path} diff-tree --no-commit-id --name-only -r #{rev}`.split("\n")
end

def get_message(path, rev)
  lines = `git -C #{path} rev-list --format=%B --max-count=1 #{rev}`.split("\n")
  hash = lines.shift.split(' ').last
  [lines.join("\n"), hash]
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

def convert_thumbnail(image, size, quality, output)
  w, h = get_size(image)
  cs = [w, h].min
  x = (w - cs) / 2
  y = (h - cs) / 2

  sys_or_fail('convert', image, '-crop', "#{cs}x#{cs}+#{x}+#{y}",
              '-resize', "#{size}x#{size}", '-quality', quality.to_s, '-strip', output)
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
  convert_thumbnail(image_file, config['thumbnail_size'].to_i,
                config['thumbnail_compression'].to_i, "#{repo}/thumbnail/#{image}")
  convert_image(image_file, config['image_size'].to_i,
                config['image_compression'].to_i, "#{repo}/photos/#{image}")
end

config = JSON.parse(File.read(ARGV[0]))
repo_path = config['repo_path']
repo_remote = config['repo_remote']
working_repo = config['watch_repo']


clone_or_pull repo_path, repo_remote

commits = ["HEAD"]

last_hash = "#{repo_path}/.last-hash"
if File.exists? last_hash
  lh = File.read(last_hash).strip
  puts "Getting from #{lh}"
  commits = `git -C #{working_repo} rev-list --ancestry-path #{lh}..HEAD`.split("\n")
end

last_processed = nil

commits.each do |hash|
  puts "Handling #{hash}"
  image = get_files(working_repo, hash).find { |file| file.match?(/\.jpe?g/) }
  image_path = working_repo + '/' + image
  message, last_processed = get_message working_repo, hash

  do_image(repo_path, image_path, message, config)

  sys_or_fail 'git', 'commit', '-am', message
end

File.write(last_hash, last_processed) if last_processed
