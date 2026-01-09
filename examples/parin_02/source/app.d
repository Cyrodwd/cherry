import parin;
import cherry;
import std.conv;

// Evaluation
IStr cfg;

chEngine engine;
chLabel videoLabel;
chLabel texturesLabel;

// Video
chList  videoResolution;   /// Two elements (width and height)
int targetFPS;           /// Target FPS
bool     fullscreen;        /// Fullscreen (YES / NO)

// Textures and positions
TextureId celestiaTexture, bigMacTexture;
GVec2!float celestiaPosition, bigMacPosition;
DrawOptions celestiaDraw, bigMacDraw;

bool shouldClose = false;
double textureScale; /// Range: 0.0 - 1.0
double textureRotation; /// Range: 0.0 - 360.0

// Called once when the game starts.
void ready() {
    cfg = readText("assets/config.cherry").getOr().toStr();
    engine = parseCherry(cfg.to!string);

    // Loading labels

    videoLabel = engine.getLabel("Video");
    assert(videoLabel.isValid(), "Video label is not being recognised");

    texturesLabel = engine.getLabel("Textures");
    assert(texturesLabel.isValid(), "Textures label is not being recognised");

    videoResolution = videoLabel.getList("resolution");
    assert(videoResolution.length()>0, "resolution list has no elements");

    chData fps = videoLabel.getData("fps");
    if (fps.isNegative()) {
        println("You cannot pass negative numbers for FPS");
        shouldClose = true; return;
    }

    // FPS
    targetFPS = fps.toInt();
    fullscreen = videoLabel.getData("fullscreen").isTrue();
    
    // Apply changes - Resolution
    int width = videoResolution.toInt(index: 0);
    int height = videoResolution.toInt(index: 1);

    if (width <= 0 || height <= 0) {
        width = 640;
        height = 480;
    }

    lockResolution(width, height);

    // Target FPS
    setFpsMax(targetFPS);
    
    // If 'fullscreen' is 'true', then set it to fullscreen.
    // For some reason, if you pass 'false' in 'setIsFullscreen', it also enables fullscreen
    // Maybe it happens only in my machine? Cuz i'm using X11 and KDE so... idk.
    // Probably it's intentional (o_o)
    if (fullscreen) { setIsFullscreen(fullscreen); }

    // Configuration of textures
    // TODO: Add a .length function to labels (for lists and elements)

    textureScale = texturesLabel.getData("scale").toFloat();
    textureRotation = texturesLabel.getData("rotation").toFloat();
    IStr randomMessage = texturesLabel.getData("randomMessage").toString();

    println("terminal::config.CHERRY: ", randomMessage);
    dprintln("config.CHERRY: ", randomMessage);
    dprintln("FPS MAX: ", targetFPS);

    celestiaTexture = loadTexture("princessCelestia.png");
    bigMacTexture = loadTexture("bigMac.png");

    assert(celestiaTexture.isValid(), "Celestia texture didn't load");
    assert(bigMacTexture.isValid(), "Big mac  texture didn't load");

    celestiaPosition = GVec2!float(130, 150);
    bigMacPosition = GVec2!float(350, 320);

    float clamped = clamp(textureScale, 0.1f, 1.0f);
    celestiaDraw.scale = bigMacDraw.scale = GVec2!float( clamped );
    celestiaDraw.rotation = bigMacDraw.rotation = clamp(textureRotation, 0.0f, 360.0f);

    auto celestiaWidth = (celestiaTexture.width * celestiaDraw.scale.x) / 2.0f;
    auto celestiaHeight = (celestiaTexture.height * celestiaDraw.scale.y) / 2.0f;

    auto bigWidth = (bigMacTexture.width * bigMacDraw.scale.x) / 2.0f;
    auto bigHeight = (bigMacTexture.height * bigMacDraw.scale.y) / 2.0f;

    celestiaDraw.origin = GVec2!float(celestiaWidth, celestiaHeight);
    bigMacDraw.origin = GVec2!float (bigWidth, bigHeight);
}

// Called every frame while the game is running.
// If true is returned, then the game will stop running.
bool update(float dt) {
    cast(void)dt;

    // FPS test
    if (isDown(Keyboard.space)) {
        celestiaDraw.rotation = bigMacDraw.rotation = fmod(celestiaDraw.rotation + 0.5, 360.0);
    }

    drawTexture(celestiaTexture, celestiaPosition, celestiaDraw);
    drawTexture(bigMacTexture, bigMacPosition, bigMacDraw);

    return shouldClose;
}

// Called once when the game ends.
void finish() {
    engine.clean();
    celestiaTexture.free();
    bigMacTexture.free();
}

// Creates a main function that calls the given functions.
mixin runGame!(ready, update, finish);
