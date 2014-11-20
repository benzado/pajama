module Pajama
  class List
    CARD_QUERY_OPTIONS = {
      members: true,
      member_fields: 'username',
    }

    def initialize(client, list_id)
      @client = client
      @trello_list = ::Trello::List.find(list_id)
    end

    def cards
      @trello_list.cards(CARD_QUERY_OPTIONS).map { |tc| Card.new(@client, tc) }.reject { |c| c.skip? }
    end

    def id
      @trello_list.id
    end

    def name
      @trello_list.name
    end
  end
end
