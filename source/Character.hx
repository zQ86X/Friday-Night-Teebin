package;

import flixel.animation.FlxAnimation;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxTween;
import flixel.util.FlxSort;
import Section.SwagSection;
import openfl.utils.Assets;
import haxe.Json;
import haxe.format.JsonParser;

using StringTools;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var startedDeath:Bool = false;
	public var singDuration:Float = 4; //Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; //Character use "danceLeft" and "danceRight" instead of "idle"

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	public var hasMissAnimations:Bool = false;

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public static var DEFAULT_CHARACTER:String = 'bf'; //In case a character is missing, it will use BF on its place
	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false)
	{
		super(x, y);

		this.isPlayer = isPlayer;
		antialiasing = ClientPrefs.globalAntialiasing;

		originalFlipX = flipX;
		setCharacter(character);
	}

	override function update(elapsed:Float)
	{
		if(!debugMode && animation.curAnim != null)
		{
			var curAnim:FlxAnimation = animation.curAnim;
			var animName:String = curAnim.name;

			if (heyTimer > 0)
			{
				heyTimer -= elapsed;
				if(heyTimer <= 0)
				{
					if (specialAnim && (animName == 'hey' || animName == 'cheer'))
					{
						specialAnim = false;
						dance();
					}
					heyTimer = 0;
				}
			} else
			{
				if (specialAnim && curAnim.finished)
				{
					specialAnim = false;
					dance();
				}
			}

			if (animName.startsWith('sing')) { holdTimer += elapsed; }
			else { if (isPlayer) holdTimer = 0; }

			if (animName.endsWith('miss') && curAnim.finished) dance();
			if (!isPlayer)
			{
				if (holdTimer >= Conductor.stepCrochet * .001 * singDuration)
				{
					dance();
					holdTimer = 0;
				}
			}

			var loopAnim:String = '${animName}-loop';

			if(curAnim.finished && animation.getByName(loopAnim) != null) playAnim(loopAnim);
			if (animName.toLowerCase().startsWith('firstdeath') && curAnim.finished && startedDeath) playAnim('deathLoop');
		}
		super.update(elapsed);
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance()
	{
		if (!debugMode && !specialAnim)
		{
			switch (danceIdle)
			{
				case true:
				{
					danced = !danced;
					playAnim(danced ? 'danceRight$idleSuffix' : 'danceLeft$idleSuffix');

					return;
				}
				default:
				{
					var idleFormat:String = 'idle$idleSuffix';
					if(animation.getByName(idleFormat) != null) playAnim(idleFormat);
				}
			}
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);

		if (animOffsets.exists(AnimName)) offset.set(daOffset[0], daOffset[1]);
		else { offset.set(0, 0); }

		if (danceIdle)
		{
			danced = switch (AnimName.toLowerCase())
			{
				case 'singright': false;
				case 'singleft': true;

				case 'singup' | 'singdown': !danced;
				default: danced;
			};
		}
	}

	public function recalculateDanceIdle() {
		danceIdle = (animation.getByName('danceLeft' + idleSuffix) != null && animation.getByName('danceRight' + idleSuffix) != null);
	}
	public function setCharacter(?character:String = 'bf')
	{
		#if (haxe >= "4.0.0")
		animOffsets = new Map();
		#else
		animOffsets = new Map<String, Array<Dynamic>>();
		#end
		animation.destroyAnimations();

		var library:String = null;
		curCharacter = character;

		switch (curCharacter)
		{
			//case 'your character name in case you want to hardcode him instead':

			default:
				var characterPath:String = 'characters/' + curCharacter + '.json';
				var path:String = Paths.getPreloadPath(characterPath);

				if (!Assets.exists(path))
				{
					path = Paths.getPreloadPath('characters/' + DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
				}

				var rawJson = Assets.getText(path);
				var json:CharacterFile = cast Json.parse(rawJson);

				if(Assets.exists(Paths.getPath('images/' + json.image + '.txt', TEXT)))
				{
				//bozo forgot about the packer shits : P
					frames = Paths.getPackerAtlas(json.image);
				}
				else
				{
					frames = Paths.getSparrowAtlas(json.image);
				}
				imageFile = json.image;

				if(json.scale != 1) {
					jsonScale = json.scale;
					setGraphicSize(Std.int(width * jsonScale));
					updateHitbox();
				}

				positionArray = json.position;
				cameraPosition = json.camera_position;

				healthIcon = json.healthicon;
				singDuration = json.sing_duration;
				flipX = json.flip_x;
				if(json.no_antialiasing) {
					antialiasing = false;
					noAntialiasing = true;
				}

				if(json.healthbar_colors != null && json.healthbar_colors.length > 2)
					healthColorArray = json.healthbar_colors;

				antialiasing = !noAntialiasing;
				if(!ClientPrefs.globalAntialiasing) antialiasing = false;

				animationsArray = json.animations;
				if(animationsArray != null && animationsArray.length > 0) {
					for (anim in animationsArray) {
						var animAnim:String = anim.anim;
						var animName:String = anim.name;
						var animLoop:Bool = anim.loop;
						var animFps:Int = anim.fps;

						var animIndices:Array<Int> = anim.indices;
						if(animIndices != null && animIndices.length > 0) {
							animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
						} else {
							animation.addByPrefix(animAnim, animName, animFps, animLoop);
						}

						if(anim.offsets != null && anim.offsets.length > 1) {
							addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
						}
					}
				} else {
					quickAnimAdd('idle', 'BF idle dance');
				}
				//trace('Loaded file to character ' + curCharacter);
		}
		hasMissAnimations = animOffsets.exists('singLEFTmiss') || animOffsets.exists('singDOWNmiss') || animOffsets.exists('singUPmiss') || animOffsets.exists('singRIGHTmiss');

		recalculateDanceIdle();
		dance();

		if (isPlayer) flipX = !flipX;
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		animation.addByPrefix(name, anim, 24, false);
	}
}
