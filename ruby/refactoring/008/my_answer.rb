class UserService
  def get_user_info(user_id)
    user_sql = "SELECT * FROM users WHERE id = #{user_id}"
    user_result = Database.execute(user_sql)

    return nil if user_result.empty?

    user = user_result[0]

    posts_sql = "SELECT COUNT(*) as count FROM posts WHERE user_id = #{user_id}"
    posts_result = Database.execute(posts_sql)
    posts_count = posts_result[0]['count']

    followers_sql = "SELECT COUNT(*) as count FROM follows WHERE followed_id = #{user_id}"
    followers_result = Database.execute(followers_sql)
    followers_count = followers_result[0]['count']

    following_sql = "SELECT COUNT(*) as count FROM follows WHERE follower_id = #{user_id}"
    following_result = Database.execute(following_sql)
    following_count = following_result[0]['count']

    latest_posts_sql = "SELECT * FROM posts WHERE user_id = #{user_id} ORDER BY created_at DESC LIMIT 5"
    latest_posts = Database.execute(latest_posts_sql)

    {
      id: user['id'],
      name: user['name'],
      email: user['email'],
      posts_count: posts_count,
      followers_count: followers_count,
      following_count: following_count,
      latest_posts: latest_posts
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
