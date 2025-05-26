// TODO(Parin): `Timer` and other update stuff should throw an error if you try to do stuff without updating first.
// TODO(Parin): `parin.platformer` could have a layer system.
// TODO(Parin): `parin.platformer` could return `Rect` indead of `ref IRect`. This removes `toVec` from user code and could also include the hidden remainder.
// TODO(Parin): `parin.platformer` should create an actor and resolve the collisions at that position. Right now it only resolves when moving.

module source.app;

import parin;

Game* game;
TextureId atlas;
SoundId walkSound;
SoundId doorSound;
SoundId goodSound;
FontId font = engineFont;

enum gameWidth  = 160;
enum gameHeight = 90;
enum gameSize   = Vec2(gameWidth, gameHeight);
enum gameTop    = gameSize * Vec2(0.5f, 0.0f);
enum gameCenter = gameSize * Vec2(0.5f, 0.5f);
enum gameBottom = gameSize * Vec2(0.5f, 1.0f);

enum commonIdleAnimation = SpriteAnimation(0, 1, 0, true);
enum commonWalkAnimation = SpriteAnimation(0, 2, 10, true);
enum commonFallAnimation = SpriteAnimation(0, 4, 8, false);
enum commonSleepAnimtion = SpriteAnimation(1, 1, 0, false);

enum buttonsTargetInput = "1323";
enum wormsTargetCount = 19;
enum bloodTargetCount = 1;
enum defaultDoorHp = 5;
enum defaultTextHp = "------";

struct Player {
    int hp = defaultTextHp.length;
    bool canMove;
    bool canAction = true; // Bruh, I don't even care anymore.
    bool isFalling;
    bool hasAction;
    Timer hitDelayTimer = Timer(2);
    Timer flashTimer = Timer(0.14f, true);
    bool flashState;
    bool isSleeping = true;
    BoxActorId id;
    BoxMover mover = BoxMover(1.0f, 0.5f);

    Sprite sprite = Sprite(8, 8, 0, 112);
    Vec2 spriteScale = Vec2(1);
    Flip spriteFlip = Flip.x;
    Hook spriteHook = Hook.bottom;

    void update(float dt) {
        sprite.update(dt);
        if (hp == 0) {
            stopSound(walkSound);
            return;
        }
        hitDelayTimer.update(dt);
        flashTimer.update(dt);

        // Update state.
        if (canMove) {
            hasAction = false;
            if (!wasd.isZero) isSleeping = false;
            if (flashTimer.hasStopped) flashState = !flashState;
            if (!hitDelayTimer.isRunning) {
                flashState = false;
                flashTimer.stop();
            }
            if (isFalling) {
                auto holeCenter = getActor(game.hole.id).centerPoint.toVec();
                auto fallPoint = holeCenter - getActor(id).size.toVec() * Vec2(0.5f) + Vec2(0, 3);
                game.world.moveActorTo(id, fallPoint, Vec2(0.3f));
                if (spriteScale.x == 0.0f) hp = 0;
            } else {
                game.world.moveActor(id, mover.move(wasd));
            }
            if (!canAction) hasAction = false;
        }

        // Update sprite.
        sprite.position = getActor(id).bottomPoint.toVec();
        spriteFlip = wasd.x == 0 ? spriteFlip : (wasd.x < 0) ? Flip.x : Flip.none;
        if (0) {
        } else if (isSleeping) {
            sprite.play(commonSleepAnimtion);
        } else if (isFalling) {
            sprite.play(commonFallAnimation, true);
            stopSound(walkSound);
            if (sprite.hasLastFrameProgress) spriteScale = spriteScale.moveTo(Vec2(0.0f), Vec2(0.02f));
            return;
        } else {
            if (wasd.isZero) {
                sprite.play(commonIdleAnimation);
                stopSound(walkSound);
            } else {
                sprite.play(commonWalkAnimation);
                playSound(walkSound);
            }
        }
    }

