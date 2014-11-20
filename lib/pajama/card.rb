module Pajama
  class Card
    ACTION_QUERY_OPTIONS = {
      # filter: 'all',
      filter: %w[
        createCard
        copyCard
        moveCardToBoard
        updateCard:idList
      ].join(','),
      fields: 'data,type,date',
      limit: 900, # default: 50; valid: 0..1000
      member: false,
      memberCreator: false
    }

    def initialize(client, trello_card)
      @client = client
      @trello_card = trello_card
      @warnings = Array.new
    end

    def skip?
      @trello_card.name =~ /^README/
    end

    def uuid
      @trello_card.id
    end

    def url
      @trello_card.short_url
    end

    def title
      @trello_card.name
    end

    def owner
      @trello_card.card_members.first['username']
    end

    def actions
      @actions ||= @trello_card.actions(ACTION_QUERY_OPTIONS).map { |ta| Action.new(@client, ta) }.sort
    end

    # The first time the card entered the "In Development" list
    def work_began_date
      if a = actions.find { |a| a.target_id == @client.work_begins_in_list_id }
        a.date
      end
    end

    # The last time the card entered the "Deployed" list
    def work_ended_date
      if a = actions.reverse_each.find { |a| a.target_id == @client.work_ends_in_list_id }
        a.date
      end
    end

    def work_duration
      (work_ended_date.to_date - work_began_date.to_date + 1).to_i
    rescue
      nil
    end

    def tasks
      tasks = Hash.new(0)

      # Search card description
      find_task_estimates(tasks, @trello_card.desc)

      # Search checklists
      missing_count = 0
      @trello_card.checklists.each do |checklist|
        checklist.check_items.map { |item| item['name'] }.each do |name|
          find_task_estimates(tasks, name) or missing_count += 1
        end
      end
      if missing_count > 0
        @warnings << "#{missing_count} checklist items with no estimate"
      end

      if tasks.size == 0
        @warnings << "no task estimates found"
      end
      return tasks
    end

    def lint!
      unexpected_count = actions.count(&:unexpected?)
      if unexpected_count > 0
        @warnings << "#{unexpected_count} unexpected actions"
      end
      incongruous_count = actions.each_cons(2).count { |a,b| !a.followed_by?(b) }
      if incongruous_count > 0
        @warnings << "#{incongruous_count} incongruous actions"
      end
      @warnings.length > 0
    end

    def to_hash
      h = {
        'title'         => title,
        'uuid'          => uuid,
        'url'           => url,
        'owner'         => owner,
        'work_began'    => work_began_date,
        'work_ended'    => work_ended_date,
        'work_duration' => work_duration,
        'tasks'         => tasks,
        'actions'       => actions.map(&:to_s)
      }
      if lint!
        h['warnings'] = @warnings
      end
      return h
    end

  private

    ESTIMATE_PATTERNS = [ /\[([SML])\]/, /\(([SML])\)/ ]

    def find_task_estimates(tasks, text)
      estimates_found = false
      ESTIMATE_PATTERNS.each do |pattern|
        text.scan(pattern) do |match|
          tasks[match.first] += 1
          estimates_found = true
        end
      end
      return estimates_found
    end
  end
end
