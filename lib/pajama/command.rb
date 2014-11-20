module Pajama
  class Command < Thor
    include Term::ANSIColor

    desc 'fetch', 'Download card information into YAML files'
    def fetch
      client = Client.new('pajama.yml')
      client.configure_trello!
      client.in_progress_work_lists.each do |list|
        fetch_cards(in_progress_cards_path, list.cards)
      end
      fetch_cards(completed_cards_path, client.completed_work_list.cards)
    end

    desc 'import', 'Import card information into database'
    def import
      db = Database.new(database_path)
      import_cards(db, in_progress_cards_path, false)
      import_cards(db, completed_cards_path, true)
    end

    desc 'stats', 'Report basic database stats'
    def stats
      db = Database.new(database_path)
      db.print_stats($stdout)
    end

    desc 'forecast', 'Forecast using information in database'
    def forecast
      client = Client.new('pajama.yml')
      db = Database.new(database_path)
      now = DateTime.now

      owners = Array.new
      ship_date_probabilities = Hash.new { |h,k| h[k] = Hash.new(0) }

      db.each_owner do |owner|
        $stderr.print green("Simulating #{owner}")

        owners << owner
        v = Velocities.new(db, client.task_weights, owner)

        100.times do
          $stderr.print '.'

          total_duration = 0

          db.in_progress_cards_for(owner) do |info, tasks, work_began|
            size = Velocities.combined_size(tasks, client.task_weights)
            predicted_duration = size.fdiv(v.sample)
            if work_began
              adjustment = (now - work_began).to_f
              if predicted_duration > adjustment
                predicted_duration -= adjustment
              end
            end
            total_duration += predicted_duration
          end

          completion_date = (now + total_duration).strftime('%m/%d/%Y')

          ship_date_probabilities[completion_date][owner] += 1
        end
        $stderr.puts "Done"
      end

      puts "Date\t" + owners.join("\t")
      ship_date_probabilities.each do |date, counts|
        row = [date]
        row.concat owners.map {|owner| counts[owner]}
        puts row.join("\t")
      end
    end

  private

    def database_path
      @database_path ||= Pathname.new('pajama.db')
    end

    def in_progress_cards_path
      @in_progress_cards_path ||= Pathname.new('cards/in-progress')
    end

    def completed_cards_path
      @completed_cards_path ||= Pathname.new('cards/completed')
    end

    def fetch_cards(path, cards)
      path.mkpath
      cards.each do |card|
        card_path = path + "#{card.uuid}.yml"
        $stderr.puts "Card: #{card_path} (#{card.title})"
        card_path.open('w') do |f|
          YAML.dump(card.to_hash, f)
        end
      end
    end

    def import_cards(db, path, is_complete)
      Pathname.glob(path + '*.yml') do |card_path|
        $stderr.puts "Importing #{card_path}"
        begin
          card_hash = YAML.load_file(card_path)
          db.insert_card(card_hash, is_complete)
        rescue DatabaseError => e
          $stderr.puts red(e.message)
        end
      end
    end
  end
end
