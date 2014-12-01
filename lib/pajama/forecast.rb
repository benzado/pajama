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

          completion_date = (@now + total_duration).strftime('%m/%d/%Y')

          @ship_date_counts[completion_date][owner] += 1
        end
        $stderr.puts "Done"
      end
    end

    def write(output)
      output.puts "Date\t" + @owners.join("\t")
      @ship_date_counts.each do |date, counts|
        row = [date]
        @owners.each { |owner| row << counts[owner] }
        output.puts row.join("\t")
      end
    end
  end
end
