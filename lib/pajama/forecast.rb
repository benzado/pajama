module Pajama
  class Forecast
    include Term::ANSIColor

    def initialize(db, task_weights)
      @db = db
      @task_weights = task_weights
      @now = DateTime.now
      @owners = Array.new
      @ship_date_counts = Hash.new { |h,k| h[k] = Hash.new(0) }
    end

    def simulate
      @db.each_owner do |owner|
        $stderr.print green("Simulating #{owner}")

        @owners << owner
        v = Velocities.new(@db, @task_weights, owner)

        100.times do
          $stderr.print '.'

          total_duration = 0

          @db.in_progress_cards_for(owner) do |info, tasks, work_began|
            size = Velocities.combined_size(tasks, @task_weights)
            predicted_duration = size.fdiv(v.sample)
            if work_began
              adjustment = (@now - work_began).to_f
              if predicted_duration > adjustment
                predicted_duration -= adjustment
              end
            end
            total_duration += predicted_duration
          end

          completion_date = (@now + total_duration).to_date

          @ship_date_counts[completion_date][owner] += 1
        end
        $stderr.puts "Done"
      end
    end

    def write(output)
      output.puts "Date\t" + @owners.join("\t")
      probability_by_owner = Hash.new(0)
      @ship_date_counts.keys.sort.each do |date|
        @owners.each do |owner|
          probability_by_owner[owner] += @ship_date_counts[date][owner]
        end
        row = [date.strftime('%m/%d/%Y')]
        row.concat probability_by_owner.values_at(*@owners)
        output.puts row.join("\t")
      end
    end
  end
end
