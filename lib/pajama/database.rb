module Pajama
  class DatabaseError < StandardError
  end

  class Database
    DATETIME_PATTERN = %r{^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$}
    URL_PATTERN = %r{^http(s?)://.+$}

    def initialize(path)
      @sqlite = SQLite3::Database.new(path.to_s)
      @sqlite.define_function('ISDATETIME') do |string|
        (DATETIME_PATTERN === string) ? 1 : 0
      end
      @sqlite.define_function('ISURL') do |string|
        (URL_PATTERN === string) ? 1 : 0
      end
      @sqlite.execute %Q[
        CREATE TABLE IF NOT EXISTS cards (
          uuid           TEXT  NOT NULL PRIMARY KEY,
          title          TEXT  NOT NULL CHECK (LENGTH(title) > 0),
          owner          TEXT  NOT NULL CHECK (LENGTH(owner) > 0),
          url            TEXT  NOT NULL CHECK (ISURL(url)),
          task_count_S   INT   NOT NULL CHECK (task_count_S >= 0) DEFAULT 0,
          task_count_M   INT   NOT NULL CHECK (task_count_M >= 0) DEFAULT 0,
          task_count_L   INT   NOT NULL CHECK (task_count_L >= 0) DEFAULT 0,
          is_complete    INT   NOT NULL CHECK (is_complete IN (0, 1)),
          work_duration  REAL,
          work_began,
          work_ended,
          CHECK ((task_count_S + task_count_M + task_count_L) > 0),
          CHECK ((is_complete = 0) OR (
            ISDATETIME(work_began) AND
            ISDATETIME(work_ended) AND
            (work_began < work_ended) AND
            (work_duration > 0)
          ))
        )
      ]
    end

    def insert_card(card_hash, is_complete)
      @insert_completed_card_query ||= @sqlite.prepare(%Q[
        INSERT OR REPLACE INTO cards VALUES (
          :uuid,
          :title,
          :owner,
          :url,
          :task_count_S,
          :task_count_M,
          :task_count_L,
          :is_complete,
          :work_duration,
          :work_began,
          :work_ended
        )
      ])
      if card_hash['work_began']
        work_began = card_hash['work_began'].strftime('%Y-%m-%d %H:%M:%S')
      end
      if card_hash['work_ended']
        work_ended = card_hash['work_ended'].strftime('%Y-%m-%d %H:%M:%S')
      end
      @insert_completed_card_query.execute(
        uuid:          card_hash['uuid'],
        title:         card_hash['title'],
        owner:         card_hash['owner'],
        url:           card_hash['url'],
        task_count_S:  card_hash['tasks']['S'],
        task_count_M:  card_hash['tasks']['M'],
        task_count_L:  card_hash['tasks']['L'],
        is_complete:   is_complete ? 1 : 0,
        work_duration: card_hash['work_duration'],
        work_began:    work_began,
        work_ended:    work_ended,
      )
    rescue SQLite3::ConstraintException
      raise DatabaseError, "insert_card: #{card_hash.inspect}"
    rescue NoMethodError
      raise DatabaseError, "insert_card: #{card_hash.inspect}"
    end

    def each_owner
      query = %Q[SELECT owner FROM cards GROUP BY owner ORDER BY owner]
      @sqlite.execute(query) do |row|
        yield row.first
      end
    end

    def at_work_ratio_for(owner, cutoff_date)
      query = %Q[
        SELECT
          MIN(work_began),
          MAX(work_ended),
          SUM(work_duration)
        FROM cards
        WHERE
          is_complete = 1 AND owner = :owner AND work_began >= :cutoff
      ]
      cutoff = cutoff_date.strftime('%Y-%m-%d')
      at_work_ratio = 0
      @sqlite.execute(query, owner: owner, cutoff: cutoff) do |row|
        work_began = DateTime.parse(row[0])
        work_ended = DateTime.parse(row[1])
        work_duration = row[2]
        at_work_ratio = work_duration / ((work_ended - work_began) * 24.0)
      end
      return at_work_ratio
    end

    def completed_cards_for(owner, cutoff_date)
      query = %Q[
        SELECT
          task_count_S,
          task_count_M,
          task_count_L,
          work_duration
        FROM cards
        WHERE
          is_complete = 1 AND owner = :owner AND work_began >= :cutoff
      ]
      cutoff = cutoff_date.strftime('%Y-%m-%d')
      list = Array.new
      @sqlite.execute(query, owner: owner, cutoff: cutoff) do |row|
        tasks = { 'S' => row[0], 'M' => row[1], 'L' => row[2] }
        work_duration = row[3]
        list << [tasks, work_duration]
      end
      return list
    end

    def in_progress_cards_for(owner)
      query = %Q[
        SELECT
          uuid,
          title,
          url,
          task_count_S,
          task_count_M,
          task_count_L,
          work_duration
        FROM cards
        WHERE
          is_complete = 0 AND owner = :owner
      ]
      @sqlite.execute(query, owner: owner) do |row|
        info = {
          'uuid' => row[0],
          'title' => row[1],
          'url' => row[2],
        }
        tasks = { 'S' => row[3], 'M' => row[4], 'L' => row[5] }
        work_duration = row[6]
        yield info, tasks, work_duration
      end
    end

    def print_stats(out)
      averages_query = %Q{
        SELECT
          owner,
          CASE is_complete WHEN 0 THEN 'inc' ELSE 'com' END,
          COUNT(*),
          AVG(task_count_S),
          AVG(task_count_M),
          AVG(task_count_L),
          AVG(work_duration)
        FROM cards
        GROUP BY is_complete, owner
        ORDER BY is_complete, owner
      }
      averages_format = {
        'owner'.ljust(13) => '%-13s',
        ' ? ' => '%3s',
        '  N' => '%3d',
        ' mS' => '%3.1f',
        ' mM' => '%3.1f',
        ' mL' => '%3.1f',
        ' mD' => '%3.0f',
      }
      out.puts
      out.puts 'AVERAGES'
      out.puts
      print_table(out, averages_query, averages_format)

      completed_query = %Q{
        SELECT
          owner,
          MIN(work_began),
          MAX(work_ended),
          SUM(work_duration)
        FROM cards
        WHERE is_complete = 1
        GROUP BY owner
        ORDER BY owner
      }
      completed_format = {
        'owner'.ljust(13) => '%-13s',
        'earliest began'.ljust(19) => '%19s',
        'latest ended'.ljust(19) => '%19s',
        ' sD' => '%3.0f',
        'hours' => '%5.0f',
        'work%' => '%5.1f',
      }
      out.puts
      out.puts 'COMPLETED WORK'
      out.puts
      print_table(out, completed_query, completed_format) do |row|
        earliest_began = DateTime.parse(row[1])
        latest_ended = DateTime.parse(row[2])
        sum_duration = row[3]
        total_hours = 24.0 * (latest_ended - earliest_began)
        accounted_time = 100.0 * sum_duration / total_hours
        row + [total_hours, accounted_time]
      end
      out.puts
    end

    def print_table(out, query, format)
      row_format = format.values.join(' ') + "\n"
      out.puts format.keys.join(' ')
      out.puts format.keys.map{ |t| '-' * t.length }.join(' ')
      @sqlite.execute(query) do |row|
        if block_given?
          row = yield(row)
        end
        out.printf row_format, *row
      end
    end
  end
end
