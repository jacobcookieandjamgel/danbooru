class TagCorrection
  attr_reader :tag_id, :tag, :hostname

  def initialize(tag_id, hostname = Socket.gethostname)
    @tag_id = tag_id
    @tag = Tag.find(tag_id)
    @hostname = hostname
  end

  def to_json(options = {})
    statistics_hash.to_json
  end

  def statistics_hash
    @statistics_hash ||= {
      "category_cache" => Cache.get("tc:" + Cache.sanitize(tag.name)),
      "post_fast_count_cache" => Cache.get("pfc:" + Cache.sanitize(tag.name))
    }
  end

  def fill_hash!
    Net::HTTP.start(hostname, 80) do |http|
      http.request_get("/tags/#{tag_id}/correction.json") do |res|
        if res === Net::HTTPSuccess
          json = JSON.parse(res.body)
          statistics_hash["category_cache"] = json["category_cache"]
          statistics_hash["post_fast_count_cache"] = json["post_fast_count_cache"]
        end
      end
    end
  end

  def each_server
    Danbooru.config.all_server_hosts.each do |host|
      other = TagCorrection.new(tag_id, host)

      if host != Socket.gethostname
        other.fill_hash!
      end

      yield other
    end
  end

  def fix!
    tag.delay(:queue => "default").fix_post_count
    tag.update_category_cache_for_all
    Post.expire_cache_for_all([tag.name])
  end
end
