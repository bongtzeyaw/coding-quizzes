require 'minitest/autorun'
require_relative 'my_answer'

class TestUserService < Minitest::Test
  def setup
    @user_service = UserService.new
  end

  def test_get_user_info_found
    mock_db = Minitest::Mock.new
    mock_db.expect(:execute, [{'id' => 1, 'name' => 'John Doe', 'email' => 'john@example.com'}], ['SELECT * FROM users WHERE id = 1'])
    mock_db.expect(:execute, [{'count' => 10}], ['SELECT COUNT(*) as count FROM posts WHERE user_id = 1'])
    mock_db.expect(:execute, [{'count' => 5}], ['SELECT COUNT(*) as count FROM follows WHERE followed_id = 1'])
    mock_db.expect(:execute, [{'count' => 3}], ['SELECT COUNT(*) as count FROM follows WHERE follower_id = 1'])
    mock_db.expect(:execute, [{'id' => 101, 'title' => 'Post 1'}], ['SELECT * FROM posts WHERE user_id = 1 ORDER BY created_at DESC LIMIT 5'])

    Database.stub :execute, ->(sql) { mock_db.execute(sql) } do
      user_info = @user_service.get_user_info(1)
      assert_equal 1, user_info[:id]
      assert_equal 'John Doe', user_info[:name]
      assert_equal 'john@example.com', user_info[:email]
      assert_equal 10, user_info[:posts_count]
      assert_equal 5, user_info[:followers_count]
      assert_equal 3, user_info[:following_count]
      assert_equal [{'id' => 101, 'title' => 'Post 1'}], user_info[:latest_posts]
    end
    mock_db.verify
  end

  def test_get_user_info_not_found
    mock_db = Minitest::Mock.new
    mock_db.expect(:execute, [], ['SELECT * FROM users WHERE id = 999'])

    Database.stub :execute, ->(sql) { mock_db.execute(sql) } do
      user_info = @user_service.get_user_info(999)
      assert_nil user_info
    end
    mock_db.verify
  end

  def test_search_users_with_keyword
    mock_db = Minitest::Mock.new
    mock_db.expect(:execute, [{'id' => 1, 'name' => 'John Doe', 'email' => 'john@example.com'}], ["SELECT * FROM users WHERE name LIKE '%john%' OR email LIKE '%john%' ORDER BY created_at DESC LIMIT 20 OFFSET 0"])
    mock_db.expect(:execute, [{'count' => 10}], ['SELECT COUNT(*) as count FROM posts WHERE user_id = 1'])

    Database.stub :execute, ->(sql) { mock_db.execute(sql) } do
      users = @user_service.search_users('john')
      assert_equal 1, users.length
      assert_equal 'John Doe', users[0][:name]
      assert_equal 10, users[0][:posts_count]
    end
    mock_db.verify
  end

  def test_search_users_no_keyword
    mock_db = Minitest::Mock.new
    mock_db.expect(:execute, [{'id' => 2, 'name' => 'Jane Smith', 'email' => 'jane@example.com'}], ["SELECT * FROM users ORDER BY created_at DESC LIMIT 20 OFFSET 0"])
    mock_db.expect(:execute, [{'count' => 7}], ['SELECT COUNT(*) as count FROM posts WHERE user_id = 2'])

    Database.stub :execute, ->(sql) { mock_db.execute(sql) } do
      users = @user_service.search_users(nil)
      assert_equal 1, users.length
      assert_equal 'Jane Smith', users[0][:name]
      assert_equal 7, users[0][:posts_count]
    end
    mock_db.verify
  end

  def test_search_users_pagination
    mock_db = Minitest::Mock.new
    mock_db.expect(:execute, [{'id' => 3, 'name' => 'Alice', 'email' => 'alice@example.com'}], ["SELECT * FROM users WHERE name LIKE '%a%' OR email LIKE '%a%' ORDER BY created_at DESC LIMIT 20 OFFSET 20"])
    mock_db.expect(:execute, [{'count' => 2}], ['SELECT COUNT(*) as count FROM posts WHERE user_id = 3'])

    Database.stub :execute, ->(sql) { mock_db.execute(sql) } do
      users = @user_service.search_users('a', 2)
      assert_equal 1, users.length
      assert_equal 'Alice', users[0][:name]
      assert_equal 2, users[0][:posts_count]
    end
    mock_db.verify
  end
end