    void draw() {
        auto o = DrawOptions(Hook.bottom);
        o.flip = spriteFlip;
        o.scale = spriteScale;
        if (hitDelayTimer.isRunning) o.color = flashState ? blank : white;
        if (!isFalling) drawTextureArea(atlas, Rect(16, 104, 8, 8), sprite.position, o);
        drawSprite(atlas, sprite, o);
        if (canAction && hasAction) {
            auto actionPoint = getActor(id).position.toVec() + Vec2(1, -8 + sin(elapsedTime * 6) * 2);
            drawTextureArea(atlas, Rect(16, 0, 8, 8), actionPoint, DrawOptions(Hook.bottom));
        }
    }
}

struct Blood {
    BoxActorId id;

    void draw() {
        drawTextureArea(atlas, Rect(24, 0, 8, 8), getActor(id).position.toVec());
    }
}

struct BloodCounterArea {
    BoxActorId id;
    Sz count;

    void update(float dt) {
        count = 0;
        foreach (blood; game.blood) count += id.hasCollision(blood.id);
    }

    void draw() {
        drawTextureArea(atlas, Rect(56, (count >= bloodTargetCount ? 8 : 0), 8, 8), getActor(id).position.toVec());
    }
}

struct WormsCounterArea {
    BoxActorId id;
    Sz count;

    void update(float dt) {
        count = 0;
        foreach (worm; game.worms) count += id.hasCollision(worm.id);
    }

    void draw() {
        enum offset = Vec2(4, 4);
        auto target = Rect(offset.x + 31 + 5, offset.y + 25 + 3);
        target.position = getActor(id).position.toVec() - offset;
        drawTexturePatch(atlas, Rect(64, 0, 24, 24), target, false);
    }
}

struct Hole {
    BoxActorId id;

    void update(float dt) {
        if (id.hasCollision(game.player.id)) {
            // It's `2.0f` here because it starts counting from the falling animation :)
            if (!game.player.isFalling) game.finTimer.start(2.0f);
            game.player.isFalling = true;
        }
    }
}

struct Ball {
    BoxActorId id;
    Vec2 direction;
    bool isFalling;
    float fallingDelay = 0.0f;
    Vec2 spriteScale = Vec2(1);

    void update(float dt) {
        if (isFalling) {
            auto holeCenter = getActor(game.hole.id).centerPoint.toVec();
            auto fallPoint = holeCenter - getActor(id).size.toVec() * Vec2(0.5f) + Vec2(1, 2);
            if (fallingDelay >= 0.25f) spriteScale = spriteScale.moveTo(Vec2(), Vec2(0.025f));
            game.world.moveActorTo(id, fallPoint, Vec2(0.3f));
            fallingDelay += dt;
        } else {
            if (id.hasCollision(game.player.id)) {
                direction = getActor(game.player.id).topPoint.directionTo(getActor(id).centerPoint);
            }
            if (id.hasCollision(game.hole.id)) {
                isFalling = true;
            }
            auto collision = game.world.moveActor(id, direction);
            if (collision.x) {
                direction = game.world.getWall(collision.x).centerPoint.directionTo(getActor(id).centerPoint) * Vec2(0.5f);
            }
            if (collision.y) {
                direction = game.world.getWall(collision.y).centerPoint.directionTo(getActor(id).centerPoint) * Vec2(0.5f);
            }
        }
        direction = direction.moveToWithSlowdown(Vec2(), Vec2(dt), 0.27f);
    }

    void draw() {
        auto o = DrawOptions();
        o.scale = spriteScale;
        o.hook = Hook.center;
        o.flip = direction.fequals(Vec2(), 0.1) ? Flip.none : (fmod(elapsedTime, 0.2f) < 0.1f) ? Flip.x : Flip.none;
        auto point = getActor(id).position.toVec() + Vec2(2);
        if (!isFalling) drawTextureArea(atlas, Rect(12, 104, 4, 4), point, o);
        drawTextureArea(atlas, Rect(8, 104, 4, 4), point, o);
    }
}

struct Door {
    int hp = defaultDoorHp;
    BoxActorId id;
    BoxActorId openButtonId;

