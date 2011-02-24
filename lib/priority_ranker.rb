class PriorityRanker
  
  def perform
    Government.current = Government.all.last

    if Government.current.is_tags? and Tag.count > 0
      # update the # of issues people who've logged in the last two hours have up endorsed
      users = User.find_by_sql("SELECT users.id, users.up_issues_count, count(distinct taggings.tag_id) as num_issues
      FROM taggings,endorsements, users
      where taggings.taggable_id = endorsements.priority_id
      and taggings.taggable_type = 'Priority'
      and endorsements.user_id = users.id
      and endorsements.value > 0
      and endorsements.status = 'active'
      and (users.loggedin_at > '#{Time.now-2.hours}' or users.created_at > '#{Time.now-2.hours}')
      group by endorsements.user_id, users.id, users.up_issues_count")
      for u in users
        User.update_all("up_issues_count = #{u.num_issues}", "id = #{u.id}") unless u.up_issues_count == u.num_issues        
      end
      # update the # of issues they've DOWN endorsed
      users = User.find_by_sql("SELECT users.id, users.down_issues_count, count(distinct taggings.tag_id) as num_issues
      FROM taggings,endorsements, users
      where taggings.taggable_id = endorsements.priority_id
      and taggings.taggable_type = 'Priority'
      and endorsements.user_id = users.id
      and endorsements.value < 0
      and endorsements.status = 'active'
      and (users.loggedin_at > '#{Time.now-2.hours}' or users.created_at > '#{Time.now-2.hours}')
      group by endorsements.user_id, users.id, users.down_issues_count")
      for u in users
        User.update_all("down_issues_count = #{u.num_issues}", "id = #{u.id}") unless u.down_issues_count == u.num_issues
      end
    end

    # update the user's vote factor score
    users = User.active.all
    for u in users
      new_score = u.calculate_score
      if (u.score*100).to_i != (new_score*100).to_i
        u.update_attribute(:score,new_score) 
        for e in u.endorsements.active # their score changed, so now update all their endorsement scores
          current_score = e.score
          new_score = e.calculate_score
          e.update_attribute(:score, new_score) if new_score != current_score
        end
      end
    end

    # ranks all the branch endorsements, if the government uses branches
    if Government.current.is_branches?

      Government.current.update_user_default_branch
      # make sure the scores for all the positions above the max position are set to 0
      Endorsement.update_all("score = 0", "position > #{Endorsement.max_position}")
      for branch in Branch.all
        # get the last version # for the different time lengths
        v = branch.endorsement_rankings.find(:all, :select => "max(version) as version")[0]
        if v
          v = v.version || 0
          v+=1
        else
          v = 1
        end
        oldest = branch.endorsement_rankings.find(:all, :select => "max(version) as version")[0].version
        v_1hr = oldest
        v_24hr = oldest
        r = branch.endorsement_rankings.find(:all, :select => "max(version) as version", :conditions => "branch_endorsement_rankings.created_at < '#{Time.now-1.hour}'")[0]
        v_1hr = r.version if r
        r = branch.endorsement_rankings.find(:all, :select => "max(version) as version", :conditions => "branch_endorsement_rankings.created_at < '#{Time.now-1.hour}'")[0]
        v_24hr = r.version if r

        endorsement_scores = Endorsement.active.find(:all, 
          :select => "endorsements.priority_id, sum(endorsements.score) as number, count(*) as endorsements_number", 
          :joins => "endorsements INNER JOIN priorities ON priorities.id = endorsements.priority_id", 
          :conditions => ["endorsements.user_id in (?)",branch.user_ids], 
          :group => "endorsements.priority_id",       
          :order => "number desc")
        i = 0
        for e in endorsement_scores
          p = branch.endorsements.find_or_create_by_priority_id(e.priority_id.to_i)
          p.endorsements_count = e.endorsements_number.to_i
          p.update_counts if p.endorsements_count != p.up_endorsements_count+p.down_endorsements_count
          p.score = e.number.to_i
          first_time = false
          i = i + 1
          p.position = i

          r = p.rankings.find_by_version(v_1hr)
          if r # it's in that version
            p.position_1hr = r.position
          else # not in that version, find the oldest one we can
            r = p.rankings.find(:all, :conditions => ["version < ?",v_1hr],:order => "version asc", :limit => 1)[0]
            if r
              p.position_1hr = r.position
            else # this is the first time they've been ranked
              p.position_1hr = p.position
              first_time = true
            end
          end

          p.position_1hr_change = p.position_1hr - i 
          r = p.rankings.find_by_version(v_24hr)
          if r # in that version
            p.position_24hr = r.position
            p.position_24hr_change = p.position_24hr - i          
          else # didn't exist yet, so let's find the oldest one we can
            r = p.rankings.find(:all, :conditions => ["version < ?",v_24hr],:order => "version asc", :limit => 1)[0]
            p.position_24hr = 0
            p.position_24hr_change = 0
          end   

          date = Time.now-5.hours-7.days
          c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
          if c
            p.position_7days = c.position
            p.position_7days_change = p.position_7days - i   
          else
            p.position_7days = 0
            p.position_7days_change = 0
          end      

          date = Time.now-5.hours-30.days
          c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
          if c
            p.position_30days = c.position
            p.position_30days_change = p.position_30days - i   
          else
            p.position_30days = 0
            p.position_30days_change = 0
          end      
          
          p.save(false)
          r = BranchEndorsementRanking.create(:version => v, :branch_endorsement => p, :position => i, :endorsements_count => p.endorsements_count)
        end

        # check if there's a new fastest rising priority for this branch
        #rising = BranchEndorsement.rising.all[0]
        #ActivityPriorityRising1.find_or_create_by_priority_id(rising.id) if rising
      end
      BranchEndorsement.connection.execute("delete from branch_endorsements where endorsements_count = 0;")      

      # adjusts the boost factor for branches with less users, so it's equivalent to the largest branch
      branches = Branch.all
      max_users = branches.collect{|b| b.users_count}.sort.last
      for branch in branches
        if branch.users_count == 0
          rank_factor = 0 
        else
          rank_factor = max_users.to_f / branch.users_count.to_f
        end
        branch.update_attribute(:rank_factor, rank_factor) if branch.rank_factor != rank_factor
      end
      
    end

    # ranks all the priorities in the database with any endorsements.

    # make sure the scores for all the positions above the max position are set to 0
    Endorsement.update_all("score = 0", "position > #{Endorsement.max_position}")      
    # get the last version # for the different time lengths
    v = Ranking.find(:all, :select => "max(version) as version")[0]
    if v
     v = v.version || 0
     v+=1
    else
     v = 1
    end
    oldest = Ranking.find(:all, :select => "max(version) as version")[0].version
    v_1hr = oldest
    v_24hr = oldest
    r = Ranking.find(:all, :select => "max(version) as version", :conditions => "created_at < '#{Time.now-1.hour}'")[0]
    v_1hr = r.version if r
    r = Ranking.find(:all, :select => "max(version) as version", :conditions => "created_at < '#{Time.now-1.hour}'")[0]
    v_24hr = r.version if r

    if Government.current.is_branches?
      priorities = Priority.find_by_sql("
         select priorities.id, priorities.endorsements_count, priorities.up_endorsements_count, priorities.down_endorsements_count, branch_endorsements.priority_id, sum(branches.rank_factor*branch_endorsements.score) as number 
         from priorities, branch_endorsements, branches
         where branch_endorsements.branch_id = branches.id and branch_endorsements.priority_id = priorities.id
         and priorities.status = 'published'
         group by priorities.id, priorities.endorsements_count,  priorities.up_endorsements_count, priorities.down_endorsements_count, branch_endorsements.priority_id
         order by number desc")
    else
      priorities = Priority.find_by_sql("
         select priorities.id, priorities.endorsements_count, priorities.up_endorsements_count, priorities.down_endorsements_count, sum(((#{Endorsement.max_position+1}-endorsements.position)*endorsements.value)*users.score) as number
         from users,endorsements,priorities
         where endorsements.user_id = users.id
         and endorsements.priority_id = priorities.id
         and priorities.status = 'published'
         and endorsements.status = 'active' and endorsements.position <= #{Endorsement.max_position}
         group by priorities.id, priorities.endorsements_count, priorities.up_endorsements_count, priorities.down_endorsements_count, endorsements.priority_id
         order by number desc")
    end

    i = 0
    for p in priorities
     p.score = p.number
     first_time = false
     i = i + 1
     p.position = i

     r = p.rankings.find_by_version(v_1hr)
     if r # it's in that version
       p.position_1hr = r.position
     else # not in that version, find the oldest one we can
       r = p.rankings.find(:all, :conditions => ["version < ?",v_1hr],:order => "version asc", :limit => 1)[0]
       if r
         p.position_1hr = r.position
       else # this is the first time they've been ranked
         p.position_1hr = p.position
         first_time = true
       end
     end

     p.position_1hr_change = p.position_1hr - i 
     r = p.rankings.find_by_version(v_24hr)
     if r # in that version
       p.position_24hr = r.position
       p.position_24hr_change = p.position_24hr - i          
     else # didn't exist yet, so let's find the oldest one we can
       r = p.rankings.find(:all, :conditions => ["version < ?",v_24hr],:order => "version asc", :limit => 1)[0]
       p.position_24hr = 0
       p.position_24hr_change = 0
     end   
 
     date = Time.now-5.hours-7.days
     c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
     if c
       p.position_7days = c.position
       p.position_7days_change = p.position_7days - i   
     else
       p.position_7days = 0
       p.position_7days_change = 0
     end      

     date = Time.now-5.hours-30.days
     c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
     if c
       p.position_30days = c.position
       p.position_30days_change = p.position_30days - i   
     else
       p.position_30days = 0
       p.position_30days_change = 0
     end      
     
     p.trending_score = p.position_7days_change/p.position
     if p.down_endorsements_count == 0
       p.is_controversial = false
       p.controversial_score = 0
     else
       con = p.up_endorsements_count/p.down_endorsements_count
       if con > 0.5 and con < 2
         p.is_controversial = true
       else
         p.is_controversial = false
       end
       p.controversial_score = p.endorsements_count - (p.endorsements_count-p.down_endorsements_count).abs
     end
     Priority.update_all("position = #{p.position}, trending_score = #{p.trending_score}, is_controversial = #{p.is_controversial}, controversial_score = #{p.controversial_score}, score = #{p.score}, position_1hr = #{p.position_1hr}, position_1hr_change = #{p.position_1hr_change}, position_24hr = #{p.position_24hr}, position_24hr_change = #{p.position_24hr_change}, position_7days = #{p.position_7days}, position_7days_change = #{p.position_7days_change}, position_30days = #{p.position_30days}, position_30days_change = #{p.position_30days_change}", ["id = ?",p.id])
     r = Ranking.create(:version => v, :priority => p, :position => i, :endorsements_count => p.endorsements_count)
    end
    Priority.connection.execute("update priorities set position = 0, trending_score = 0, is_controversial = false, controversial_score = 0, score = 0 where endorsements_count = 0;")

    # check if there's a new fastest rising priority
    rising = Priority.published.rising.all[0]
    ActivityPriorityRising1.find_or_create_by_priority_id(rising.id) if rising

   
    # determines any changes in the #1 priority for an issue, and updates the # of distinct endorsers and opposers across the entire issue
    
    if Government.current.is_tags? and Tag.count > 0
      keep = []
      # get the number of endorsers on the issue
      tags = Tag.find_by_sql("SELECT tags.id, tags.name, tags.top_priority_id, tags.controversial_priority_id, tags.rising_priority_id, tags.obama_priority_id, count(distinct endorsements.user_id) as num_endorsers
      FROM tags,taggings,endorsements
      where 
      taggings.taggable_id = endorsements.priority_id
      and taggable_type = 'Priority'
      and taggings.tag_id = tags.id
      and endorsements.status = 'active'
      and endorsements.value > 0
      group by tags.id, tags.name, tags.top_priority_id, tags.controversial_priority_id, tags.rising_priority_id, tags.obama_priority_id, taggings.tag_id")
      for tag in tags
       keep << tag.id
       priorities = tag.priorities.published.top_rank # figure out the top priority while we're at it
       if priorities.any?
         if tag.top_priority_id != priorities[0].id # new top priority
           ActivityIssuePriority1.create(:tag => tag, :priority_id => priorities[0].id)
           tag.top_priority_id = priorities[0].id
         end
         controversial = tag.priorities.published.controversial
         if controversial.any? and tag.controversial_priority_id != controversial[0].id
           ActivityIssuePriorityControversial1.create(:tag => tag, :priority_id => controversial[0].id)
           tag.controversial_priority_id = controversial[0].id
         elsif controversial.empty?
           tag.controversial_priority_id = nil
         end
         rising = tag.priorities.published.rising
         if rising.any? and tag.rising_priority_id != rising[0].id
           ActivityIssuePriorityRising1.create(:tag => tag, :priority_id => rising[0].id)
           tag.rising_priority_id = rising[0].id
         elsif rising.empty?
           tag.rising_priority_id = nil
         end 
         obama = tag.priorities.published.obama_endorsed
         if obama.any? and tag.obama_priority_id != obama[0].id
           ActivityIssuePriorityObama1.create(:tag => tag, :priority_id => obama[0].id)
           tag.obama_priority_id = obama[0].id
         elsif obama.empty?
           tag.obama_priority_id = nil
         end
       else
         tag.top_priority_id = nil
         tag.controversial_priority_id = nil
         tag.rising_priority_id = nil
         tag.obama_priority_id = nil
       end
       tag.up_endorsers_count = tag.num_endorsers
       tag.save(false)
      end
      # get the number of opposers on the issue
      tags = Tag.find_by_sql("SELECT tags.id, tags.name, tags.down_endorsers_count, count(distinct endorsements.user_id) as num_opposers
      FROM tags,taggings,endorsements
      where 
      taggings.taggable_id = endorsements.priority_id
      and taggable_type = 'Priority'
      and taggings.tag_id = tags.id
      and endorsements.status = 'active'
      and endorsements.value < 0
      group by tags.id, tags.name, tags.down_endorsers_count, taggings.tag_id")    
      for tag in tags
       keep << tag.id
       tag.update_attribute(:down_endorsers_count,tag.num_opposers) unless tag.down_endorsers_count == tag.num_opposers
      end
      if keep.any?
       Tag.connection.execute("update tags set up_endorsers_count = 0, down_endorsers_count = 0 where id not in (#{keep.uniq.compact.join(',')})")
      end
    end
    
    # now, check to see if the charts have been updated in the last day
    
    date = Time.now-4.hours-1.day
    previous_date = date-1.day
    start_date = date.year.to_s + "-" + date.month.to_s + "-" + date.day.to_s
    end_date = (date+1.day).year.to_s + "-" + (date+1.day).month.to_s + "-" + (date+1.day).day.to_s
    
    if Government.current.is_branches?
      if BranchEndorsementChart.count(:conditions => ["date_year = ? and date_month = ? and date_day = ?", date.year, date.month, date.day]) == 0  # check to see if it's already been done for yesterday
        for branch in Branch.all
          priorities = BranchEndorsement.all
          for p in priorities
            # find the ranking
            r = p.rankings.find(:all, :conditions => ["branch_endorsement_rankings.created_at between ? and ?",start_date,end_date], :order => "created_at desc",:limit => 1)
            if r.any?
              c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
              if not c
                c = p.charts.new(:date_year => date.year, :date_month => date.month, :date_day => date.day)
              end
              c.position = r[0].position
              previous = p.charts.find_by_date_year_and_date_month_and_date_day(previous_date.year,previous_date.month,previous_date.day) 
              if previous
                c.change = previous.position-c.position
                c.change_percent = (c.change.to_f/previous.position.to_f)          
              end
              c.save
            end
            Rails.cache.delete('views/priority_chart-' + p.id.to_s)      
          end
          Rails.cache.delete('views/total_volume_chart') # reset the daily volume chart
        end
      end
    end
    
    if PriorityChart.count(:conditions => ["date_year = ? and date_month = ? and date_day = ?", date.year, date.month, date.day]) == 0  # check to see if it's already been done for yesterday
      
      priorities = Priority.published.find(:all)
      for p in priorities
        # find the ranking
        r = p.rankings.find(:all, :conditions => ["rankings.created_at between ? and ?",start_date,end_date], :order => "created_at desc",:limit => 1)
        if r.any?
          c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
          if not c
            c = PriorityChart.new(:priority => p, :date_year => date.year, :date_month => date.month, :date_day => date.day)
          end
          c.position = r[0].position
          c.up_count = p.endorsements.active.endorsing.count(:conditions => ["endorsements.created_at between ? and ?",start_date,end_date])
          c.down_count = p.endorsements.active.opposing.count(:conditions => ["endorsements.created_at between ? and ?",start_date,end_date])
          c.volume_count = c.up_count + c.down_count
          previous = p.charts.find_by_date_year_and_date_month_and_date_day(previous_date.year,previous_date.month,previous_date.day) 
          if previous
            c.change = previous.position-c.position
            c.change_percent = (c.change.to_f/previous.position.to_f)          
          end
          c.save
          if p.created_at+2.days > Time.now # within last two days, check to see if we've given them their priroity debut activity
            ActivityPriorityDebut.create(:user => p.user, :priority => p, :position => p.position) unless ActivityPriorityDebut.find_by_priority_id(p.id)
          end        
        end
        Rails.cache.delete('views/priority_chart-' + p.id.to_s)      
      end
      Rails.cache.delete('views/total_volume_chart') # reset the daily volume chart
      for u in User.active.at_least_one_endorsement.all
        u.index_24hr_change = u.index_change_percent(2)
        u.index_7days_change = u.index_change_percent(7)
        u.index_30days_change = u.index_change_percent(30)
        u.save(false)
        u.expire_charts
      end
       
    end
    
    Delayed::Job.enqueue PriorityRanker.new, -1, 47.minutes.from_now
    
  end
 
end