module Pajama
  class Client

    def initialize(path)
      @store = YAML.load(File.read(path)).pajama_deep_freeze
    end

    def configure_trello!
      ::Trello.configure do |config|
        config.developer_public_key = @store['trello']['developer_public_key']
        config.consumer_secret = @store['trello']['consumer_secret']
        config.member_token = @store['trello']['member_token']
      end
      if ::Trello.configuration.member_token.nil?
        puts "Get a member_token and update config.yml"
        puts "https://trello.com/1/authorize?key=%s&response_type=token&scope=read" % [::Trello.configuration.developer_public_key]
        exit 1
      end
    end

    def board
      ::Trello::Board.find @store['board']
    end

    def name_for_list_id(list_id)
      @store['lists'][list_id]
    end

    def list_id_for_name(list_name)
      @list_ids_for_name ||= @store['lists'].invert
      @list_ids_for_name[list_name]
    end

    def work_begins_in_list_name
      @store['work_begins_in_list']
    end

    def work_ends_in_list_name
      @store['work_ends_in_list']
    end

    def completed_work_list_name
      @store['completed_work_list']
    end

    def task_weights
      @store['task_weights']
    end

    def work_begins_in_list_id
      list_id_for_name(work_begins_in_list_name)
    end

    def work_ends_in_list_id
      list_id_for_name(work_ends_in_list_name)
    end

    def completed_work_list_id
      list_id_for_name(completed_work_list_name)
    end

    def completed_work_list
      List.new(self, completed_work_list_id)
    end

    def in_progress_work_lists
      @store['in_progress_work_lists'].map { |name| List.new(self, list_id_for_name(name)) }
    end

    def expected_transition?(source_list_id, target_list_id)
      transitions[source_list_id || :BEGIN].include?(target_list_id || :END)
    end

  private

    def transitions
      @transitions ||= Hash.new([]).tap do |t|
        @store['transitions'].each do |src_name, dst_name_list|
          src_id = (src_name == 'BEGIN') ? :BEGIN : list_id_for_name(src_name)
          t[src_id] = dst_name_list.map do |name|
            (name == 'END') ? :END : list_id_for_name(name)
          end
        end
      end
    end

    # def holidays
    #   @store['holidays'].map { |s| Date.strptime('%Y-%m-%d', s) }
    # end
    #
    # def vacation_for_username(username)
    #   if list = @store['vacation'][username]
    #     list.map do |s|
    #       if s =~ /^(\d\d\d\d-\d\d-\d\d) to (\d\d\d\d-\d\d-\d\d)$/
    #         [ Date.strptime('%Y-%m-%d', $1), Date.strptime('%Y-%m-%d', $2) ]
    #       elsif s =~ /^(\d\d\d\d-\d\d-\d\d)$/
    #         d = Date.strptime('%Y-%m-%d', s)
    #         [ d, d ]
    #       else
    #         raise "Cannot parse '#{s}' as Date"
    #       end
    #     end
    #   end
    # end

  end
end
