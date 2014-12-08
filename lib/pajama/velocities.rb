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
      @list.sort!
      @list.freeze
    end

    def sample
      @list.sample
    end

    def min
      @list.first
    end

    def max
      @list.last
    end

    def q1
      @list[@list.length / 4]
    end

    def median
      @list[@list.length / 2]
    end

    def q3
      @list[@list.length * 3 / 4]
    end

    def count
      @list.length
    end

    def to_s
      "#{@owner}: " + @list.map { |v| '%.2f' % v }.join(', ')
    end
  end
end
