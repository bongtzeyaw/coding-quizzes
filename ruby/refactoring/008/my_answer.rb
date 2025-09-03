# frozen_string_literal: true

# Database placeholder implementation to be replaced
module Database
  def self.execute(sql, params = [])
    []
  end
end

class User
  LATEST_POSTS_LIMIT = 5

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
    @posts_count ||= count_records(table: 'posts', foreign_key: 'user_id')
  end

  def followers_count
    @followers_count ||= count_records(table: 'follows', foreign_key: 'followed_id')
  end

  def following_count
    @following_count ||= count_records(table: 'follows', foreign_key: 'follower_id')
  end

  def latest_posts
    @latest_posts ||= fetch_user_associated_records(table: 'posts', foreign_key: 'user_id', limit: LATEST_POSTS_LIMIT)
  end

  private

  def count_records(table:, foreign_key:)
    result = Database.execute(
      "SELECT COUNT(*) as count FROM #{table} WHERE #{foreign_key} = ?",
      [id]
    ).first

    result['count']
  end

  def fetch_user_associated_records(table:, foreign_key:, limit:)
    Database.execute(
      "SELECT * FROM #{table} WHERE #{foreign_key} = ? ORDER BY created_at DESC LIMIT ?",
      [id, limit]
    )
  end
end

class UserRegistry
  DEFAULT_PAGE_SIZE = 20

  class << self
    def find_by(id:)
      result = Database.execute(
        'SELECT * FROM users WHERE id = ?',
        [id]
      ).first

      return nil unless result

      User.new(result)
    end

    def search_by_name_or_email(keyword:, page:)
      offset = calculate_pagination_offset(page)
      sql, params = build_search_query(keyword, offset)

      results = Database.execute(sql, params)
      results.map { |result| User.new(result) }
    end

    def fetch_posts_counts(user_ids)
      return {} if user_ids.empty?

      placeholders = (['?'] * user_ids.size).join(', ')
      sql = "SELECT user_id, COUNT(*) as count FROM posts WHERE user_id IN (#{placeholders}) GROUP BY user_id"

      results = Database.execute(sql, user_ids)
      transform_results_to_hash(results)
    end

    private

    def calculate_pagination_offset(page)
      (page - 1) * DEFAULT_PAGE_SIZE
    end

    def build_search_query(keyword, offset)
      base_query = 'SELECT * FROM users'
      order_by_query = 'ORDER BY created_at DESC LIMIT ? OFFSET ?'
      order_by_params = [DEFAULT_PAGE_SIZE, offset]

      if keyword.nil? || keyword.empty?
        sql = "#{base_query} #{order_by_query}"
        params = order_by_params
      else
        sql = "#{base_query} WHERE name LIKE ? OR email LIKE ? #{order_by_query}"
        params = ["%#{keyword}%", "%#{keyword}%"] + order_by_params
      end

      [sql, params]
    end

    def transform_results_to_hash(results)
      results.map { |row| [row['user_id'], row['count']] }.to_h
    end
  end
end

class UserPresenter
  def initialize(user)
    @user = user
  end

  def detailed_info
    {
      id: @user.id,
      name: @user.name,
      email: @user.email,
      posts_count: @user.posts_count,
      followers_count: @user.followers_count,
      following_count: @user.following_count,
      latest_posts: @user.latest_posts
    }
  end

  def summarised_info_with_preloaded_posts_counts(posts_counts_map)
    {
      id: @user.id,
      name: @user.name,
      email: @user.email,
      posts_count: posts_counts_map.fetch(@user.id, 0)
    }
  end
end

class UserService
  def get_user_info(user_id)
    user = UserRegistry.find_by(id: user_id)
    return nil unless user

    UserPresenter.new(user).detailed_info
  end

  def search_users(keyword, page = 1)
    users = UserRegistry.search_by_name_or_email(keyword:, page:)

    user_ids = users.map(&:id)
    posts_counts_map = UserRegistry.fetch_posts_counts(user_ids)

    users.map do |user|
      UserPresenter.new(user).summarised_info_with_preloaded_posts_counts(posts_counts_map)
    end
  end
end
