package;

import flixel.math.FlxMath;
#if desktop
import Discord.DiscordClient;
import sys.thread.Thread;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import haxe.Json;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.system.ui.FlxSoundTray;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import lime.app.Application;
import openfl.Assets;

using StringTools;
typedef TitleData =
{
	titlex:Float,
	titley:Float,
	startx:Float,
	starty:Float,
	teebx:Float,
	teeby:Float,
	backgroundSprite:String,
	bpm:Int
}
class TitleState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;
	private static var titleJSON:TitleData;

	var blackScreen:FlxSprite;
	var credGroup:FlxGroup;
	var credTextShit:Alphabet;
	var textGroup:FlxGroup;
	var trollSpr:FlxSprite;

	var curWacky1:Array<String> = [];
	var curWacky2:Array<String> = [];

	var lastKeysPressed:Array<FlxKey> = [];

	var logoScale:Float = .375;
	var logoBumpScale:Float = 1.065;

	public static var updateVersion:String = '';
	override public function create():Void
	{
		var path = Paths.getPreloadPath("images/teebDJ.json");
		titleJSON = Json.parse(Assets.getText(path));

		FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = muteKeys;
		FlxG.sound.volumeDownKeys = volumeDownKeys;
		FlxG.sound.volumeUpKeys = volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];

		PlayerSettings.init();

		curWacky1 = rollWacky();
		curWacky2 = rollWacky(curWacky1);

		super.create();

		FlxG.save.bind('teebin', 'ninjamuffin99');
		ClientPrefs.loadPrefs();

		Highscore.load();
		if (FlxG.save.data.weekCompleted != null) StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;

		FlxG.mouse.visible = false;
		#if FREEPLAY
		MusicBeatState.switchState(new FreeplayState());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if(FlxG.save.data.flashing == null && !FlashingState.leftState) {
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		} else {
			#if desktop
			DiscordClient.initialize();
			Application.current.onExit.add (function (exitCode) {
				DiscordClient.shutdown();
			});
			#end
			new FlxTimer().start(1, function(tmr:FlxTimer)
			{
				startIntro();
			});
		}
		#end
	}

	var logoBl:FlxSprite;
	var teebDJ:FlxSprite;
	var titleText:FlxSprite;

	public static function playTitleMusic(?volume:Float = 1)
	{
		FlxG.sound.playMusic(Paths.music('mainmenuteebmod'), volume);
		if (titleJSON != null) Conductor.changeBPM(titleJSON.bpm);
	}
	function startIntro()
	{
		if (!initialized)
		{
			if(FlxG.sound.music == null) {
				playTitleMusic(0);
				FlxG.sound.music.fadeIn(4, 0, 0.7);
			}
		}

		Conductor.changeBPM(titleJSON.bpm);
		persistentUpdate = true;

		var bg:FlxSprite = new FlxSprite();

		if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.length > 0 && titleJSON.backgroundSprite != "none") { bg.loadGraphic(Paths.image(titleJSON.backgroundSprite)); }
		else { bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK); }

		bg.antialiasing = ClientPrefs.globalAntialiasing;
		bg.screenCenter();

		logoBl = new FlxSprite(titleJSON.titlex, titleJSON.titley);
		logoBl.loadGraphic(Paths.image('teebin'));

		logoBl.antialiasing = ClientPrefs.globalAntialiasing;
		logoBl.updateHitbox();
		// logoBl.screenCenter();
		// logoBl.color = FlxColor.BLACK;

		teebDJ = new FlxSprite(titleJSON.teebx, titleJSON.teeby);
		teebDJ.frames = Paths.getSparrowAtlas('teebDJ');

		teebDJ.animation.addByPrefix('dance', 'TEEB_DANCE', 24, false);
		teebDJ.antialiasing = ClientPrefs.globalAntialiasing;

		add(teebDJ);
		add(logoBl);

		titleText = new FlxSprite(titleJSON.startx, titleJSON.starty);
		titleText.frames = Paths.getSparrowAtlas('titleEnter');

		titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
		titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		titleText.antialiasing = ClientPrefs.globalAntialiasing;
		titleText.animation.play('idle');
		titleText.updateHitbox();
		// titleText.screenCenter(X);
		add(titleText);

		var logo:FlxSprite = new FlxSprite().loadGraphic(Paths.image('logo'));
		logo.screenCenter();
		logo.antialiasing = ClientPrefs.globalAntialiasing;
		// add(logo);

		// FlxTween.tween(logoBl, {y: logoBl.y + 50}, 0.6, {ease: FlxEase.quadInOut, type: PINGPONG});
		// FlxTween.tween(logo, {y: logoBl.y + 50}, 0.6, {ease: FlxEase.quadInOut, type: PINGPONG, startDelay: 0.1});

		credGroup = new FlxGroup();
		add(credGroup);
		textGroup = new FlxGroup();

		credGroup.add(bg);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();

		// credTextShit.alignment = CENTER;

		credTextShit.visible = false;

		trollSpr = new FlxSprite(0, FlxG.height * .4).loadGraphic(Paths.image('torled'));
		add(trollSpr);
		trollSpr.visible = false;
		trollSpr.setGraphicSize(Std.int(trollSpr.width * .6));
		trollSpr.updateHitbox();
		trollSpr.screenCenter(X);
		trollSpr.antialiasing = true;

		FlxTween.tween(credTextShit, {y: credTextShit.y + 20}, 2.9, {ease: FlxEase.quadInOut, type: PINGPONG});

		if (initialized)
			skipIntro();
		else
			initialized = true;

		// credGroup.add(credTextShit);
	}

	function getIntroTextShit():Array<Array<String>>
	{
		var fullText:String = Assets.getText(Paths.txt('introText'));

		var firstArray:Array<String> = fullText.split('\n');
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
		// FlxG.watch.addQuick('amp', FlxG.sound.music.amplitude);

		if (FlxG.keys.justPressed.F)
		{
			FlxG.fullscreen = !FlxG.fullscreen;
		}

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}

		// EASTER EGG

		if (!transitioning && skippedIntro)
		{
			if(pressedEnter)
			{
				if(titleText != null) titleText.animation.play('press');

				FlxG.camera.flash(FlxColor.WHITE, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), .7);

				transitioning = true;
				// FlxG.sound.music.stop();

				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					MusicBeatState.switchState(new MainMenuState());
					closedState = true;
				});
				// FlxG.sound.play(Paths.music('titleShoot'), 0.7);
			}
		}

		if (pressedEnter && !skippedIntro) skipIntro();
		if (ClientPrefs.camZooms)
		{
			var lerpSpeed:Float = CoolUtil.boundTo(1 - (elapsed * 3.125), 0, 1);
			FlxG.camera.zoom = FlxMath.lerp(1, FlxG.camera.zoom, lerpSpeed);
		}
		if (logoBl != null)
		{
			var mult:Float = FlxMath.lerp(logoScale, logoBl.scale.x, CoolUtil.boundTo(1 - (elapsed * 9), 0, 1));

			logoBl.scale.set(mult, mult);
			logoBl.updateHitbox();
		}
		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true, false);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if(credGroup != null && textGroup != null) {
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if(textGroup != null && credGroup != null) {
			var coolText:Alphabet = new Alphabet(0, 0, text, true, false);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
		}
	}

	function canZoomCamera():Bool { return FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms; }
	function sameRoll(a:Array<String>, ?b:Array<String> = null):Bool
	{
		if (b != null && a.length == b.length)
		{
			var compared:Int = 0;

			for (i in 0...a.length) { if (a[i] == b[i]) compared++; }
			if (compared >= a.length) return true;
		}
		return false;
	}
	function rollWacky(?match = null):Array<String>
	{
		var rolled = null;

		do { rolled = FlxG.random.getObject(getIntroTextShit()); } while (sameRoll(rolled, match));
		return rolled;
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0; //Basically curBeat but won't be skipped if you hold the tab or resize the screen
	public static var closedState:Bool = false;

	override function beatHit()
	{
		super.beatHit();

		if (logoBl != null) { var mult:Float = logoScale * logoBumpScale; logoBl.scale.set(mult, mult); logoBl.updateHitbox(); }
		if (teebDJ != null) teebDJ.animation.play('dance', true);

		if (!closedState) {
			sickBeats++;
			if (canZoomCamera())
			{
				var beatMod = sickBeats % 2;
				FlxG.camera.zoom += .045 / (beatMod == 1 ? 2 : 1);
			}
			switch (sickBeats)
			{
				case 1: createCoolText(['Zion', FlxG.random.bool(5) ? 'Teebiscuit' : 'Teebicus', 'MotorcycIeMan', 'DubSurgeon', 'yellwbit'], -40);
				case 6: addMoreText('present', -40);

				case 8: deleteCoolText();

				case 10: createCoolText(['A mod fabricated by']);
				case 12: addMoreText('dumbasses');

				case 14: deleteCoolText();

				case 16: createCoolText(['In association', 'with'], -40);
				case 18:
				{
					addMoreText('deez', FlxG.height * .275);
					trollSpr.visible = true;
				}
				case 20:
				{
					deleteCoolText();
					trollSpr.visible = false;
				}

				case 22: createCoolText([curWacky1[0]]);
				case 24: addMoreText(curWacky1[1]);

				case 26: deleteCoolText();

				case 28: createCoolText([curWacky2[0]]);
				case 30: addMoreText(curWacky2[1]);

				case 32: deleteCoolText();

				case 34: addMoreText('Friday');
				case 36: addMoreText('Night');
				case 38: addMoreText('Teebin');

				case 40: skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;

	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			remove(trollSpr);

			FlxG.camera.flash(FlxColor.WHITE, 4);
			remove(credGroup);
			skippedIntro = true;
		}
	}
}