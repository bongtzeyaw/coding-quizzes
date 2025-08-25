# frozen_string_literal: true

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

class UserRegistry
  DEFAULT_PAGE_SIZE = 20

  def self.find_by(id:)
    result = Database.execute(
      format(
        'SELECT * FROM users WHERE id = %<id>s',
        id:
      )
    ).first

    return nil unless result

    User.new(result)
  end

  def self.search_by_name_or_email(keyword:, page:)
    offset = calculate_pagination_offset(page)
    sql = build_search_query(keyword, offset)

    results = Database.execute(sql)
    results.map { |result| User.new(result) }
  end

  def self.calculate_pagination_offset(page)
    (page - 1) * DEFAULT_PAGE_SIZE
  end

  def self.build_search_condition_query(keyword)
    if keyword.nil? || keyword.empty?
      ''
    else
      format(
        "WHERE name LIKE '%%%<keyword>s%%' OR email LIKE '%%%<keyword>s%%' ",
        keyword:
      )
    end
  end

  def self.build_search_query(keyword, offset)
    search_condition_query = build_search_condition_query(keyword)

    format(
      'SELECT * FROM users %<search_condition_query>sORDER BY created_at DESC LIMIT %<limit>s OFFSET %<offset>s',
      search_condition_query:,
      limit: DEFAULT_PAGE_SIZE,
      offset:
    )
  end

  private_class_method :calculate_pagination_offset, :build_search_condition_query, :build_search_query
end

class UserService
  def get_user_info(user_id)
    user = UserRegistry.find_by(id: user_id)
    return nil unless user

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
    users = UserRegistry.search_by_name_or_email(keyword:, page:)

    users.map do |user|
      {
        id: user.id,
        name: user.name,
        email: user.email,
        posts_count: user.posts_count
      }
    end
  end
end
