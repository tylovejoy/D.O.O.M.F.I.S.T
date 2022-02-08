globalvar Queue  # queue[players]
globalvar InProgress  # bool
globalvar TempIter  # temp iterator int
globalvar AbilityCount  # array[int] = [upper, slam, punch]
globalvar Positions  # array of start/end vect
globalvar Effects  # array of Checkpoint rings
globalvar Scoreboard  # string

playervar State  # int 0=not started, 1=failed, 2=success
playervar Points  # int
playervar AbilityCount  # array[int] = [upper, slam, punch] copy of globalvar


rule "Initialize Gamemode":
    Queue = []
    InProgress = false
    Positions = [vect(0, 0, 0), vect(0, 0, 0)]
    #Effects = []
    Scoreboard = ""
    createEffect(localPlayer, Effect.RING, Color.TURQUOISE, Positions[0], 2, EffectReeval.POSITION_RADIUS_AND_COLOR)
    #Effects.append(getLastCreatedEntity())
    createEffect(localPlayer, Effect.RING, Color.TURQUOISE, Positions[1], 2, EffectReeval.POSITION_RADIUS_AND_COLOR)
    #Effects.append(getLastCreatedEntity())
    createIcon(localPlayer, Positions[0], Icon.ARROW_DOWN, IconReeval.POSITION,Color.TURQUOISE, true)
    createIcon(localPlayer, Positions[1], Icon.ARROW_DOWN, IconReeval.POSITION,Color.TURQUOISE, true)

def scoreboardGenerate():
    for TempIter in range(len(getAllPlayers())):
        Scoreboard += "{0}\n{1}\n".format(getAllPlayers()[TempIter], "DOOMFIST".substring(0, getAllPlayers()[TempIter].Points))

def queueCycle():
    # After each round, progress the queue.
    Queue.append(Queue[0])
    Queue.remove(Queue[0])

def enableAbilities():
    getAllPlayers().setAbility1Enabled(true)
    getAllPlayers().setAbility2Enabled(true)
    getAllPlayers().setSecondaryFireEnabled(true)
    getAllPlayers().setAbilityCooldown(Button.ABILITY_1, 0)
    getAllPlayers().setAbilityCooldown(Button.ABILITY_2, 0)
    getAllPlayers().setAbilityCooldown(Button.SECONDARY_FIRE, 0)

def setAbilities():
    getAllPlayers().setAbility1Enabled(AbilityCount[0])
    getAllPlayers().setAbility2Enabled(AbilityCount[1])
    getAllPlayers().setSecondaryFireEnabled(AbilityCount[2])
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

    # Reset State tracker
    for TempIter in range(len(getAllPlayers())):
        getAllPlayers()[TempIter].State = 0

    enableAbilities()
    InProgress = false
    AbilityCount = [0, 0, 0]
    Positions = [vect(0, 0, 0), vect(0, 0, 0)]
    queueCycle()
    scoreboardGenerate()
    


def roundStart():
    InProgress = true
    AbilityCount = Queue[0].AbilityCount
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
    @Condition eventPlayer.isOnGround()
    Positions[1] = eventPlayer.getPosition()
    roundStart()

rule "Ability Count Increment -- PRE ROUND":
    @Event eachPlayer
    @Condition InProgress == false
    @Condition eventPlayer == Queue[0]
    @Condition distance(eventPlayer.getPosition(), Positions[0]) > 2
    @Condition not eventPlayer.isOnGround()
    @Condition eventPlayer.isHoldingButton(Button.SECONDARY_FIRE) or eventPlayer.isHoldingButton(Button.ABILITY_1) or eventPlayer.isHoldingButton(Button.ABILITY_2)

    if eventPlayer.isUsingAbility1():
        eventPlayer.AbilityCount[0] += 1
    elif eventPlayer.isUsingAbility2():
        eventPlayer.AbilityCount[1] += 1
    elif eventPlayer.isFiringSecondaryFire():
        eventPlayer.AbilityCount[2] += 1


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
    @Condition eventPlayer.isOnGround()
    @Condition eventPlayer.State == 0
    eventPlayer.State = 2
    bigMessage(eventPlayer, "SUCCESS!")
   
rule "Fail checkpoint -- DURING ROUND":
    @Event eachPlayer
    @Condition InProgress == true
    @Condition distance(eventPlayer.getPosition(), Positions[1]) > 2
    @Condition eventPlayer.isOnGround()
    @Condition eventPlayer.State == 0
    eventPlayer.State = 1
    bigMessage(eventPlayer, "FAILED!")
    scoreboardGenerate()

rule "HUD":
    hudText(localPlayer, "SCOREBOARD", Scoreboard, null, HudPosition.RIGHT, 0, Color.TURQUOISE, Color.TURQUOISE, null, HudReeval.STRING, SpecVisibility.ALWAYS)
    hudText(localPlayer, "CURRENT TURN", Queue[0], Queue[1], HudPosition.TOP, 0, Color.TURQUOISE, Color.TURQUOISE, Color.TURQUOISE, HudReeval.STRING, SpecVisibility.ALWAYS)
    hudText(
        localPlayer, 
        "ABILITY COUNT", 
        "{0}: {1} | {2}: {3}| {4}: {5}".format(
            buttonString(Button.ABILITY_1), 
            localPlayer.AbilityCount[0], 
            buttonString(Button.ABILITY_2), 
            localPlayer.AbilityCount[0], 
            buttonString(Button.SECONDARY_FIRE), 
            localPlayer.AbilityCount[0]
        ), 
        null, 
        HudPosition.LEFT, 
        0, 
        Color.TURQUOISE, 
        Color.TURQUOISE, 
        null, 
        HudReeval.STRING, 
        SpecVisibility.ALWAYS
    )

rule "DOOMFIST Loser":
    @Event eachPlayer
    @Condition eventPlayer.Points == 8
    eventPlayer.setRespawnTime(9999)
    kill(eventPlayer, null)

rule "DOOMFIST Winner":
    @Condition len([p for p in getAllPlayers() if p.isAlive()]) <= 1
    bigMessage(localPlayer, "{0} is the winner!".format([p for p in getAllPlayers() if p.isAlive()][0]))