#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment'))

ActiveRecord::Base.connection.execute("set statement_timeout = 0")
ActiveRecord::Base.connection.execute("update posts set last_commented_at = (select max(c.created_at) from comments c where c.post_id = posts.id)")
TagImplication.find_each do |ti|
  ta = TagAlias.where("antecedent_name = ? AND status != ?", ti.antecedent_name, "pending").first
  if ta
    puts "testing alias #{ta.antecedent_name} -> #{ta.consequent_name}"
    existing_ti = TagImplication.where("antecedent_name = ? AND consequent_name = ?", ta.consequent_name, ti.consequent_name).first
    existing_ti.destroy if existing_ti

    if ta.consequent_name == ti.consequent_name
      puts "  deleting implication #{ti.antecedent_name} -> #{ti.consequent_name}"
      ti.destroy
    else
      puts "  updating implication #{ti.antecedent_name} -> #{ti.consequent_name}"
      ti.antecedent_name = ta.consequent_name
      ti.save
      ti.update_posts
    end

    puts "  updating alias posts"
    ta.update_posts
  end
end