    void update(float dt, bool hackBool = false) {
        if (id.hasCollision(game.player.id) || openButtonId.hasCollision(game.player.id)) {
           game.player.hasAction = true;
            if (!isActionPressed || game.player.hp == 0) return;
            stopSound(doorSound);
            playSound(doorSound);
            if (id.hasCollision(game.player.id) && hp == 0) {
                game.isEnding = true;
                game.fadingArea.y = gameHeight;
                game.fadingTarget.y = -gameHeight * 1.5f;
//                game.world.clearWalls(); TODO
            } else if (openButtonId.hasCollision(game.player.id)) {
                if (!hackBool) moveWorms(getActor(openButtonId).bottomPoint.toVec());
                if (hp == 1) {
                    auto hasOrderAndNotChaos = true;
                    foreach (i; 0 .. 4) if (game.paintings[i].index != i) hasOrderAndNotChaos = false;
                    if (hasOrderAndNotChaos) {
                        hp = 0;
                        playSound(goodSound);
                    }
                }
            } else {
                if (!hackBool) moveWorms(getActor(id).bottomPoint.toVec());
            }
            if (!game.isEnding) if (!hackBool) appendWorm();
        }
    }

    void draw() {
        drawTextureArea(atlas, Rect(112 + (hp == 0 ? 8 : 0), 0, 8, 16), Vec2(112, 8));
    }
}

struct Button {
    bool isDown;
    int value;
    BoxActorId id;

    void update(float dt) {
        auto isPlayerHere = id.hasCollision(game.player.id);
        if (isPlayerHere && !isDown) {
            stopSound(doorSound);
            playSound(doorSound);
            moveWorms(getActor(id).centerPoint.toVec());
            appendWorm();
            game.buttonsInput.append(value.toStr()[0]);
        }
        isDown = isPlayerHere;
    }

    void draw() {
        drawTextureArea(atlas, Rect(48 + (isDown ? 8 : 0), 16, 8, 8), getActor(id).position.toVec());
    }
}

struct Worm {
    bool canMove;
    Vec2 target;
    ubyte animationOffset;
    ubyte animationSpeed;
    Flip animationFlip;
    Timer flipTimer = Timer(0.35f, true);
    Timer directionTimer = Timer(0.3f, true);
    Timer huntTimer = Timer(10, true);
    BoxActorId id;
    BoxMover mover = BoxMover(0.6f, 0.6f);

    enum minHuntTime = 15;
    enum extraHuntTime = 10;

    void startHuntTimer() {
        huntTimer.start(minHuntTime + randi % extraHuntTime);
    }

    void update(float dt) {
        if (!canMove) return;
        flipTimer.update(dt);
        huntTimer.update(dt);
        directionTimer.update(dt);

        // Move around.
        mover.direction = Vec2();
        if (directionTimer.hasStopped) {
            switch (randi % 4) {
                case 0: mover.direction += Vec2(-1, -1); break;
                case 1: mover.direction += Vec2(-1, 1); break;
                case 2: mover.direction += Vec2(1, -1); break;
                case 3: mover.direction += Vec2(1, 1); break;
                default: break;
            }
        }
        if (flipTimer.hasStopped) animationFlip = randi % 2 ? Flip.x : Flip.none;
        if (huntTimer.hasStopped) target = getActor(game.player.id).centerPoint.toVec();
        if (!target.isZero) {
            directionTimer.duration = 0.02f;
            auto point = getActor(id).centerPoint.toVec();
            mover.direction = (mover.direction + point.directionTo(target));
            if (Rect(target, 4, 4).area(Hook.center).hasPoint(point)) target = Vec2();
        } else {
            directionTimer.duration = 0.3f;
        }
        mover.direction = mover.direction.normalize();
        if (id.hasCollision(game.hole.id)) {
            mover.direction = getActor(game.hole.id).centerPoint.toVec().directionTo(getActor(id).centerPoint.toVec()) + mover.direction;
        }
        game.world.moveActor(id, mover.move());

        // Check for collisions.
        if (id.hasCollision(game.player.id)) {
            if (!game.player.hitDelayTimer.isRunning) {
                if (game.player.hp >= 1) {
                    if (game.player.hp == 1) game.finTimer.start();
                    game.player.hp -= 1;
                }
                game.player.hitDelayTimer.start();
                game.player.flashTimer.start();
                game.player.flashState = true;
                playSound(doorSound);
                appendBlood(getActor(game.player.id).centerPoint);
            }
        }
    }

