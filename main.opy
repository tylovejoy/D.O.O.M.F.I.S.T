globalvar Queue  # queue[players]
globalvar InProgress  # bool
globalvar TempIter  # temp iterator int
globalvar AbilityCount  # array[int] = [upper, slam, punch]
globalvar Positions  # array of start/end vect
globalvar Effects  # array of Checkpoint rings
globalvar Scoreboard  # string
globalvar GameLength  # Workshop Setting DOOM vs DOOMFIST
globalvar TimeRemaining


playervar State  # int 0=not started, 1=failed, 2=success
playervar Points  # int
playervar AbilityCount  # array[int] = [upper, slam, punch] copy of globalvar


rule "Workshop Settings":
    GameLength = createWorkshopSetting(enum["DOOMFIST", "DOOFIST", "DOFIST", "DBRUG" "DOOM"], "Settings", "Game Length", 0, 0)


rule "Match time -- Written By Hax":
    if getCurrentGamemode() == Gamemode.SKIRMISH:
        goto lbl_0
    wait(0.25)
    setMatchTime(1)
    wait(1.1)
    setMatchTime(1)
    wait(1.1)
    lbl_0:
    while true:
        setMatchTime(3600)
        wait(2875)
        TimeRemaining += true
        if TimeRemaining == 5:
            TimeRemaining = 1800
            hudHeader(getAllPlayers(), "  Server Restarts In {0} Min  ".format(ceil(TimeRemaining / 60)), HudPosition.RIGHT, -200, Color.RED, HudReeval.VISIBILITY_AND_STRING, SpecVisibility.ALWAYS)
            chase(TimeRemaining, false, rate=true, ChaseReeval.NONE)
            wait(1795)
            bigMessage(getAllPlayers(), "Restarting")
            wait(5)
            if getCurrentGamemode() == Gamemode.FFA:
                declarePlayerVictory(getPlayersInSlot(1, Team.ALL))
            else:
                declareTeamVictory(Team.1)
            return


rule "Initialize Gamemode":
    disableAnnouncer()
    disableGamemodeCompletion()
    disableMusic()
    disableScoring()

    Queue = []
    InProgress = false
    Positions = [vect(0, 0, 0), vect(0, 0, 0)]
    #Effects = []
    Scoreboard = ""
    createEffect(getAllPlayers(), Effect.RING, Color.TURQUOISE, Positions[0], 2, EffectReeval.VISIBILITY_POSITION_RADIUS_AND_COLOR)
    #Effects.append(getLastCreatedEntity())
    createEffect(getAllPlayers(), Effect.RING, Color.TURQUOISE, Positions[1], 2, EffectReeval.VISIBILITY_POSITION_RADIUS_AND_COLOR)
    #Effects.append(getLastCreatedEntity())
    createIcon(getAllPlayers(), Positions[0] + vect(0, 3, 0), Icon.ARROW_DOWN, IconReeval.VISIBILITY_POSITION_AND_COLOR, Color.TURQUOISE, true)
    createIcon(getAllPlayers(), Positions[1] + vect(0, 3, 0), Icon.ARROW_DOWN, IconReeval.VISIBILITY_POSITION_AND_COLOR, Color.TURQUOISE, true)

def scoreboardGenerate():
    Scoreboard = ""
    for TempIter in range(len(getAllPlayers())):
        Scoreboard = "{0}\n{1}\n{2}".format(Scoreboard, getAllPlayers()[TempIter], GameLength.substring(0, getAllPlayers()[TempIter].Points))

def queueCycle():
    # After each round, progress the queue.
    TempIter = Queue[0]
    Queue.remove(Queue[0])
    Queue.append(TempIter)

def enableAbilities():
    getAllPlayers().setAbility1Enabled(true)
    getAllPlayers().setAbility2Enabled(true)
    getAllPlayers().setSecondaryFireEnabled(true)
    getAllPlayers().setAbilityCooldown(Button.ABILITY_1, 0)
    getAllPlayers().setAbilityCooldown(Button.ABILITY_2, 0)
    getAllPlayers().setAbilityCooldown(Button.SECONDARY_FIRE, 0)

def setAbilities():
    getAllPlayers().setAbility1Enabled(true if AbilityCount[0] else false)
    getAllPlayers().setAbility2Enabled(true if AbilityCount[1] else false)
    getAllPlayers().setSecondaryFireEnabled(true if AbilityCount[2] else false)
    getAllPlayers().setAbilityCooldown(Button.ABILITY_1, 6)
    getAllPlayers().setAbilityCooldown(Button.ABILITY_2, 6)
    getAllPlayers().setAbilityCooldown(Button.SECONDARY_FIRE, 4)

def disableAbilities():
    eventPlayer.setAbility1Enabled(eventPlayer.AbilityCount[0])
    eventPlayer.setAbility2Enabled(eventPlayer.AbilityCount[1])
    eventPlayer.setSecondaryFireEnabled(eventPlayer.AbilityCount[2])

rule "Player Joins":
    @Event playerJoined
    # Add new player to queue and init player vars
    eventPlayer.disableGamemodeHud()
    eventPlayer.disableMessages()
    eventPlayer.disablePlayerCollision()
    eventPlayer.disableGamemodeInWorldUi()
    
    Queue.append(eventPlayer)
    eventPlayer.State = 0
    eventPlayer.Points = 0
    scoreboardGenerate()
    
rule "Player Leaves":
    @Event playerLeft
    Queue.remove(eventPlayer)
    eventPlayer.Points = 0
    scoreboardGenerate()

