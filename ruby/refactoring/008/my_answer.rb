# Database placeholder implementation to be replaced
module Database
  def self.execute(sql)
    []
  end
end

class User
  DEFAULT_NUMBER_OF_LATEST_POSTS = 5

  def initialize(user_record)
    @user_record = user_record
  end

  def id
    @user_record['id']
  end

  def name
    @user_record['name']
  end

  def email
    @user_record['email']
  end

  def posts_count
    extract_count(table: 'posts', foreign_key: 'user_id')
  end

  def followers_count
    extract_count(table: 'follows', foreign_key: 'followed_id')
  end

  def following_count
    extract_count(table: 'follows', foreign_key: 'follower_id')
  end

  def latest_posts
    extract_user_associated_records(table: 'posts', foreign_key: 'user_id')
  end

  private

  def extract_user_record
    Database.execute(
      format(
        'SELECT * FROM users WHERE id = %<id>s',
        id:
      )
    ).first
  end

  def extract_count(table:, foreign_key:)
    result = Database.execute(
      format(
        'SELECT COUNT(*) as count FROM %<table>s WHERE %<foreign_key>s = %<id>s',
        table:,
        foreign_key:,
        id:
      )
    ).first

    result['count']
  end

  def extract_user_associated_records(table:, foreign_key:, limit: DEFAULT_NUMBER_OF_LATEST_POSTS)
    Database.execute(
      format(
        'SELECT * FROM %<table>s WHERE %<foreign_key>s = %<id>s ORDER BY created_at DESC LIMIT %<limit>s',
        table:,
        foreign_key:,
        id:,
        limit:
      )
    )
  end
end

class UserService
  def get_user_info(user_id)
    user_sql = "SELECT * FROM users WHERE id = #{user_id}"
    user_result = Database.execute(user_sql)

    return nil if user_result.empty?

    user = User.new(user_result[0])

    {
      id: user.id,
      name: user.name,
      email: user.email,
      posts_count: user.posts_count,
      followers_count: user.followers_count,
      following_count: user.following_count,
      latest_posts: user.latest_posts
    }
  end

  def search_users(keyword, page = 1)
    limit = 20
    offset = (page - 1) * limit

    if [nil, ''].include?(keyword)
      sql = "SELECT * FROM users ORDER BY created_at DESC LIMIT #{limit} OFFSET #{offset}"
    else
      sql = "SELECT * FROM users WHERE name LIKE '%#{keyword}%' OR email LIKE '%#{keyword}%' ORDER BY created_at DESC LIMIT #{limit} OFFSET #{offset}"
    end

    results = Database.execute(sql)

    users = []
    for i in 0..results.length - 1
      user = results[i]

      posts_sql = "SELECT COUNT(*) as count FROM posts WHERE user_id = #{user['id']}"
      posts_result = Database.execute(posts_sql)
      posts_count = posts_result[0]['count']

      users << {
        id: user['id'],
        name: user['name'],
        email: user['email'],
        posts_count: posts_count
      }
    end

    users
  end
end