    void draw() {
        drawTextureArea(
            atlas,
            Rect(((cast(int) (elapsedTime * animationSpeed + animationOffset)) % 2) * 4, 104, 4, 4),
            getActor(id).position.toVec() + Vec2(0, -1),
            DrawOptions(animationFlip),
        );
    }
}

struct NumberInput {
    char[N] data;
    int appendIndex;

    enum N = 8;
    enum inputLenght = 4;

    void append(char value) {
        data[appendIndex] = value;
        appendIndex = wrap(appendIndex + 1, 0, N);
    }

    char[] get() {
        static char[N] buffer;
        auto result = buffer[0 .. inputLenght];
        foreach (i; 0 .. inputLenght) {
            result[i] = data[wrap(appendIndex - inputLenght + i, 0, N)];
        }
        return result;
    }
}

struct Painting {
    Vec2 position = startPosition;
    BoxActorId id;
    int index;

    enum startPosition = Vec2(8 * 5 - 4, 8 * 1 * -10);

    this(int index, BoxActorId id) {
        this.index = index;
        this.id = id;
        snapX();
    }

    bool isUp() {
        return position.y.fequals(startPosition.y);
    }

    void snapX() {
        position.x = startPosition.x + index * 16;
        getActor(id).position = position.toIVec() + IVec2(3, 0);
    }

    void update(float dt) {
        position = position.moveToWithSlowdown(Vec2(startPosition.x + index * 16, 8.0f), Vec2(dt), 0.12f);
        getActor(id).position = position.toIVec() + IVec2(3, 0);
        if (id.hasCollision(game.player.id)) {
            game.player.hasAction = true;
            if (isActionPressed) {
                auto move = game.player.spriteFlip == Flip.x ? -1 : 1;
                index = clamp(index + move, 0, 3);
            }
        }
    }
}

enum GameMode {
    intro,
    play,
    outro,
}

struct Game {
    GameMode         mode;
    TileMap          map;
    BoxWorld         world;
    Rect             fadingArea = Rect(0, gameHeight, gameSize);
    Vec2             fadingTarget = Vec2(0, gameHeight);
    Rgba             fadingColor = Pico8.black;
    bool             oneFadeForTheEndBoys = false;
    bool             isDebugging;
    bool             isEnding;
    bool             canHideHp;
    bool             hasPlayerLeft;
    Timer            outroTimer = Timer(4.2f);
    Timer            finTimer = Timer(0.9f);

    List!Painting    paintings;
    Player           player;
    Hole             hole;
    Door             door;

    Ball             ball;
    bool             ballDone;

    List!Blood       blood;
    BloodCounterArea bloodCounterArea1;
    BloodCounterArea bloodCounterArea2;
    bool             bloodDone;

    List!Worm        worms;
    WormsCounterArea wormsCounterArea;
    bool             wormsDone;

    List!Button      buttons;
    NumberInput      buttonsInput;
    bool             buttonsDone;
}

ref IRect getActor(BoxActorId id) {
    return game.world.getActor(id);
}

// TODO(Parin): Make a ID-ID collision thing.
bool hasCollision(BoxActorId a, BoxActorId b) {
    return getActor(a).hasIntersection(getActor(b));
}

