class Travian extends require('casper').Casper
  selector:
    loginForm:              "form[name='login']"
    resourceTip:            "#rx area[href^='build.php?id=']"
    construct:    (i)    -> "#contract_building#{i} .contractLink .green.new"
    upgrade:                "#contract .contractLink .green.build"
    adventure:              "#adventureListForm .gotoAdventure.arrow"
    adventureOK:            "#start"
    reward:                 "#mentorTaskList .quest .reward"
    rewardOK:               "#dialogContent .green.questButtonGainReward"
    rewardValue:           [".questRewardTypeWood+.questRewardValue"
                            ".questRewardTypeClay+.questRewardValue"
                            ".questRewardTypeIron+.questRewardValue"
                            ".questRewardTypeCrop+.questRewardValue"]
    quest:                  ".green.questButtonOverviewAchievements"
    questReward:  (i)    -> "#achievementRewardList .quest .points_#{i}"
    questTitle:             "#dialogContent .questRewardTitle"
    questOK:                "#dialogContent .green.questButtonGainReward"
    inventory:    (i)    -> "#inventory_#{i} div"
    inventoryOK:            ".green.ok.dialogButtonOk"
    movements:              "#map_details .movements"
    troopsForm:             "#build form"
    troopsAll:              "#troops a"
    troopsRaid:             ".radio[name='c'][value='4']"
    troopsSend:             "#btn_ok"
    troopsOK:               "#btn_ok"
    troopsX:                ".abort button"
    attacked:               "#movements .a1"
    rally:                  "build.php?tt=1&id=39"
    level:                  "#content .titleInHeader .level"
    buildUrl:     (i)    -> "build.php?id=#{i}"
    buildgidUrl:  (i)    -> "build.php?gid=#{i}"
    buildCatUrl:  (i, j) -> "build.php?id=#{i}&category=#{j}"
    adventureUrl:           "hero_adventure.php"
    inventoryUrl:           "hero_inventory.php"

  echoLn: (x) ->
    @echo JSON.stringify msg: x

  echoJSON: (x) ->
    @echoLn JSON.stringify x

  echoImg: ->
    @echoLn "<img src='data:image/png;base64,#{@captureBase64 'png'}'>"

  constructor: ->
    super pageSettings: loadImages: false
    @args = JSON.parse @cli.get 0
    @start @args.baseUrl
    @waitForSelector @selector.loginForm, ->
      @echoLn 'started'
      @fill @selector.loginForm, {name: @args.ac, password: @args.pw}, true
    , ->
      @echoImg()
      @die 'no loginForm'
    @waitForSelector @selector.resourceTip, ->
      resources = @getGlobal 'resources'
      @prod = (Number resources.production['l' + i] for i in [1..5])
      @stor = (Number resources.storage[   'l' + i] for i in [1..4])
      @capa = (Number resources.maxStorage['l' + i] for i in [1..4])
      translate = (s) ->
        if s[3] == 'd'
          0
        else if s[3] == 'y'
          1
        else if s[3] == 'n'
          2
        else if s[3] == 'p'
          3

      @costs = @evaluate (selector, translate) ->
        for w in document.querySelectorAll selector
          x = w._extendedTipContent
          y = ///[^]+r1.+>(\d+)
                 [^]+r2.+>(\d+)
                 [^]+r3.+>(\d+)
                 [^]+r4.+>(\d+)///.exec x.text
          z = (Number v for v in y[1..4])
          z[4] = Number translate x.title
          z[5] = Number /\d+/.exec x.title
          z[6] = Number /level.+(\d+)/.exec(x.text)[1]
          z
      , @selector.resourceTip, translate
      @costs[i].type    = @costs[i][4] for i in [0..17]
      @costs[i].level   = @costs[i][5] for i in [0..17]
      @costs[i].upgrade = @costs[i][6] for i in [0..17]
      @echoLn @costs[0].type
    , ->
      @echoImg()
      @die 'failed login'

  baseOpen: (x) ->
    @open @args.baseUrl + x

  thenClickIfExists: (selector, f, g) ->
    @waitForSelector selector, ->
      #g = (s) ->
      #  document.querySelector(s)?.nextSibling?.nextSibling?.nextSibling?.nextSibling
      #return if @evaluate g, selector
      @click selector
      f?.call @
    , ->
      g?.call @

  thenMinimalCrop: ->
    @then ->
      if @prod[4] < (@args.minimalCrop ? 4)
        x = ((if v.type is 3 then v.upgrade else 999999) for v in @costs)
        id = 1 + x.indexOf Math.min x...
        @echoLn "minimalCrop #{id}"
        @baseOpen @selector.buildUrl id
        @thenClickIfExists @selector.upgrade, -> @echoLn 'built'

  thenGetBuild: ->
    @then ->
      w = for i in [0..3]
        Math.min (v.upgrade for v in @costs when v.type is i)...
      x = for v in @costs
        if v.upgrade is w[v.type]
          t = Math.max ((@capa[i] * 0.5 + v[i] - @stor[i]) / @prod[i] for i in [0..3])...
          t = 0 if t < 0
          Math.max (@stor[i] + @prod[i] * t - v[i] for i in [0..3])...
        else
          999999
      id = 1 + x.indexOf Math.min x...
      @echoLn "auto build #{id} (type #{@costs[id - 1].type})"
      @baseOpen @selector.buildUrl id
    @thenClickIfExists @selector.upgrade, -> @echoLn 'built'

  thenConstruct: (id, cat, gid) ->
    @then -> @baseOpen @selector.buildCatUrl id, cat
    @thenClickIfExists @selector.construct gid

  thenUpgradeTo: (id, level) ->
    @then -> @baseOpen @selector.buildUrl id
    @waitForSelector @selector.level, ->
      return if level <= /\d+/.exec @fetchText @selector.level
      @thenClickIfExists @selector.upgrade
    , ->

  thenInventory: (i) ->
    @then -> @baseOpen @selector.inventoryUrl
    @thenClickIfExists @selector.inventory i, ->
      @thenClickIfExists @selector.inventoryOK

  thenAdventure: ->
    @then -> @baseOpen @selector.adventureUrl
    @then -> @echoLn 'Adventure'
    @thenClickIfExists @selector.adventure, ->
      @thenClickIfExists @selector.adventureOK

  thenReward: ->
    @thenClickIfExists @selector.reward, ->
      @waitForSelector @selector.rewardOK, ->
        if @exists @selector.rewardValue[3]
          x = for i in [0..3]
            v = Number @fetchText @selector.rewardValue[i]
            @capa[i] - @stor[i] - @prod[i] - v
          @echoJSON x
          if 0 > Math.min x...
            @echoLn 'reward too much'
            return
        @echoLn 'collect reward'
        @click @selector.rewardOK
      , ->

  thenQuest: (i) ->
    @thenClickIfExists @selector.quest, ->
      @thenClickIfExists @selector.questReward i, ->
        if i is 25
          @waitForSelector @selector.questTitle, ->
            x = Math.min (@capa[i] - @stor[i] - @prod[i] for i in [0..3])...
            s = @evaluate (s) ->
              s.nextSibling.textContent
            , @selector.questTitle
            @echoJSON x
            @echoJSON s
            if /1000/.test(s) and 1000 > x or /200/.test(s) and 200 > x
              @echoLn 'quest too much'
            else
              @echoLn "collect quest 25"
              @thenClickIfExists @selector.questOK
        else
          @echoLn "collect quest #{i}"
          @thenClickIfExists @selector.questOK

  thenEscape: (f) ->
    @waitForSelector @selector.movements, ->
      t = 999999
      if @exists @selector.attacked
        t = @evaluate (selector) ->
          x = document.querySelector selector
          y = x.parentNode.nextSibling.nextSibling.childNodes[1].textContent
          [a,b,c,d] = /(\d+):(\d+):(\d+)/.exec y
          Number(b) * 3600 + Number(c) * 60 + Number(d)
        , @selector.attacked
        @echoLn "ATTACK IN #{t} seconds"
      if t > 5 * 60
        f?.call @
      else
        @echoLn 'waiting to escape...'
        @wait (Math.max 0, (t - 70) * 1000), ->
          @echoLn 'escaping...'
          @baseOpen @escapeRoute
          @waitForSelector @selector.troopsForm, ->
            @evaluate (selector) ->
              for x in document.querySelectorAll selector
                x.previousSibling.previousSibling.value = x.textContent
            , @selector.troopsAll
            @click @selector.troopsRaid
            @click @selector.troopsSend
            @thenClickIfExists @selector.troopsOK, ->
              @echoLn 'troops sent!'
              @wait 45 * 1000, ->
                @waitForSelector @selector.troopsX, ->
                  @click @selector.troopsX
                  @echoLn 'troops retreated.'
                , ->
                  @echoImg()
                  @echoLn 'CANT RETREAT! TRYING AGAIN - '
                  @baseOpen @selector.rally
                  @thenClickIfExists @selector.troopsX, ->
                  @echoLn 'troops retreated.'
    , -> @echoLn '???no movements???'

travian = new Travian
travian.thenMinimalCrop()
travian.thenGetBuild()
travian.thenAdventure()
travian.thenReward()
travian.thenQuest 25
travian.thenQuest 50
travian.thenQuest 75
#travian.thenConstruct 31, 1, 10
#travian.thenUpgradeTo 26, 3
travian.run()

