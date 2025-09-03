require 'minitest/autorun'
require_relative 'my_answer'

class TestUserService < Minitest::Test
  def setup
    @user_service = UserService.new
  end

  def test_get_user_info_found
    mock_db = Minitest::Mock.new
    mock_db.expect(:execute, [{'id' => 1, 'name' => 'John Doe', 'email' => 'john@example.com'}], ['SELECT * FROM users WHERE id = ?', [1]])
    mock_db.expect(:execute, [{'count' => 10}], ['SELECT COUNT(*) as count FROM posts WHERE user_id = ?', [1]])
    mock_db.expect(:execute, [{'count' => 5}], ['SELECT COUNT(*) as count FROM follows WHERE followed_id = ?', [1]])
    mock_db.expect(:execute, [{'count' => 3}], ['SELECT COUNT(*) as count FROM follows WHERE follower_id = ?', [1]])
    mock_db.expect(:execute, [{'id' => 101, 'title' => 'Post 1'}], ['SELECT * FROM posts WHERE user_id = ? ORDER BY created_at DESC LIMIT ?', [1, 5]])

    Database.stub :execute, ->(sql, params) { mock_db.execute(sql, params) } do
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
    mock_db.expect(:execute, [], ['SELECT * FROM users WHERE id = ?', [999]])

    Database.stub :execute, ->(sql, params) { mock_db.execute(sql, params) } do
      user_info = @user_service.get_user_info(999)
      assert_nil user_info
    end
    mock_db.verify
  end

  def test_search_users_with_keyword
    mock_db = Minitest::Mock.new
    mock_db.expect(:execute, [{'id' => 1, 'name' => 'John Doe', 'email' => 'john@example.com'}], ['SELECT * FROM users WHERE name LIKE ? OR email LIKE ? ORDER BY created_at DESC LIMIT ? OFFSET ?', ['%john%', '%john%', 20, 0]])
    mock_db.expect(:execute, [{'user_id' => 1, 'count' => 10}], ['SELECT user_id, COUNT(*) as count FROM posts WHERE user_id IN (?) GROUP BY user_id', [1]])

    Database.stub :execute, ->(sql, params) { mock_db.execute(sql, params) } do
      users = @user_service.search_users('john')
      assert_equal 1, users.length
      assert_equal 'John Doe', users[0][:name]
      assert_equal 10, users[0][:posts_count]
    end
    mock_db.verify
  end

  def test_search_users_no_keyword
    mock_db = Minitest::Mock.new
    mock_db.expect(:execute, [{'id' => 2, 'name' => 'Jane Smith', 'email' => 'jane@example.com'}], ['SELECT * FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?', [20, 0]])
    mock_db.expect(:execute, [{'user_id' => 2, 'count' => 7}], ['SELECT user_id, COUNT(*) as count FROM posts WHERE user_id IN (?) GROUP BY user_id', [2]])

    Database.stub :execute, ->(sql, params) { mock_db.execute(sql, params) } do
      users = @user_service.search_users(nil)
      assert_equal 1, users.length
      assert_equal 'Jane Smith', users[0][:name]
      assert_equal 7, users[0][:posts_count]
    end
    mock_db.verify
  end

  def test_search_users_pagination
    mock_db = Minitest::Mock.new
    mock_db.expect(:execute, [{'id' => 3, 'name' => 'Alice', 'email' => 'alice@example.com'}], ['SELECT * FROM users WHERE name LIKE ? OR email LIKE ? ORDER BY created_at DESC LIMIT ? OFFSET ?', ['%a%', '%a%', 20, 20]])
    mock_db.expect(:execute, [{'user_id' => 3, 'count' => 2}], ['SELECT user_id, COUNT(*) as count FROM posts WHERE user_id IN (?) GROUP BY user_id', [3]])

    Database.stub :execute, ->(sql, params) { mock_db.execute(sql, params) } do
      users = @user_service.search_users('a', 2)
      assert_equal 1, users.length
      assert_equal 'Alice', users[0][:name]
      assert_equal 2, users[0][:posts_count]
    end
    mock_db.verify
  end
  
  def test_search_users_multiple_results
    mock_db = Minitest::Mock.new
    mock_users_data = [
      {'id' => 1, 'name' => 'John Doe', 'email' => 'john@example.com'},
      {'id' => 2, 'name' => 'Jane Smith', 'email' => 'jane@example.com'},
    ]
    mock_db.expect(:execute, mock_users_data, ['SELECT * FROM users WHERE name LIKE ? OR email LIKE ? ORDER BY created_at DESC LIMIT ? OFFSET ?', ['%o%', '%o%', 20, 0]])

    mock_counts_data = [
      {'user_id' => 1, 'count' => 10},
      {'user_id' => 2, 'count' => 7},
    ]
    mock_db.expect(:execute, mock_counts_data, ['SELECT user_id, COUNT(*) as count FROM posts WHERE user_id IN (?, ?) GROUP BY user_id', [1, 2]])

    Database.stub :execute, ->(sql, params) { mock_db.execute(sql, params) } do
      users = @user_service.search_users('o')
      assert_equal 2, users.length
      assert_equal 'John Doe', users[0][:name]
      assert_equal 10, users[0][:posts_count]
      assert_equal 'Jane Smith', users[1][:name]
      assert_equal 7, users[1][:posts_count]
    end
    mock_db.verify
  end
end
