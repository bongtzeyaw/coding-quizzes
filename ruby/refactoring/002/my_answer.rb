# frozen_string_literal: true

class GameCharacter
  ATTACK_SKILLS_DETAIL = {
    'normal' => { mp_cost: 0, attack_multiplier: 1 }
  }.freeze

  DEFAULT_DEFENSE_MULTIPLIER = 0.5

  def initialize(hp:, mp:, attack:, defense:, skills:)
    @hp = hp
    @mp = mp
    @attack = attack
    @defense = defense
    @skills = skills
  end

  def attack_enemy(enemy, skill)
    return 0 unless valid_attack_skill?(skill)

    attack_skill_detail = attack_skill_details[skill]
    return 0 unless sufficient_mp_for_skill?(attack_skill_detail)

    consume_mp!(attack_skill_detail)
    damage = calculate_damage(attack_skill_detail)
    enemy.receive_damage!(damage)
  end

  def level_up
    increments = level_up_increments

    @hp += increments[:hp]
    @mp += increments[:mp]
    @attack += increments[:attack]
    @defense += increments[:defense]
  end

  protected

  def receive_damage!(damage)
    final_damage = calculate_mitigated_damage(damage)
    @hp = [0, @hp - final_damage].max
    final_damage
  end

  private

  def attack_skill_details
    ATTACK_SKILLS_DETAIL.merge(self.class::ATTACK_SKILLS_DETAIL)
  end

  def level_up_increments
    self.class::LEVEL_UP_STATS_INCREMENTS
  end

  def valid_attack_skill?(skill)
    attack_skill_details.key?(skill)
  end

  def sufficient_mp_for_skill?(attack_skill_detail)
    @mp >= attack_skill_detail[:mp_cost]
  end

  def consume_mp!(attack_skill_detail)
    @mp -= attack_skill_detail[:mp_cost]
  end

  def calculate_damage(attack_skill_detail)
    @attack * attack_skill_detail[:attack_multiplier]
  end

  def calculate_mitigated_damage(damage)
    @defense.positive? ? [0, damage - @defense * DEFAULT_DEFENSE_MULTIPLIER].max : damage
  end
end

class Warrior < GameCharacter
  ATTACK_SKILLS_DETAIL = {
    'slash' => { mp_cost: 5, attack_multiplier: 1.5 }
  }.freeze

  LEVEL_UP_STATS_INCREMENTS = {
    hp: 30,
    mp: 5,
    attack: 5,
    defense: 4
  }.freeze

  def initialize
    super(
      hp: 150,
      mp: 30,
      attack: 25,
      defense: 20,
      skills: %w[slash guard]
    )
  end
end

class Wizard < GameCharacter
  ATTACK_SKILLS_DETAIL = {
    'fireball' => { mp_cost: 15, attack_multiplier: 3 }
  }.freeze

  LEVEL_UP_STATS_INCREMENTS = {
    hp: 15,
    mp: 20,
    attack: 3,
    defense: 2
  }.freeze

  def initialize
    super(
      hp: 80,
      mp: 120,
      attack: 10,
      defense: 8,
      skills: %w[fireball heal]
    )
  end
end

class Archer < GameCharacter
  ATTACK_SKILLS_DETAIL = {
    'multishot' => { mp_cost: 10, attack_multiplier: 2 }
  }.freeze

  LEVEL_UP_STATS_INCREMENTS = {
    hp: 20,
    mp: 10,
    attack: 4,
    defense: 3
  }.freeze

  def initialize
    super(
      hp: 100,
      mp: 50,
      attack: 20,
      defense: 12,
      skills: %w[arrow multishot]
    )
  end
end
