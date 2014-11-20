require 'minitest/autorun'
require 'pajama'

describe "Database" do
  let(:db) { Pajama::Database.new(':memory:') }

  describe 'any card' do
    let(:card_hash_template) do
      {
        'uuid'          => '54133ef4bfe96c5ca8a49446',
        'title'         => 'Refill Honey Pot',
        'url'           => 'http://www.tired.com/',
        'owner'         => 'foobear',
        'tasks'         => { 'S' => 1, 'M' => 0, 'L' => 0 },
        'work_began'    => Time.utc(1986, 1, 2),
        'work_ended'    => Time.utc(1986, 1, 9),
      }
    end

    it 'accepts inserts' do
      card_hash = card_hash_template.dup
      db.insert_card card_hash, true
    end

    it 'fails if uuid is missing' do
      card_hash = card_hash_template.dup
      card_hash['uuid'] = nil
      assert_raises Pajama::DatabaseError do
        db.insert_card card_hash, true
      end
    end

    it 'fails if owner is missing' do
      card_hash = card_hash_template.dup
      card_hash['owner'] = nil
      assert_raises Pajama::DatabaseError do
        db.insert_card card_hash, true
      end
    end

    it 'fails if tasks sum is 0' do
      card_hash = card_hash_template.dup
      card_hash['tasks'] = { 'S' => 0, 'M' => 0, 'L' => 0 }
      assert_raises Pajama::DatabaseError do
        db.insert_card card_hash, true
      end
    end

    it 'fails if any tasks is negative' do
      card_hash = card_hash_template.dup
      card_hash['tasks'] = { 'L' => -1 }
      assert_raises Pajama::DatabaseError do
        db.insert_card card_hash, true
      end
    end
 end

  describe 'in-progress cards' do
    let(:card_hash_template) do
      {
        'uuid'          => '54133ef4bfe96c5ca8a49446',
        'title'         => 'Refill Honey Pot',
        'url'           => 'http://www.tired.com/',
        'owner'         => 'foobear',
        'tasks'         => { 'S' => 1, 'M' => 0, 'L' => 0 },
      }
    end

    it 'can be inserted' do
      card_hash = card_hash_template.dup
      db.insert_card card_hash, false
    end
  end

  describe 'completed cards' do
    let(:card_hash_template) do
      {
        'uuid'          => '54133ef4bfe96c5ca8a49446',
        'title'         => 'Refill Honey Pot',
        'url'           => 'http://www.tired.com/',
        'owner'         => 'foobear',
        'tasks'         => { 'S' => 1, 'M' => 0, 'L' => 0 },
        'work_began'    => Time.utc(1986, 1, 2),
        'work_ended'    => Time.utc(1986, 1, 9),
      }
    end

    it 'fails if work_began is not a date' do
      card_hash = card_hash_template.dup
      card_hash['work_began'] = 'bleep'
      assert_raises Pajama::DatabaseError do
        db.insert_card card_hash, true
      end
    end

    it 'fails if work_ended is not a date' do
      card_hash = card_hash_template.dup
      card_hash['work_ended'] = 'bloop'
      assert_raises Pajama::DatabaseError do
        db.insert_card card_hash, true
      end
    end

    it 'fails if work_ended is before work_began' do
      card_hash = card_hash_template.dup
      card_hash['work_began'] = Time.utc(1984, 1, 1, 0, 0, 1)
      card_hash['work_ended'] = Time.utc(1984, 1, 1, 0, 0, 0)
      assert_raises Pajama::DatabaseError do
        db.insert_card card_hash, true
      end
    end
  end
end
