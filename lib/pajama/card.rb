module Pajama
  class Card
    SECONDS_PER_HOUR = 3600

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
    rescue NoMethodError
      nil
    end

    def actions
      @actions ||= begin
        @trello_card.actions(ACTION_QUERY_OPTIONS).map { |ta|
          Action.new(@client, ta)
        }.sort
      end
    end

    def work_began_date
      list_name = @client.active_work_list_name
      action = actions.find { |a| a.target_name == list_name }
      action.date if action
    end

    def work_ended_date
      list_name = @client.active_work_list_name
      action = actions.reverse_each.find { |a| a.source_name == list_name }
      action.date if action
    end

    def work_duration
      list_name = @client.active_work_list_name
      actions.each_cons(2).reduce(0) do |hours_worked, consecutive_actions|
        first_action, second_action = consecutive_actions
        if first_action.target_name == list_name
          if second_action.source_name == list_name
            duration_in_seconds = (second_action.date - first_action.date)
            hours_worked += duration_in_seconds.fdiv(SECONDS_PER_HOUR)
          else
            raise "incongruous actions!"
          end
        else
          hours_worked
        end
      end
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
        'tasks'         => tasks,
        'actions'       => actions.map(&:to_s),
        'work_began'    => work_began_date,
        'work_ended'    => work_ended_date,
        'work_duration' => work_duration,
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