void prepareGame() {
    lockResolution(gameWidth, gameHeight);
    freeEngineResources();
    setBackgroundColor(Pico8.lightGray);
    setBorderColor(Pico8.lightGray);
    walkSound = loadSound("audio/walk.wav", 2.51f, 0.38f, true, 1.18f);
    doorSound = loadSound("audio/door.wav", 0.44f, 1.00f, false, 1.18f);
    goodSound = loadSound("audio/good.wav", 0.92f, 1.00f, false, 1.18f);
    atlas = loadTexture("atlas.png");

    if (game == null) {
        game = jokaMake!Game();
    } else {
        // NOTE(Joka): Make the arena allocator easier to use for existing types?
        // Is an arena good for things like that? Don't know. I will review the code later.
        // I do have a similar problem with the engine state too.
        game.map.clear();
        auto tempMap = game.map;
        game.world.clear();
        auto tempWorld = game.world;
        game.paintings.clear();
        auto tempPaintings = game.paintings;
        game.blood.clear();
        auto tempBlood = game.blood;
        game.worms.clear();
        auto tempWorms = game.worms;
        game.buttons.clear();
        auto tempButtons = game.buttons;
        *game = Game();
        game.map = tempMap;
        game.world = tempWorld;
        game.paintings = tempPaintings;
        game.blood = tempBlood;
        game.worms = tempWorms;
        game.buttons = tempButtons;
    }
    game.map.parse(loadTempText("map.csv").getOr(), 8, 8);
    game.world.parseWalls(loadTempText("map_walls.csv").getOr(), 8, 8);

    // NOTE(Joka): Arrays of structs.
    // This could be an array, but D likes to create type info for `struct[N]` types and WASM doesn't like that.
    // Joka's `FixedList` could avoid this by using `ubyte[N * S]`, but yeah.
    // Anyway...
    // I am setting the painting order here too because why not.
    // It depends also on the atlas position a bit. It's weird, I know. Works tho.
    game.paintings.append(Painting(2, game.world.appendActor(IRect(10, 20))));
    game.paintings.append(Painting(3, game.world.appendActor(IRect(10, 20))));
    game.paintings.append(Painting(1, game.world.appendActor(IRect(10, 20))));
    game.paintings.append(Painting(0, game.world.appendActor(IRect(10, 20))));

    game.player.id = game.world.appendActor(IRect(114, 49, 4, 2));
    game.hole.id = game.world.appendActor(IRect(73, 42, 13, 13));
    game.ball.id = game.world.appendActor(IRect(35, 30, 4, 4));
    game.wormsCounterArea.id = game.world.appendActor(IRect(100, 36, 31, 25));
    game.bloodCounterArea1.id = game.world.appendActor(IRect(21, 32, 8, 8));
    game.bloodCounterArea2.id = game.world.appendActor(IRect(21, 46, 8, 8));
    game.door.id = game.world.appendActor(IRect(111, 24, 10, 4));
    game.door.openButtonId = game.world.appendActor(IRect(133, 14, 5, 14));

    enum buttonCenter = IVec2(8 * 9 + 4, 67);
    enum buttonOffset = IVec2(25, 0);
    appendButton(buttonCenter - buttonOffset);
    appendButton(buttonCenter);
    appendButton(buttonCenter + buttonOffset);
}

bool checkKeyboardShortcuts() {
    if (Keyboard.f11.isPressed) toggleIsFullscreen();
    if ('0'.isPressed) {
        game.isDebugging = !game.isDebugging;
        if (game.isDebugging) lockResolution(cast(int) (gameWidth * 1.5f), cast(int) (gameHeight * 1.5f));
        else lockResolution(gameWidth, gameHeight);
    }
    debug {
        if (Keyboard.esc.isPressed) return true;
        if ('9'.isPressed) prepareGame();
    }
    return false;
}

bool isActionPressed() {
    with (Keyboard) return space.isPressed;
}

void appendWorm() {
    auto worm = Worm();
    worm.flipTimer.start();
    worm.directionTimer.start();
    worm.startHuntTimer();
    worm.id = game.world.appendActor(IRect(77, 45, 4, 2));
    worm.animationOffset = cast(ubyte) (randi % 255);
    worm.animationSpeed = cast(ubyte) (2 + randi % 4);
    game.worms.append(worm);
}

