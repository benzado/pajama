module Pajama
  class Action
    def initialize(client, trello_action)
      @client = client
      @trello_action = trello_action
      case trello_action.type
      when 'createCard', 'copyCard', 'moveCardToBoard'
        @target = trello_action.data['list']
      when 'updateCard'
        @source = trello_action.data['listBefore']
        @target = trello_action.data['listAfter']
      else
        p trello_action.data
        raise "I don't know what to do with #{trello_action.type}"
      end
    end

    def date
      @trello_action.date
    end

    def type
      @trello_action.type
    end

    def source_id
      @source['id'] if @source
    end

    def target_id
      @target['id'] if @target
    end

    def source_name
      if @source
        @client.name_for_list_id(source_id) || @source['name'] || @source['id']
      end
    end

    def target_name
      if @target
        @client.name_for_list_id(target_id) || @target['name'] || @target['id']
      end
    end

    def expected?
      @client.expected_transition?(source_id, target_id)
    end

    def unexpected?
      !expected?
    end

    def followed_by?(other)
      (self.date < other.date) && (self.target_id == other.source_id)
    end

    def <=>(other)
      self.date <=> other.date
    end

    def to_s
      flag = expected? ? '' : '*'
      sprintf '%s %1s %-24s -> %-24s', date, flag, source_name, target_name
    end
  end
end
