require 'minitest/autorun'
require_relative 'my_answer'

class TestGameCharacter < Minitest::Test
  def setup
    @warrior = Warrior.new
    @wizard = Wizard.new
    @archer = Archer.new

    @enemy_warrior = Warrior.new
    @enemy_wizard = Wizard.new
    @enemy_archer = Archer.new

    @enemy_warrior.instance_variable_set(:@hp, 100)
    @enemy_warrior.instance_variable_set(:@defense, 10)

    @enemy_wizard.instance_variable_set(:@hp, 100)
    @enemy_wizard.instance_variable_set(:@defense, 10)

    @enemy_archer.instance_variable_set(:@hp, 100)
    @enemy_archer.instance_variable_set(:@defense, 10)
  end

  def test_warrior_initialization
    assert_equal 150, @warrior.instance_variable_get(:@hp)
    assert_equal 30, @warrior.instance_variable_get(:@mp)
    assert_equal 25, @warrior.instance_variable_get(:@attack)
    assert_equal 20, @warrior.instance_variable_get(:@defense)
  end

  def test_wizard_initialization
    assert_equal 80, @wizard.instance_variable_get(:@hp)
    assert_equal 120, @wizard.instance_variable_get(:@mp)
    assert_equal 10, @wizard.instance_variable_get(:@attack)
    assert_equal 8, @wizard.instance_variable_get(:@defense)
  end

  def test_archer_initialization
    assert_equal 100, @archer.instance_variable_get(:@hp)
    assert_equal 50, @archer.instance_variable_get(:@mp)
    assert_equal 20, @archer.instance_variable_get(:@attack)
    assert_equal 12, @archer.instance_variable_get(:@defense)
  end

  def test_warrior_normal_attack
    initial_enemy_hp = @enemy_warrior.instance_variable_get(:@hp)
    initial_warrior_mp = @warrior.instance_variable_get(:@mp)

    expected_damage = 20.0
    returned_damage = @warrior.attack_enemy(@enemy_warrior, 'normal')

    assert_equal expected_damage, returned_damage
    assert_equal initial_enemy_hp - expected_damage, @enemy_warrior.instance_variable_get(:@hp)
    assert_equal initial_warrior_mp, @warrior.instance_variable_get(:@mp)
  end

  def test_warrior_slash_attack
    initial_enemy_hp = @enemy_warrior.instance_variable_get(:@hp)
    initial_warrior_mp = @warrior.instance_variable_get(:@mp)

    expected_damage = 32.5
    returned_damage = @warrior.attack_enemy(@enemy_warrior, 'slash')

    assert_equal expected_damage, returned_damage
    assert_equal initial_enemy_hp - expected_damage, @enemy_warrior.instance_variable_get(:@hp)
    assert_equal initial_warrior_mp - 5, @warrior.instance_variable_get(:@mp)
  end

  def test_warrior_slash_attack_insufficient_mp
    @warrior.instance_variable_set(:@mp, 4)
    initial_enemy_hp = @enemy_warrior.instance_variable_get(:@hp)
    initial_warrior_mp = @warrior.instance_variable_get(:@mp)

    expected_damage = 0.0
    returned_damage = @warrior.attack_enemy(@enemy_warrior, 'slash')

    assert_equal expected_damage, returned_damage
    assert_equal initial_enemy_hp, @enemy_warrior.instance_variable_get(:@hp)
    assert_equal initial_warrior_mp, @warrior.instance_variable_get(:@mp)
  end

  def test_wizard_normal_attack
    initial_enemy_hp = @enemy_wizard.instance_variable_get(:@hp)
    initial_wizard_mp = @wizard.instance_variable_get(:@mp)

    expected_damage = 5.0 # (10 - 10 * 0.5)
    returned_damage = @wizard.attack_enemy(@enemy_wizard, 'normal')

    assert_equal expected_damage, returned_damage
    assert_equal initial_enemy_hp - expected_damage, @enemy_wizard.instance_variable_get(:@hp)
    assert_equal initial_wizard_mp, @wizard.instance_variable_get(:@mp)
  end

  def test_wizard_fireball_attack
    initial_enemy_hp = @enemy_wizard.instance_variable_get(:@hp)
    initial_wizard_mp = @wizard.instance_variable_get(:@mp)

    expected_damage = 25.0 # (10 * 3 - 10 * 0.5)
    returned_damage = @wizard.attack_enemy(@enemy_wizard, 'fireball')

    assert_equal expected_damage, returned_damage
    assert_equal initial_enemy_hp - expected_damage, @enemy_wizard.instance_variable_get(:@hp)
    assert_equal initial_wizard_mp - 15, @wizard.instance_variable_get(:@mp)
  end

  def test_wizard_fireball_attack_insufficient_mp
    @wizard.instance_variable_set(:@mp, 14)
    initial_enemy_hp = @enemy_wizard.instance_variable_get(:@hp)
    initial_wizard_mp = @wizard.instance_variable_get(:@mp)

    expected_damage = 0.0
    returned_damage = @wizard.attack_enemy(@enemy_wizard, 'fireball')

    assert_equal expected_damage, returned_damage
    assert_equal initial_enemy_hp, @enemy_wizard.instance_variable_get(:@hp)
    assert_equal initial_wizard_mp, @wizard.instance_variable_get(:@mp)
  end

  def test_archer_normal_attack
    initial_enemy_hp = @enemy_archer.instance_variable_get(:@hp)
    initial_archer_mp = @archer.instance_variable_get(:@mp)

    expected_damage = 15.0 # (20 - 10 * 0.5)
    returned_damage = @archer.attack_enemy(@enemy_archer, 'normal')

    assert_equal expected_damage, returned_damage
    assert_equal initial_enemy_hp - expected_damage, @enemy_archer.instance_variable_get(:@hp)
    assert_equal initial_archer_mp, @archer.instance_variable_get(:@mp)
  end

  def test_archer_multishot_attack
    initial_enemy_hp = @enemy_archer.instance_variable_get(:@hp)
    initial_archer_mp = @archer.instance_variable_get(:@mp)

    expected_damage = 35.0 # (20 * 2 - 10 * 0.5)
    returned_damage = @archer.attack_enemy(@enemy_archer, 'multishot')

    assert_equal expected_damage, returned_damage
    assert_equal initial_enemy_hp - expected_damage, @enemy_archer.instance_variable_get(:@hp)
    assert_equal initial_archer_mp - 10, @archer.instance_variable_get(:@mp)
  end

  def test_archer_multishot_attack_insufficient_mp
    @archer.instance_variable_set(:@mp, 9)
    initial_enemy_hp = @enemy_archer.instance_variable_get(:@hp)
    initial_archer_mp = @archer.instance_variable_get(:@mp)

    expected_damage = 0.0
    returned_damage = @archer.attack_enemy(@enemy_archer, 'multishot')

    assert_equal expected_damage, returned_damage
    assert_equal initial_enemy_hp, @enemy_archer.instance_variable_get(:@hp)
    assert_equal initial_archer_mp, @archer.instance_variable_get(:@mp)
  end

  def test_attack_damage_cannot_be_negative
    weak_character = Warrior.new
    weak_character.instance_variable_set(:@attack, 1)

    tough_enemy = Warrior.new
    tough_enemy.instance_variable_set(:@hp, 100)
    tough_enemy.instance_variable_set(:@defense, 100)

    expected_damage = 0.0
    returned_damage = weak_character.attack_enemy(tough_enemy, 'normal')

    assert_equal expected_damage, returned_damage
    assert_equal 100, tough_enemy.instance_variable_get(:@hp)
  end

  def test_attack_when_defense_is_zero
    weak_character = Warrior.new
    weak_character.instance_variable_set(:@attack, 1)

    weak_enemy = Warrior.new
    weak_enemy.instance_variable_set(:@hp, 100)
    weak_enemy.instance_variable_set(:@defense, 0)

    expected_damage = 1.0
    returned_damage = weak_character.attack_enemy(weak_enemy, 'normal')

    assert_equal expected_damage, returned_damage
    assert_equal 99, weak_enemy.instance_variable_get(:@hp)
  end

  def test_attack_when_defense_is_negative
    weak_character = Warrior.new
    weak_character.instance_variable_set(:@attack, 1)

    irregular_enemy = Warrior.new
    irregular_enemy.instance_variable_set(:@hp, 100)
    irregular_enemy.instance_variable_set(:@defense, -1)

    expected_damage = 1.0
    returned_damage = weak_character.attack_enemy(irregular_enemy, 'normal')

    assert_equal expected_damage, returned_damage
    assert_equal 99, irregular_enemy.instance_variable_get(:@hp)
  end

  def test_warrior_level_up
    @warrior.level_up
    assert_equal 180, @warrior.instance_variable_get(:@hp)
    assert_equal 35, @warrior.instance_variable_get(:@mp)
    assert_equal 30, @warrior.instance_variable_get(:@attack)
    assert_equal 24, @warrior.instance_variable_get(:@defense)
  end

  def test_wizard_level_up
    @wizard.level_up
    assert_equal 95, @wizard.instance_variable_get(:@hp)
    assert_equal 140, @wizard.instance_variable_get(:@mp)
    assert_equal 13, @wizard.instance_variable_get(:@attack)
    assert_equal 10, @wizard.instance_variable_get(:@defense)
  end

  def test_archer_level_up
    @archer.level_up
    assert_equal 120, @archer.instance_variable_get(:@hp)
    assert_equal 60, @archer.instance_variable_get(:@mp)
    assert_equal 24, @archer.instance_variable_get(:@attack)
    assert_equal 15, @archer.instance_variable_get(:@defense)
  end
end