rule "Round End":
    @Condition InProgress
    @Condition all([p.State for p in getAllPlayers()])

    getAllPlayers().State = 0    
    enableAbilities()
    InProgress = false
    AbilityCount = [0, 0, 0]
    Positions = [vect(0, 0, 0), vect(0, 0, 0)]
    queueCycle()
    scoreboardGenerate()
    


def roundStart():
    InProgress = true
    getAllPlayers().AbilityCount = AbilityCount
    setAbilities()
    # Tele all players to starting position
    getAllPlayers().teleport(Queue[0].getPosition())
    scoreboardGenerate()


rule "Create Start Checkpoint -- PRE ROUND":
    @Event eachPlayer
    @Condition InProgress == false
    @Condition eventPlayer == Queue[0]
    @Condition eventPlayer.isHoldingButton(Button.INTERACT)
    Positions[0] = eventPlayer.getPosition()

rule "Create End Checkpoint -- PRE ROUND":
    @Event eachPlayer
    @Condition InProgress == false
    @Condition eventPlayer == Queue[0]
    @Condition distance(eventPlayer.getPosition(), Positions[0]) > 2
    @Condition Positions[0] != vect(0, 0, 0)
    @Condition eventPlayer.isOnGround()
    Positions[1] = eventPlayer.getPosition()
    eventPlayer.teleport(Positions[0])
    roundStart()

rule "Ability Count Increment -- PRE ROUND":
    @Event eachPlayer
    @Condition InProgress == false
    @Condition eventPlayer == Queue[0]
    @Condition distance(eventPlayer.getPosition(), Positions[0]) > 2
    @Condition not eventPlayer.isOnGround()
    @Condition eventPlayer.isHoldingButton(Button.SECONDARY_FIRE) or eventPlayer.isHoldingButton(Button.ABILITY_1) or eventPlayer.isHoldingButton(Button.ABILITY_2)

    if eventPlayer.isUsingAbility1():
        AbilityCount[0] += 1
    elif eventPlayer.isUsingAbility2():
        AbilityCount[1] += 1
    elif eventPlayer.isFiringSecondaryFire():
        AbilityCount[2] += 1


rule "Ability Count Decrement -- DURING ROUND":
    @Event eachPlayer
    @Condition InProgress == true
    @Condition distance(eventPlayer.getPosition(), Positions[0]) > 2
    @Condition not eventPlayer.isOnGround()
    @Condition eventPlayer.isHoldingButton(Button.SECONDARY_FIRE) or eventPlayer.isHoldingButton(Button.ABILITY_1) or eventPlayer.isHoldingButton(Button.ABILITY_2)
    @Condition eventPlayer.State == 0
    if eventPlayer.isUsingAbility1():
        eventPlayer.AbilityCount[0] -= 1
    elif eventPlayer.isUsingAbility2():
        eventPlayer.AbilityCount[1] -= 1
    elif eventPlayer.isFiringSecondaryFire():
        eventPlayer.AbilityCount[2] -= 1
    disableAbilities()

rule "Complete checkpoint -- DURING ROUND":
    @Event eachPlayer
    @Condition InProgress == true
    @Condition distance(eventPlayer.getPosition(), Positions[1]) < 2
    @Condition distance(eventPlayer.getPosition(), Positions[0]) > 2
    @Condition eventPlayer.isOnGround()
    @Condition eventPlayer.State == 0
    eventPlayer.State = 2
    bigMessage(eventPlayer, "SUCCESS!")
   
rule "Fail checkpoint -- DURING ROUND":
    @Event eachPlayer
    @Condition InProgress == true
    @Condition distance(eventPlayer.getPosition(), Positions[1]) > 2
    @Condition distance(eventPlayer.getPosition(), Positions[0]) > 2
    @Condition eventPlayer.isOnGround()
    @Condition eventPlayer.State == 0
    eventPlayer.State = 1
    bigMessage(eventPlayer, "FAILED!")
    eventPlayer.Points += 1
    scoreboardGenerate()

rule "HUD":
    hudText(getAllPlayers(), "SCOREBOARD", Scoreboard, null, HudPosition.RIGHT, 0, Color.TURQUOISE, Color.TURQUOISE, null, HudReeval.VISIBILITY_STRING_AND_COLOR, SpecVisibility.ALWAYS)
    hudText(getAllPlayers(), "CURRENT TURN", Queue[0], Queue[1], HudPosition.TOP, 0, Color.TURQUOISE, Color.TURQUOISE, Color.TURQUOISE, HudReeval.VISIBILITY_STRING_AND_COLOR, SpecVisibility.ALWAYS)
    hudText(
        getAllPlayers(), 
        "{0} {1} {2} {3} {4} {5}".format(
            abilityIconString(Hero.DOOMFIST, Button.ABILITY_1),
            localPlayer.AbilityCount[0], 
            abilityIconString(Hero.DOOMFIST, Button.ABILITY_2), 
            localPlayer.AbilityCount[0], 
            abilityIconString(Hero.DOOMFIST, Button.SECONDARY_FIRE), 
            localPlayer.AbilityCount[0]
        ), 
        null,
        null, 
        HudPosition.LEFT, 
        0, 
        Color.TURQUOISE, 
        Color.TURQUOISE, 
        null, 
        HudReeval.VISIBILITY_STRING_AND_COLOR, 
        SpecVisibility.ALWAYS
    )

rule "DOOMFIST Loser":
    @Event eachPlayer
    @Condition eventPlayer.Points == strLen(GameLength)
    eventPlayer.setRespawnTime(9999)
    kill(eventPlayer, null)

rule "DOOMFIST Winner":
    @Disabled
    @Condition len([p for p in getAllPlayers() if p.isAlive()]) <= 1
    bigMessage(localPlayer, "{0} is the winner!".format([p for p in getAllPlayers() if p.isAlive()][0]))
