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
          work_began                    CHECK ((is_complete = 0) OR ISDATETIME(work_began)),
          work_ended                    CHECK ((is_complete = 0) OR ISDATETIME(work_ended)),
          CHECK ((task_count_S + task_count_M + task_count_L) > 0),
          CHECK ((is_complete = 0) OR (work_began < work_ended))
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

    def completed_cards_for(owner)
      query = %Q[
        SELECT
          task_count_S, task_count_M, task_count_L,
          work_began, work_ended
        FROM cards
        WHERE
          is_complete = 1 AND owner = :owner
      ]
      list = Array.new
      @sqlite.execute(query, owner: owner) do |row|
        tasks = { 'S' => row[0], 'M' => row[1], 'L' => row[2] }
        range = Range.new(DateTime.parse(row[3]), DateTime.parse(row[4]))
        list << [tasks, range]
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
          work_began
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
        work_began = DateTime.parse(row[6]) unless row[6].nil?
        yield info, tasks, work_began
      end
    end

    def print_stats(out)
      statement = @sqlite.prepare(%Q[
        SELECT owner,
          COUNT(*)          AS n_cards,
          SUM(is_complete)  AS n_complete_cards,
          AVG(task_count_S) AS mean_S,
          AVG(task_count_M) AS mean_M,
          AVG(task_count_L) AS mean_L,
          MIN(work_began)   AS earliest_began,
          MAX(work_ended)   AS latest_end
        FROM cards
        GROUP BY owner
        ORDER BY owner
      ])
      statement.execute do |result|
        out.printf "%-14s %3s %3s %3s %3s %3s  %-19s  %-19s\n",
          'owner', 'N', 'Nc', 'mS', 'mM', 'mL', 'earliest began', 'latest end'
        result.each do |row|
          out.printf "%-14s %3d %3d %3.1f %3.1f %3.1f  %19s  %19s\n", *row
        end
      end
    end
  end
end
