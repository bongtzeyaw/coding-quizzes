class GameCharacter
  def initialize(type)
    @type = type
    if type == 'warrior'
      @hp = 150
      @mp = 30
      @attack = 25
      @defense = 20
      @skills = %w[slash guard]
    elsif type == 'wizard'
      @hp = 80
      @mp = 120
      @attack = 10
      @defense = 8
      @skills = %w[fireball heal]
    elsif type == 'archer'
      @hp = 100
      @mp = 50
      @attack = 20
      @defense = 12
      @skills = %w[arrow multishot]
    end
  end

  def attack_enemy(enemy, skill)
    damage = 0
    if @type == 'warrior'
      if skill == 'slash'
        if @mp >= 5
          @mp -= 5
          damage = @attack * 1.5
        end
      elsif skill == 'normal'
        damage = @attack
      end
    elsif @type == 'wizard'
      if skill == 'fireball'
        if @mp >= 15
          @mp -= 15
          damage = @attack * 3
        end
      elsif skill == 'normal'
        damage = @attack
      end
    elsif @type == 'archer'
      if skill == 'multishot'
        if @mp >= 10
          @mp -= 10
          damage = @attack * 2
        end
      elsif skill == 'normal'
        damage = @attack
      end
    end

    damage -= enemy.instance_variable_get(:@defense) * 0.5 if enemy.instance_variable_get(:@defense) > 0

    damage = 0 if damage < 0

    enemy.instance_variable_set(:@hp, enemy.instance_variable_get(:@hp) - damage)
    damage
  end

  def level_up
    if @type == 'warrior'
      @hp += 30
      @mp += 5
      @attack += 5
      @defense += 4
    elsif @type == 'wizard'
      @hp += 15
      @mp += 20
      @attack += 3
      @defense += 2
    elsif @type == 'archer'
      @hp += 20
      @mp += 10
      @attack += 4
      @defense += 3
    end
  end
end