void appendButton(IVec2 position) {
    auto button = Button();
    button.id = game.world.appendActor(IRect(position, 8, 6));
    button.value = cast(int) game.buttons.length + 1;
    game.buttons.append(button);
}

void appendBlood(IVec2 position) {
    auto blood = Blood();
    auto box = IRect(position + IVec2(-3, -2), 6, 5);
    // TODO(Parin): Hack that resolves collision with bottom walls. Make library solution that does this when adding a new box.
    if (box.y >= 77) {
        foreach (wall; game.world.walls) {
            while (wall.hasIntersection(box)) box.y -= 1;
        }
    }
    blood.id = game.world.appendActor(box);
    game.blood.append(blood);
}

void moveWorms(Vec2 target) {
    foreach (ref worm; game.worms) worm.target = target;
}

void ready() {
    setIsPixelPerfect(true);
    setIsPixelSnapped(true);
    prepareGame();
}

bool update(float dt) {
    auto o = DrawOptions();
    if (checkKeyboardShortcuts()) return true;
    game.fadingArea.position = game.fadingArea.position.moveToWithSlowdown(game.fadingTarget, Vec2(dt), 0.3f);
    game.finTimer.update(dt);
    game.outroTimer.update(dt);
    // Update the world.
    with (GameMode) final switch (game.mode) {
        case intro:
            o = DrawOptions();
            o.hook = Hook.bottom;
            o.color = white;
            auto offsetX = Vec2(17, 0);
            auto offsetY = Vec2(0, 10);
            auto offsetTime1 = Vec2(0, sin(elapsedTime * 6 + 10) * 2);
            auto offsetTime2 = Vec2(0, sin(elapsedTime * 6 + 20) * 2);
            drawTextureArea(atlas, Rect(88, 0, 22, 8), gameCenter - offsetX + offsetY + offsetTime2, o);
            drawTextureArea(atlas, Rect(88, 8, 22, 16), gameCenter + offsetX + offsetY + offsetTime1, o);
            version(WebAssembly) {
            } else {
                drawTextureArea(atlas, Rect(88, 112, 13, 7), gameBottom + Vec2(68, -4), o);
            }
            if (game.fadingArea.y == gameHeight && isActionPressed) {
                game.fadingArea.y = gameHeight;
                game.fadingTarget.y = -gameHeight * 1.5f;
            }
            if (game.fadingArea.y <= 0) game.mode = play;
            break;
        case play:
            auto isFading = !game.fadingArea.y.fequals(game.fadingTarget.y, 30); // I don't care. Smoothstep is better, I know... Nerd.
            if (game.fadingArea.y <= 10 && !game.oneFadeForTheEndBoys && game.isEnding) {
                game.oneFadeForTheEndBoys = true;
                game.canHideHp = true;
                game.map.parse(loadTempText("end.csv").getOr(), 8, 8);
                game.world.parseWalls(loadTempText("end_walls.csv").getOr(), 8, 8);
                getActor(game.player.id).position = IVec2(8 * 10 + 2, 8 * 3 + 4);
                setBorderColor(Pico8.black);
                setBackgroundColor(Pico8.black);
                game.player.canAction = false;
            }
            game.player.canMove = !isFading;
            if (game.isEnding) {
                game.player.update(dt);
                if (!game.hasPlayerLeft && getActor(game.player.id).y >= gameHeight + 3) {
                    game.hasPlayerLeft = true;
                    game.outroTimer.start();
                }
                if (game.outroTimer.hasStopped) {
                    game.mode = outro;
                }
            } else {
                game.door.update(dt);
                game.player.update(dt);
                game.door.update(dt, true); // LOL
                game.ball.update(dt);
                game.hole.update(dt);
                game.wormsCounterArea.update(dt);
                game.bloodCounterArea1.update(dt);
                game.bloodCounterArea2.update(dt);
                foreach (ref button; game.buttons) {
                    button.update(dt);
                }
                foreach (ref worm; game.worms) {
                    worm.canMove = !isFading;
                    worm.update(dt);
                }
                foreach (i; 0 .. defaultDoorHp - game.door.hp) {
                    if (i == defaultDoorHp - 1) continue;
                    auto oldIndex = game.paintings[i].index;
                    game.paintings[i].update(dt);
                    auto newIndex = game.paintings[i].index;
                    if (oldIndex != newIndex) {
                        foreach (ii; 0 .. game.paintings.length) {
                            if (game.paintings[ii].index == newIndex && ii != i) {
                                game.paintings[ii].index = oldIndex;
                                if (game.paintings[ii].isUp) game.paintings[ii].snapX();
                                break;
                            }
                        }
                        break;
                    }
                }
                if (game.player.hp == 0) {
                    if (!game.finTimer.isRunning && isActionPressed) game.mode = outro;
                }
                if (!game.bloodDone && game.bloodCounterArea1.count >= bloodTargetCount && game.bloodCounterArea2.count >= bloodTargetCount) {
                    game.bloodDone = true;
                    game.door.hp -= 1;
                    playSound(goodSound);
                }
                if (!game.wormsDone && game.wormsCounterArea.count >= wormsTargetCount) {
                    game.wormsDone = true;
                    game.door.hp -= 1;
                    playSound(goodSound);
                }
                if (!game.buttonsDone && game.buttonsInput.get() == buttonsTargetInput) {
                    game.buttonsDone = true;
                    game.door.hp -= 1;
                    playSound(goodSound);
                }
                if (!game.ballDone && game.ball.isFalling) {
                    game.ballDone = true;
                    game.door.hp -= 1;
                    playSound(goodSound);
                }
            }
            // Draw the world.
            if (game.player.hp == 0) {
                drawRect(Rect(resolution), Pico8.black);
                o = DrawOptions(Hook.center);
                drawTextureArea(atlas, Rect(40, 40, 40, 16), gameCenter, o);
            } else {
                drawTileMap(atlas, game.map, Camera());
                if (game.isEnding && game.fadingArea.y <= 0) {
                } else {
                    drawTextureArea(atlas, Rect(32, 0, 8, 8), Vec2(21, 13));
                    drawTextureArea(atlas, Rect(40, 0, 8, 8), Vec2(132, 13));
                    foreach (i, painting; game.paintings) {
                        drawTextureArea(atlas, Rect(40 + 16 * i, 24, 16, 16), painting.position);
                    }
                    game.wormsCounterArea.draw();
                    game.door.draw();
                    game.bloodCounterArea1.draw();
                    game.bloodCounterArea2.draw();
                    foreach (ref button; game.buttons) button.draw();
                    foreach (ref blood; game.blood) blood.draw();
                    foreach (ref worm; game.worms) worm.draw();
                    game.ball.draw();
                }
                game.player.draw();
                if (game.isDebugging) drawDebugBoxWorld(game.world);
            }
            // Draw the UI.
            o = DrawOptions(Hook.bottomLeft);
            o.color = Pico8.white;
            if (game.isDebugging) drawDebugEngineInfo(Vec2(4, resolutionHeight - 4), o);
            if (!game.canHideHp) {
                o = DrawOptions(Hook.bottom);
                o.color = Pico8.purple;
                drawText(font, defaultTextHp[0 .. game.player.hp], gameBottom + Vec2(0, 2), o);
            } else {
                // Mix ideas and make code more spaghetti. MMmmMmmMm... Lecker!!!
                drawRect(Rect(-2, 84, 168, 22), Pico8.black);
                drawRect(Rect(-7, -5, 11, 92), Pico8.black);
                drawRect(Rect(157, -7, 11, 92), Pico8.black);
                if (game.hasPlayerLeft) drawTextureArea(atlas, Rect(88, 88, 40, 24), Vec2(64, 32));
            }
            break;
        case outro:
            prepareGame();
    }
    drawRect(game.fadingArea, game.fadingColor);
    return false;
}

void finish() { }

mixin runGame!(ready, update, finish, gameWidth * 6, gameHeight * 6);
