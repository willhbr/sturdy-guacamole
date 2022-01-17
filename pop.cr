date = Time.utc

Dir["photos/*.jpeg"].each do |photo|
  p = Path.new(photo)
  next if p.basename.starts_with? "thumb"
  thumb = p.parent / ("thumb-" + p.stem + ".jpeg")
  File.write("_posts/#{date.to_s("%Y-%m-%d-photo.md")}", "---
layout: post
image: http://jared.lan:4001/#{photo}
thumbnail: /#{thumb}
date: #{date.to_s("%Y-%m-%d")}
---
")
  date -= 1.day
end
