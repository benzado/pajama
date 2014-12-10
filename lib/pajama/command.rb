module Pajama
  class Command < Thor
    include Term::ANSIColor

    desc 'fetch', 'Download card information into YAML files'
    option 'in-progress', type: :boolean, default: nil
    option 'completed',   type: :boolean, default: nil
    def fetch
      client = Client.new('pajama.yml')
      client.configure_trello!
      fetch_all = %w[in-progress completed].all? {|n| options[n].nil? }
      if fetch_all || options['in-progress']
        client.in_progress_work_lists.each do |list|
          fetch_cards(in_progress_cards_path, list.cards)
        end
      end
      if fetch_all || options['completed']
        fetch_cards(completed_cards_path, client.completed_work_list.cards)
      end
    end

    desc 'import', 'Import card information into database'
    def import
      db = Database.new(database_path)
      @import_count = 0
      @import_error_count = 0
      import_cards(db, in_progress_cards_path, false)
      import_cards(db, completed_cards_path, true)
      $stderr.puts "#{@import_count} cards imported."
      $stderr.puts "#{@import_error_count} cards failed."
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
      forecast = Forecast.new(db, client.task_weights)
      forecast.simulate
      cut_line = begin
        terminal_width = 80
        dash_count = (terminal_width - 8) / 4
        ('- ' * dash_count) + 'CUT HERE' + (' -' * dash_count)
      end
      $stderr.puts yellow(cut_line)
      forecast.write($stdout)
      $stderr.puts yellow(cut_line)
    end

    desc 'velocities', 'Velocity statistics'
    def velocities
      db = Database.new(database_path)
      task_weights = Client.new('pajama.yml').task_weights
      puts %w[
        Owner
        Min
        Q1
        Q3
        Max
        Median
        Count
        AtWork
      ].join("\t")
      db.each_owner do |owner|
        velocities = Velocities.new(db, task_weights, owner)
        row = [
          owner,
          velocities.min,
          velocities.q1,
          velocities.q3,
          velocities.max,
          velocities.median,
          velocities.count,
          velocities.at_work_ratio
        ]
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
          @import_count += 1
        rescue DatabaseError => e
          $stderr.puts red(e.message)
          @import_error_count += 1
        end
      end
    end
  end
end
