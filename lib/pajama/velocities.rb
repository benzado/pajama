module Pajama
  class Velocities
    def self.combined_size(tasks, weights)
      tasks.map { |size, count| weights[size] * count }.reduce(:+)
    end

    def initialize(db, weights, owner)
      @owner = owner
      cutoff_date = Date.today - 90
      @at_work_ratio = db.at_work_ratio_for(owner, cutoff_date)
      @list = db.completed_cards_for(owner, cutoff_date).map do |tasks, work_duration|
        card_size = Velocities.combined_size(tasks, weights)
        card_size / work_duration
      end
      @list.sort!
      @list.freeze
    end

    def at_work_ratio
      @at_work_ratio
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
