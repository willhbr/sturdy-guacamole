require "json"
require 'date'
require "erb"
require "fileutils"

THUMBNAIL_COMPPRESSION = 70
THUMBNAIL_SIZE = 640
IMAGE_COMPRESSION = 85
IMAGE_SIZE = 1440

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

def do_image(image_file, message)
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
  File.write("_posts/#{date_str}-post.md", md)
  puts "Writing thumbnail for #{image}"
  convert_thumbnail(image_file, THUMBNAIL_SIZE,
                THUMBNAIL_COMPPRESSION, "thumbnail/#{image}")
  puts "Writing #{image}"
  convert_image(image_file, IMAGE_SIZE,
                IMAGE_COMPRESSION, "photos/#{image}")
  puts "Finished #{message.split("\n")[0]}"
end

bare_repo = ARGV[0]

# clone bare repo to tmp

working_repo =  "/tmp/photos-raw"
clone_or_pull working_repo, bare_repo

# find last commit

last_hash = File.exists?(".last-hash") ? File.read(".last-hash").strip : nil

# list commits from last to HEAD

if ARGV[1]
  puts "using specific commit: #{ARGV[1]}"
  commits = [ARGV[1]]
elsif last_hash.nil?
  puts "no last hash"
  commits = ["HEAD"]
else
  puts "Getting from #{last_hash}"
  commits = `git -C #{working_repo} rev-list --ancestry-path #{last_hash}..HEAD`.split("\n")
end

# process each commit

last_processed = nil

commits.each do |hash|
  puts "Handling #{hash}"
  image = get_files(working_repo, hash).find { |file| file.match?(/\.jpe?g/) }
  image_path = working_repo + '/' + image
  message, last_processed = get_message working_repo, hash

  do_image(image_path, message)

  # sys_or_fail 'git', 'commit', '-am', message
end

# push changes

File.write(".last-hash", last_processed) if last_processed

