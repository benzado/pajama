module Pajama
  class Velocities
    def self.combined_size(tasks, weights)
      tasks.map { |size, count| weights[size] * count }.reduce(:+)
    end

    def initialize(db, weights, owner)
      @owner = owner
      @list = db.completed_cards_for(owner).map do |tasks, range|
        card_size = Velocities.combined_size(tasks, weights)
        duration = (range.end - range.begin + 1).to_f
        card_size / duration
      end
    end

    def sample
      @list.sample
    end

    def to_s
      "#{@owner}: " + @list.map { |v| '%.2f' % v }.join(', ')
    end
  end
end
